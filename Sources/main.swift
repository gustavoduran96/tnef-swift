#!/usr/bin/env swift

import Foundation

let TNEF_SIGNATURE: UInt32 = 0x223E9F78
let LEVEL_MESSAGE: UInt8 = 0x01
let LEVEL_ATTACHMENT: UInt8 = 0x02

let ATTATTACHTITLE: UInt16 = 0x8010
let ATTATTACHDATA: UInt16 = 0x800F
let ATTATTACHRENDDATA: UInt16 = 0x9002
let ATTMAPIPROPS: UInt16 = 0x9003

let MAPIBody: UInt16 = 0x1000
let MAPIBodyHTML: UInt16 = 0x1013

struct TNEFAttachment {
    var title: String = ""
    var data: Data = Data()
}

struct TNEFMessage {
    var attachments: [TNEFAttachment] = []
    var body: String = ""
    var bodyHTML: String = ""
    var attributes: [String: Data] = [:]
}

func parseTNEF(data: Data) -> TNEFMessage? {
    guard data.count >= 4 else { return nil }
    
    let signature = data.withUnsafeBytes { bytes in
        bytes.load(as: UInt32.self).littleEndian
    }
    
    if signature != TNEF_SIGNATURE { return nil }
    
    var tnef = TNEFMessage()
    var currentAttachment: TNEFAttachment?
    var offset = 6
    
    while offset < data.count {
        guard let obj = decodeTNEFObject(data: data, offset: offset) else { break }
        
        offset += obj.length
        
        if obj.name == ATTATTACHRENDDATA {
            currentAttachment = TNEFAttachment()
            tnef.attachments.append(currentAttachment!)
        } else if obj.level == LEVEL_ATTACHMENT {
            if currentAttachment != nil {
                addAttribute(obj: obj, attachment: &tnef.attachments[tnef.attachments.count - 1])
            }
        } else if obj.name == ATTMAPIPROPS {
            if let mapiAttrs = decodeMAPI(data: obj.data) {
                tnef.attributes = mapiAttrs
                
                for (name, data) in mapiAttrs {
                    if name == "MAPIBody" {
                        tnef.body = String(data: data, encoding: .utf8) ?? ""
                    } else if name == "MAPIBodyHTML" {
                        tnef.bodyHTML = String(data: data, encoding: .utf8) ?? ""
                    }
                }
            }
        }
    }
    
    return tnef
}

func decodeTNEFObject(data: Data, offset: Int) -> (level: UInt8, name: UInt16, type: UInt16, data: Data, length: Int)? {
    guard offset + 8 <= data.count else { return nil }
    
    let bytes = Array(data)
    var pos = offset
    
    let level = bytes[pos]
    pos += 1
    
    let name = UInt16(bytes[pos]) | (UInt16(bytes[pos + 1]) << 8)
    pos += 2
    
    let type = UInt16(bytes[pos]) | (UInt16(bytes[pos + 1]) << 8)
    pos += 2
    
    let length = UInt32(bytes[pos]) | (UInt32(bytes[pos + 1]) << 8) | (UInt32(bytes[pos + 2]) << 16) | (UInt32(bytes[pos + 3]) << 24)
    pos += 4
    
    guard pos + Int(length) + 2 <= data.count else { return nil }
    let attrData = data.subdata(in: pos..<(pos + Int(length)))
    pos += Int(length)
    pos += 2
    
    let totalLength = pos - offset
    
    return (level: level, name: name, type: type, data: attrData, length: totalLength)
}

func addAttribute(obj: (level: UInt8, name: UInt16, type: UInt16, data: Data, length: Int), attachment: inout TNEFAttachment) {
    switch obj.name {
    case ATTATTACHTITLE:
        if let title = String(data: obj.data, encoding: .utf8) {
            attachment.title = title.replacingOccurrences(of: "\0", with: "")
        }
    case ATTATTACHDATA:
        attachment.data = obj.data
    default:
        break
    }
}

