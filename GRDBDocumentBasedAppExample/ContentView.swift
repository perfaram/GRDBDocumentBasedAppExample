//
//  ContentView.swift
//  GRDBDocumentBasedAppExample
//
//  Created by Perceval Faramaz on 22.02.23.
//

import SwiftUI
import GRDBQuery

struct ErrorPopover: View {
    var body: some View {
        Text("Keys must be unique")
            .padding()
    }
}

struct Safe<T: RandomAccessCollection & MutableCollection, C: View>: View {
   
   typealias BoundElement = Binding<T.Element>
   private let binding: BoundElement
   private let content: (BoundElement) -> C

   init(_ binding: Binding<T>, index: T.Index, @ViewBuilder content: @escaping (BoundElement) -> C) {
      self.content = content
      self.binding = .init(get: { binding.wrappedValue[index] },
                           set: { binding.wrappedValue[index] = $0 })
   }
   
   var body: some View {
      content(binding)
   }
}

struct TableView: View {
    enum Focusable: Hashable {
        case none
        case record(id: KVRecord.ID)
    }
    
    @EnvironmentStateObject private var viewModel: KVRecordsViewModel
    @State private var selectedRecord: KVRecord.ID? = nil
    @FocusState private var focusedElement: TableView.Focusable?
    @State private var erroredRow: KVRecord.ID? = nil
    
    init() {
        _viewModel = EnvironmentStateObject {
            KVRecordsViewModel(document: $0.document)
        }
    }
    
    func commitRecord(_ itemId: KVRecord.ID) {
        do {
            try viewModel.commitRecord(itemId)
        }
        catch {
            erroredRow = itemId
            focusedElement = .record(id: itemId)
        }
    }
    
    func deleteRecord(_ itemID: KVRecord.ID?) {
        do {
            try viewModel.delete(selectedRecord)
        }
        catch {
            //if it fails, the record is not deleted, and stays visible
        }
    }
    
    var body: some View {
        VStack {
            Table($viewModel.records, selection: $selectedRecord) {
                TableColumn("Key") { item in
                    let itemId = item.id
                    TextField("key", text: item.key) { isEditing in
                        //editingRow = isEditing ? item.id : nil
                    } onCommit: {
                        commitRecord(itemId)
                    }
                    .focused($focusedElement, equals: .record(id: itemId))
                }
                
                TableColumn("Value") { item in
                    let itemId = item.id
                    TextField("value", text: item.value) { isEditing in
                        //editingRow = isEditing ? item.id : nil
                    } onCommit: {
                        commitRecord(itemId)
                    }
                }
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .popover(isPresented: Binding<Bool>(
                get: {
                    self.erroredRow != nil
                },
                set: {
                    if !$0 {
                        self.erroredRow = nil
                    }
                }),
                     attachmentAnchor: .point(.top),
                     arrowEdge: .bottom) { ErrorPopover() }
            
            HStack {
                Button("-") {
                    deleteRecord(selectedRecord)
                }
                Button("+") {
                    try! viewModel.newRecord()
                }
                Button("garbage") {
                    if var last = viewModel.records.last {
                        last.value = "garbage"
                        viewModel.records[viewModel.records.count - 1] = last
                        commitRecord(last.id)
                    }
                }
            }
            .padding()
        }
    }
}

struct KeysList: View {
    @Query(KVRecordRequest(ordering: KVRecordRequest.Ordering.byKeyName), in: \.document.database)
        private var records: [KVRecord]
    
    var body: some View {
        List {
            Section(header: Text("Keys")) {
                ForEach(records) { record in
                    Text(record.key)
                }
            }
            .headerProminence(.increased)
        }
    }
}

struct ContentView: View {
    @Environment(\.undoManager) var undoManager
    @Environment(\.document) var document
    
    var body: some View {
        HStack {
            TableView()
            KeysList()
        }
        .onChange(of: undoManager) { undoManager in
            document.undoManager = undoManager
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
