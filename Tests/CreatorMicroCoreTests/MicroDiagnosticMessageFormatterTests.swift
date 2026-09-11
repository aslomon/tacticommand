import Foundation
import XCTest

@testable import CreatorMicroCore

final class MicroDiagnosticMessageFormatterTests: XCTestCase {
    func testMalformedJSONUsesPlainLanguageWithoutSwiftInternals() {
        let data = Data(#"{} }"#.utf8)

        XCTAssertThrowsError(try MicroMessageParser.parse(data)) { error in
            let message = MicroDiagnosticMessageFormatter.message(for: error)

            XCTAssertEqual(
                message,
                "The device sent an unreadable message. It was ignored; control remains active."
            )
            XCTAssertFalse(message.contains("DecodingError"))
            XCTAssertFalse(message.contains("codingPath"))
        }
    }

    func testDomainErrorsKeepTheirReadableDescriptions() {
        let error = MicroMessageParserError.unknownControl("ACT99")

        XCTAssertEqual(
            MicroDiagnosticMessageFormatter.message(for: error),
            "The device reported an unknown control: ACT99."
        )
    }
}
