//
//  FileWrapper+SourceURL.swift
//  GRDBDocumentBasedAppExample
//
//  Created by Perceval Faramaz on 22.02.23.
//

import Foundation
import ObjectiveC

// Declare a global var to produce a unique address as the associated object handle
private var AssociatedObjectHandle: UInt8 = 0

/// FileWrapper extension to make instances aware of their URL.
/// Source: https://developer.apple.com/forums/thread/700112 / @giacomoleopizzi
extension FileWrapper {
    var fileURL: URL? {
        get {
            return objc_getAssociatedObject(self, &AssociatedObjectHandle) as? URL
        }
        set {
            objc_setAssociatedObject(self, &AssociatedObjectHandle, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    @objc convenience init(trick url: URL, options: ReadingOptions) throws {
        try self.init(trick: url, options: options)
        self.fileURL = url
    }
    
    static func swizzleInitializerToGetURL() {
        let aClass: AnyClass = FileWrapper.self
        let originalMethod = class_getInstanceMethod(aClass, #selector(FileWrapper.init(url:options:)))
        let swizzledMethod = class_getInstanceMethod(aClass, #selector(FileWrapper.init(trick:options:)))
        guard let originalMethod = originalMethod, let swizzledMethod = swizzledMethod else {
            return
        }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
}
