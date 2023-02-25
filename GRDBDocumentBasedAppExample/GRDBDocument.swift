//
//  GRDBDocumentBasedAppExampleDocument.swift
//  GRDBDocumentBasedAppExample
//
//  Created by Perceval Faramaz on 22.02.23.
//

import SwiftUI
import UniformTypeIdentifiers
import GRDB
import GRDBUndoRedo

extension UTType {
    static var exampleText: UTType {
        UTType(exportedAs: "com.example.sqlite", conformingTo: .data)
    }
}

class GRDBFileWrapper: FileWrapper {
    var databaseQueue: DatabaseQueue

    init(fromDatabaseQueue databaseQueue: DatabaseQueue) {
        self.databaseQueue = databaseQueue
        super.init(regularFileWithContents: Data())
    }

    required init?(coder inCoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func write(
        to url: URL,
        options: FileWrapper.WritingOptions = [],
        originalContentsURL: URL?
    ) throws {
        let destination = try DatabaseQueue(path: url.path)
        do {
            try databaseQueue.backup(to: destination)
        } catch {
            throw CocoaError(.sqlite)
        }
    }
}

final class GRDBDocument: ReferenceFileDocument, ObservableObject {
    static var readableContentTypes: [UTType] { [.exampleText] }
    
    var database: DocumentDatabase
    var dbQueue: DatabaseQueue
    
    var undoManager: UndoManager?
    var sqlUndoRedo: UndoRedoManager

    init() {
        self.dbQueue = try! DatabaseQueue()
        self.database = try! DocumentDatabase(self.dbQueue)
        self.sqlUndoRedo = try! UndoRedoManager(recordTypes: KVRecord.self, db: self.dbQueue)
    }

    required init(configuration: ReadConfiguration) throws {
        self.dbQueue = try! DatabaseQueue()
        self.database = try! DocumentDatabase(self.dbQueue)
        
        guard let sourceURL = configuration.file.fileURL else {
            throw CocoaError(.fileReadUnknown)
        }
        
        if !FileManager.default.fileExists(atPath: sourceURL.path) {
            throw CocoaError(.fileReadNoSuchFile)
        }
        
        // Copy the DB from disk to an in-memory database
        do {
            let onDiskDb = try DatabaseQueue(path: sourceURL.path)
            try onDiskDb.backup(to: self.dbQueue)
        }
        catch {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        self.sqlUndoRedo = try! UndoRedoManager(recordTypes: KVRecord.self, db: self.dbQueue)
    }
    
    func snapshot(contentType: UTType) throws -> GRDBDocument {
        let snapshotDocument = GRDBDocument()
        try self.dbQueue.backup(to: snapshotDocument.dbQueue)
        return snapshotDocument
    }
    
    func fileWrapper(snapshot: GRDBDocument, configuration: WriteConfiguration) throws -> FileWrapper {
        // Copy the in-memory database to the disk
        return GRDBFileWrapper(fromDatabaseQueue: snapshot.dbQueue)
    }
    
    var cosmeticUndoActionsTarget: NSObject = NSObject()
}

struct EditableDocument {
    var dbQueue: DatabaseQueue
    
    func saveRecord(_ record: inout KVRecord) throws {
        try dbQueue.write { database in
            try record.save(database)
        }
    }
    
    func deleteRecords(ids: [UUID]) throws {
        try dbQueue.write { database in
            _ = try KVRecord.deleteAll(database, keys: ids)
        }
    }
}

extension GRDBDocument {
    func editAction(hint: String, _ closure: (EditableDocument) throws -> Void) throws {
        let eD = EditableDocument(dbQueue: self.dbQueue)
        try closure(eD)
        
        let changed = try self.sqlUndoRedo.barrier()
        guard changed else {return}
        undoManager?.registerUndo(withTarget: self) { document in
            document.undo()
        }
        undoManager?.setActionName(hint)
    }
    
    func cosmeticAction(hint: String, _ closure: () throws -> (() -> Void)) throws {
        self.undoManager?.removeAllActions(withTarget: self.cosmeticUndoActionsTarget)
        
        let undoer = try closure()
        
        let _ = try self.sqlUndoRedo.barrier()
        
        undoManager?.registerUndo(withTarget: self.cosmeticUndoActionsTarget) { _ in
            undoer()
        }
        undoManager?.setActionName(hint)
    }
    
    func undo() {
        try! self.sqlUndoRedo.perform(.undo)
        
        undoManager?.registerUndo(withTarget: self) { document in
            document.redo()
        }
    }
    
    func redo() {
        try! self.sqlUndoRedo.perform(.redo)
        
        undoManager?.registerUndo(withTarget: self) { document in
            document.undo()
        }
    }
}
