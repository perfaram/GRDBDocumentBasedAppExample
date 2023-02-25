//
//  GRDBDocumentBasedAppExampleApp.swift
//  GRDBDocumentBasedAppExample
//
//  Created by Perceval Faramaz on 22.02.23.
//

import SwiftUI

private struct GRDBDocumentKey: EnvironmentKey {
    /// The default document is an empty document
    static let defaultValue = GRDBDocument()
}

extension EnvironmentValues {
    var document: GRDBDocument {
        get { self[GRDBDocumentKey.self] }
        set { self[GRDBDocumentKey.self] = newValue }
    }
}

@main
struct GRDBDocumentBasedAppExampleApp: App {
    init() {
        FileWrapper.swizzleInitializerToGetURL()
    }
    
    var body: some Scene {
        DocumentGroup(newDocument: { GRDBDocument() }) { file in
            ContentView()
                .environment(\.document, file.document)
        }
    }
}
