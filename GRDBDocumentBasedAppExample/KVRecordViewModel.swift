//
//  KVRecordViewModel.swift
//  GRDBDocumentBasedAppExample
//
//  Created by Perceval Faramaz on 22.02.23.
//

import Foundation
import Combine
import GRDB

final class KVRecordsViewModel: ObservableObject {
    @Published var records: [KVRecord] = []
    private var cancellable: AnyCancellable?
    
    private let document: GRDBDocument
    
    init(document: GRDBDocument) {
        self.document = document
        cancellable = ValueObservation
            .tracking(KVRecord.fetchAll)
            .publisher(in: document.database.reader, scheduling: .immediate)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] newRecords in
                    self?.records = newRecords
                })
    }
    
    func reset() throws {
        records = try document.database.reader.read { db in
            try KVRecord.fetchAll(db)
        }
    }
    
    func delete(_ id: KVRecord.ID?) throws {
        guard let id = id else { return }
        try document.editAction(hint: "Delete KV-record") { docProxy in
            try docProxy.deleteRecords(ids: [id])
            
        }
    }
    
    func newRecord() throws {
        try document.cosmeticAction(hint: "New KV-record") {
            self.records.append(KVRecord(key: "", value: ""))
            
            let undoer: () -> () = {
                try! self.reset()
            }
            return undoer
        }
    }
    
    func commitRecord(_ id: KVRecord.ID) throws {
        try document.editAction(hint: "Edit KV-record") { docProxy in
            if let idx = records.firstIndex(where: { $0.id == id })
            {
                var updatedRecord = records[idx]
                try docProxy.saveRecord(&updatedRecord)
            }
            else {
                try docProxy.deleteRecords(ids: [id])
            }
        }
    }
}
