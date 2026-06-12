import XCTest
@testable import RuntahioCore

final class ByteSizeFormatterTests: XCTestCase {
    let formatter = ByteSizeFormatter(style: .file)

    func testUnitsAppearForMagnitudes() {
        XCTAssertTrue(formatter.string(fromByteCount: 1_000_000).contains("MB"))
        XCTAssertTrue(formatter.string(fromByteCount: 2_000_000_000).contains("GB"))
        XCTAssertTrue(formatter.string(fromByteCount: 1_000).contains("KB"))
    }

    func testSmallSizesUseBytes() {
        let s = formatter.string(fromByteCount: 500)
        XCTAssertTrue(s.lowercased().contains("byte"), "expected a bytes unit, got \(s)")
    }

    func testNegativeIsClampedToZero() {
        XCTAssertEqual(formatter.string(fromByteCount: -1234), formatter.string(fromByteCount: 0))
    }

    func testSharedConvenienceMatchesInstance() {
        XCTAssertEqual(
            ByteSizeFormatter.string(1_500_000),
            ByteSizeFormatter.shared.string(fromByteCount: 1_500_000))
    }
}
