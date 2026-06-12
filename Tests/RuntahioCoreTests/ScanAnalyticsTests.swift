import XCTest
@testable import RuntahioCore

final class ScanAnalyticsTests: XCTestCase {
    private func sampleTree() -> DiskNode {
        let d0 = Date(timeIntervalSince1970: 1_000)
        let d1 = Date(timeIntervalSince1970: 2_000)
        let d2 = Date(timeIntervalSince1970: 3_000)
        let media = TestTree.dir(
            "media", parentID: "/root", depth: 1,
            children: [
                TestTree.file(
                    "movie.mp4", size: 5_000, parentID: "/root/media", depth: 2, ext: "mp4",
                    modified: d2),
                TestTree.file(
                    "song.mp3", size: 1_000, parentID: "/root/media", depth: 2, ext: "mp3",
                    modified: d0),
            ])
        let docs = TestTree.dir(
            "docs", parentID: "/root", depth: 1,
            children: [
                TestTree.file(
                    "report.pdf", size: 3_000, parentID: "/root/docs", depth: 2, ext: "pdf",
                    modified: d1),
                // A duplicate of media/song.mp3 (same name + size) in another folder.
                TestTree.file(
                    "song.mp3", size: 1_000, parentID: "/root/docs", depth: 2, ext: "mp3",
                    modified: d1),
            ])
        return TestTree.root("root", children: [media, docs])
    }

    func testLargestFiles() {
        let largest = ScanAnalytics.largestFiles(in: sampleTree(), limit: 3, useAllocated: false)
        XCTAssertEqual(largest.map(\.name), ["movie.mp4", "report.pdf", "song.mp3"])
        XCTAssertEqual(largest.first?.byteSize, 5_000)
    }

    func testLargestFilesRespectsLimit() {
        XCTAssertEqual(
            ScanAnalytics.largestFiles(in: sampleTree(), limit: 1, useAllocated: false).count, 1)
    }

    func testOldestFiles() {
        let oldest = ScanAnalytics.oldestFiles(in: sampleTree(), limit: 2, useAllocated: false)
        // song.mp3 (t=1000) is oldest; report.pdf and the dup song.mp3 share t=2000.
        XCTAssertEqual(oldest.first?.byteSize, 1_000)
        XCTAssertEqual(oldest.first?.modifiedDate, Date(timeIntervalSince1970: 1_000))
    }

    func testOldestFilesMinSizeFilter() {
        // Only files >= 3000 bytes; the oldest such is report.pdf (3000, t=2000).
        let oldest = ScanAnalytics.oldestFiles(
            in: sampleTree(), limit: 5, minSize: 3_000, useAllocated: false)
        XCTAssertEqual(oldest.map(\.byteSize), [3_000, 5_000])
    }

    func testCategoryBreakdown() {
        let breakdown = ScanAnalytics.categoryBreakdown(in: sampleTree(), useAllocated: false)
        let byCategory = Dictionary(uniqueKeysWithValues: breakdown.map { ($0.category, $0) })
        XCTAssertEqual(byCategory[.video]?.totalSize, 5_000)
        XCTAssertEqual(byCategory[.audio]?.totalSize, 2_000)  // two song.mp3 of 1000 each
        XCTAssertEqual(byCategory[.audio]?.fileCount, 2)
        XCTAssertEqual(byCategory[.document]?.totalSize, 3_000)
        // Sorted by total size descending.
        XCTAssertEqual(breakdown.first?.category, .video)
    }

    func testDuplicateGroups() {
        let groups = ScanAnalytics.duplicateGroups(in: sampleTree(), minSize: 0)
        XCTAssertEqual(groups.count, 1)
        let group = try? XCTUnwrap(groups.first)
        XCTAssertEqual(group?.name, "song.mp3")
        XCTAssertEqual(group?.size, 1_000)
        XCTAssertEqual(group?.count, 2)
        XCTAssertEqual(group?.reclaimable, 1_000)  // keep one, reclaim one
        XCTAssertEqual(group?.extras.count, 1)
    }

    func testDuplicateGroupsMinSizeExcludesSmall() {
        XCTAssertTrue(ScanAnalytics.duplicateGroups(in: sampleTree(), minSize: 2_000).isEmpty)
    }

    func testExcludingRemovesItems() {
        let tree = sampleTree()
        let largest = ScanAnalytics.largestFiles(
            in: tree, limit: 5, useAllocated: false, excluding: ["/root/media/movie.mp4"])
        XCTAssertFalse(largest.contains { $0.name == "movie.mp4" })
        XCTAssertEqual(largest.first?.name, "report.pdf")
    }

    func testLeavesExcludeContainersAndInaccessible() {
        let leaves = ScanAnalytics.leaves(in: sampleTree())
        XCTAssertEqual(leaves.count, 4)  // movie, song, report, dup-song
        XCTAssertFalse(leaves.contains { $0.type == .directory })
    }
}