func decodeMAPI(data: Data) -> [String: Data]? {
    guard data.count >= 4 else { return nil }
    
    let bytes = Array(data)
    var pos = 0
    
    let numProperties = UInt32(bytes[pos]) | (UInt32(bytes[pos + 1]) << 8) | (UInt32(bytes[pos + 2]) << 16) | (UInt32(bytes[pos + 3]) << 24)
    pos += 4
    
    var attributes: [String: Data] = [:]
    
    for _ in 0..<numProperties {
        guard pos + 4 <= data.count else { break }
        
        let attrType = UInt16(bytes[pos]) | (UInt16(bytes[pos + 1]) << 8)
        pos += 2
        
        let attrName = UInt16(bytes[pos]) | (UInt16(bytes[pos + 1]) << 8)
        pos += 2
        
        if attrName == MAPIBody {
            let length = getMAPITypeSize(attrType)
            if length > 0 && pos + length <= data.count {
                let attrData = data.subdata(in: pos..<(pos + length))
                attributes["MAPIBody"] = attrData
            }
        } else if attrName == MAPIBodyHTML {
            let length = getMAPITypeSize(attrType)
            if length > 0 && pos + length <= data.count {
                let attrData = data.subdata(in: pos..<(pos + length))
                attributes["MAPIBodyHTML"] = attrData
            }
        }
        
        let length = getMAPITypeSize(attrType)
        if length > 0 {
            pos += length
        } else {
            guard pos + 4 <= data.count else { break }
            let varLength = UInt32(bytes[pos]) | (UInt32(bytes[pos + 1]) << 8) | (UInt32(bytes[pos + 2]) << 16) | (UInt32(bytes[pos + 3]) << 24)
            pos += 4 + Int(varLength)
        }
        
        pos = (pos + 3) & ~3
    }
    
    return attributes
}

func getMAPITypeSize(_ type: UInt16) -> Int {
    switch type {
    case 0x0002: return 2
    case 0x0003: return 4
    case 0x0004: return 4
    case 0x0005: return 8
    case 0x000A: return 4
    case 0x000B: return 2
    case 0x0040: return 8
    case 0x0048: return 16
    case 0x001E, 0x001F, 0x0102: return -1
    default: return 0
    }
}

func createZIP(tnef: TNEFMessage, outputPath: String) {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("tnef_extract")
    try? FileManager.default.removeItem(at: tempDir)
    try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    
    var extractedFiles: [String] = []
    
    for (index, attachment) in tnef.attachments.enumerated() {
        if !attachment.title.isEmpty && !attachment.data.isEmpty {
            let fileName = attachment.title.isEmpty ? "attachment_\(index).bin" : attachment.title
            let filePath = tempDir.appendingPathComponent(fileName)
            
            do {
                try attachment.data.write(to: filePath)
                extractedFiles.append(fileName)
            } catch {
                continue
            }
        }
    }
    
    if !tnef.body.isEmpty {
        let bodyPath = tempDir.appendingPathComponent("body.txt")
        try? tnef.body.write(to: bodyPath, atomically: true, encoding: .utf8)
        extractedFiles.append("body.txt")
    }
    
    if !tnef.bodyHTML.isEmpty {
        let htmlPath = tempDir.appendingPathComponent("body.html")
        try? tnef.bodyHTML.write(to: htmlPath, atomically: true, encoding: .utf8)
        extractedFiles.append("body.html")
    }
    
    let currentDir = FileManager.default.currentDirectoryPath
    let absoluteZipPath = "\(currentDir)/\(outputPath)"
    
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
    process.arguments = ["-r", absoluteZipPath] + extractedFiles
    process.currentDirectoryURL = tempDir
    
    try? process.run()
    process.waitUntilExit()
    
    try? FileManager.default.removeItem(at: tempDir)
}

func main() {
    let args = CommandLine.arguments
    
    if args.count < 2 {
        print("Usage: swift main.swift <file.dat>")
        return
    }
    
    let filePath = args[1]
    
    do {
        let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
        
        if let tnef = parseTNEF(data: data) {
            let outputPath = filePath + "_extracted.zip"
            createZIP(tnef: tnef, outputPath: outputPath)
        }
        
    } catch {
        print("Error reading file: \(error)")
    }
}

main()
