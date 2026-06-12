import XCTest
@testable import RuntahioCore

final class CleanupServiceTests: XCTestCase {

    private func item(for url: URL, byteSize: Int64, allocated: Int64) -> BasketItem {
        BasketItem(
            id: url.standardizedFileURL.path(percentEncoded: false),
            name: url.lastPathComponent, url: url,
            byteSize: byteSize, allocatedSize: allocated, type: .file)
    }

    func testMoveToTrashMovesItemAndKeepsRecoverableCopy() async throws {
        let dir = try TempFixture.makeUniqueDir()
        defer { TempFixture.cleanup(dir) }
        let fileURL = try TempFixture.writeFile("trashme.txt", bytes: 1234, in: dir)

        let service = CleanupService()
        let summary = await service.moveToTrash([
            item(for: fileURL, byteSize: 1234, allocated: 4096)
        ])

        XCTAssertTrue(summary.allSucceeded, "expected the trash to succeed: \(summary.failed)")
        XCTAssertEqual(summary.movedCount, 1)
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: fileURL.path),
            "original should no longer be at its path")

        let resulting = try XCTUnwrap(summary.succeeded.first?.resultingURL)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: resulting.path),
            "a recoverable copy must exist in Trash (never permanently deleted)")
        XCTAssertEqual(summary.reclaimedBytes(useAllocated: false), 1234)

        // Tidy: remove the copy we created in the Trash.
        try? FileManager.default.removeItem(at: resulting)
    }

    func testPartialFailureIsIsolated() async throws {
        let dir = try TempFixture.makeUniqueDir()
        defer { TempFixture.cleanup(dir) }
        let good = try TempFixture.writeFile("good.txt", bytes: 10, in: dir)
        let missing = dir.appendingPathComponent("does-not-exist.txt")

        let service = CleanupService()
        let summary = await service.moveToTrash([
            item(for: good, byteSize: 10, allocated: 4096),
            item(for: missing, byteSize: 99, allocated: 99),
        ])

        XCTAssertEqual(summary.movedCount, 1)
        XCTAssertEqual(summary.failedCount, 1)
        XCTAssertFalse(summary.allSucceeded)
        XCTAssertNotNil(summary.failed.first?.errorMessage)

        if let resulting = summary.succeeded.first?.resultingURL {
            try? FileManager.default.removeItem(at: resulting)
        }
    }

    func testEmptyInputProducesEmptySummary() async throws {
        let service = CleanupService()
        let summary = await service.moveToTrash([])
        XCTAssertEqual(summary.movedCount, 0)
        XCTAssertEqual(summary.failedCount, 0)
        XCTAssertTrue(summary.allSucceeded)
    }
}
