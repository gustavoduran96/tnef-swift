#!/usr/bin/env swift

import Foundation
import TNEFSwift

let args = CommandLine.arguments

if args.count < 2 {
    print("Usage: TNEFSwiftDemo <file.dat>")
    exit(1)
}

let filePath = args[1]

do {
    let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
    
    if let tnef = parseTNEF(data: data) {
        print("TNEF parsed successfully")
        print("Body: \(tnef.body)")
        print("Attachments: \(tnef.attachments.count)")
        print("Attributes: \(tnef.attributes.count)")
    } else {
        print("Failed to parse TNEF file")
        exit(1)
    }
    
} catch {
    print("Error reading file: \(error)")
    exit(1)
}
