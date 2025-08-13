import XCTest
@testable import TNEFSwift

final class TNEFSwiftTests: XCTestCase {
    func testTNEFSignature() throws {
        XCTAssertEqual(TNEF_SIGNATURE, 0x223E9F78)
    }
    
    func testTNEFMessageInitialization() throws {
        let message = TNEFMessage()
        XCTAssertEqual(message.attachments.count, 0)
        XCTAssertEqual(message.body, "")
        XCTAssertEqual(message.bodyHTML, "")
        XCTAssertEqual(message.attributes.count, 0)
    }
    
    func testTNEFAttachmentInitialization() throws {
        let attachment = TNEFAttachment(title: "test.txt", data: Data([1, 2, 3]))
        XCTAssertEqual(attachment.title, "test.txt")
        XCTAssertEqual(attachment.data.count, 3)
    }
    
    func testParseTNEFWithInvalidData() throws {
        let invalidData = Data([0, 0, 0, 0])
        let result = parseTNEF(data: invalidData)
        XCTAssertNil(result)
    }
}
