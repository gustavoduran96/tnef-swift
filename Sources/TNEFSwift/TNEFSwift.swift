import Foundation

public let TNEF_SIGNATURE: UInt32 = 0x223E9F78
public let LEVEL_MESSAGE: UInt8 = 0x01
public let LEVEL_ATTACHMENT: UInt8 = 0x02

public let ATTATTACHTITLE: UInt16 = 0x8010
public let ATTATTACHDATA: UInt16 = 0x800F
public let ATTATTACHRENDDATA: UInt16 = 0x9002
public let ATTMAPIPROPS: UInt16 = 0x9003

public let MAPIBody: UInt16 = 0x1000
public let MAPIBodyHTML: UInt16 = 0x1013

public struct TNEFAttachment {
    public var title: String = ""
    public var data: Data = Data()
    
    public init(title: String = "", data: Data = Data()) {
        self.title = title
        self.data = data
    }
}

public struct TNEFMessage {
    public var attachments: [TNEFAttachment] = []
    public var body: String = ""
    public var bodyHTML: String = ""
    public var attributes: [String: Data] = [:]
    
    public init(attachments: [TNEFAttachment] = [], body: String = "", bodyHTML: String = "", attributes: [String: Data] = [:]) {
        self.attachments = attachments
        self.body = body
        self.bodyHTML = bodyHTML
        self.attributes = attributes
    }
}

public func parseTNEF(data: Data) -> TNEFMessage? {
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
    if obj.name == ATTATTACHTITLE {
        attachment.title = String(data: obj.data, encoding: .utf8) ?? ""
    } else if obj.name == ATTATTACHDATA {
        attachment.data = obj.data
    }
}

func decodeMAPI(data: Data) -> [String: Data]? {
    var attributes: [String: Data] = [:]
    var offset = 0
    
    while offset < data.count {
        guard offset + 8 <= data.count else { break }
        
        let bytes = Array(data)
        var pos = offset
        
        let type = UInt16(bytes[pos]) | (UInt16(bytes[pos + 1]) << 8)
        pos += 2
        
        let nameLength = UInt16(bytes[pos]) | (UInt16(bytes[pos + 1]) << 8)
        pos += 2
        
        let valueLength = UInt32(bytes[pos]) | (UInt32(bytes[pos + 1]) << 8) | (UInt32(bytes[pos + 2]) << 16) | (UInt32(bytes[pos + 3]) << 24)
        pos += 4
        
        guard pos + Int(nameLength) + Int(valueLength) <= data.count else { break }
        
        let nameData = data.subdata(in: pos..<(pos + Int(nameLength)))
        pos += Int(nameLength)
        
        let valueData = data.subdata(in: pos..<(pos + Int(valueLength)))
        pos += Int(valueLength)
        
        if let name = String(data: nameData, encoding: .utf8) {
            attributes[name] = valueData
        }
        
        offset = pos
    }
    
    return attributes
}
