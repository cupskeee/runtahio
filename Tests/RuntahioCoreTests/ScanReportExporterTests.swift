import XCTest
@testable import RuntahioCore

final class ScanReportExporterTests: XCTestCase {
    private func sampleResult(rootName: String = "root", extraFile: DiskNode? = nil) -> ScanResult {
        var children = [
            TestTree.file("movie.mp4", size: 5_000, parentID: "/\(rootName)", depth: 1, ext: "mp4"),
            TestTree.file(
                "report.pdf", size: 3_000, parentID: "/\(rootName)", depth: 1, ext: "pdf"),
        ]
        if let extraFile { children.append(extraFile) }
        return TestTree.result(root: TestTree.root(rootName, children: children))
    }

    func testJSONRoundTrips() throws {
        let data = ScanReportExporter.json(sampleResult(), useAllocated: false, topFilesLimit: 10)
        XCTAssertFalse(data.isEmpty)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let report = try decoder.decode(ScanReportExporter.Report.self, from: data)

        XCTAssertEqual(report.totalSizeBytes, 8_000)
        XCTAssertEqual(report.fileCount, 2)
        XCTAssertEqual(report.largestFiles.first?.path, "/root/movie.mp4")
        XCTAssertEqual(report.largestFiles.first?.sizeBytes, 5_000)
        let video = report.categories.first { $0.category == "video" }
        XCTAssertEqual(video?.totalSizeBytes, 5_000)
    }

    func testCSVHasHeaderAndRows() {
        let csv = ScanReportExporter.csv(sampleResult(), useAllocated: false, topFilesLimit: 10)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        XCTAssertEqual(lines.first, "Path,Size (bytes),Kind,Modified")
        XCTAssertEqual(lines.count, 3)  // header + 2 files
        XCTAssertTrue(lines[1].contains("/root/movie.mp4"))
        XCTAssertTrue(lines[1].contains("5000"))
    }

    func testCSVQuotesFieldsWithCommas() {
        let comma = TestTree.file(
            "weird, name.txt", size: 9_999, parentID: "/root", depth: 1, ext: "txt")
        let csv = ScanReportExporter.csv(
            sampleResult(extraFile: comma), useAllocated: false, topFilesLimit: 10)
        XCTAssertTrue(
            csv.contains("\"/root/weird, name.txt\""),
            "paths with commas must be quoted: \(csv)")
    }

    func testEscapeCSVDoublesQuotes() {
        XCTAssertEqual(ScanReportExporter.escapeCSV("a\"b"), "\"a\"\"b\"")
        XCTAssertEqual(ScanReportExporter.escapeCSV("plain"), "plain")
    }
}
