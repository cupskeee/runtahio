import Foundation

/// Exports a scan as a JSON or CSV report. Pure and testable; the app writes the bytes via
/// a save panel. No network — everything stays local.
public enum ScanReportExporter {

    public struct Report: Codable, Sendable, Equatable {
        public let rootPath: String
        public let totalSizeBytes: Int64
        public let allocatedTotalBytes: Int64
        public let fileCount: Int
        public let folderCount: Int
        public let inaccessibleCount: Int
        public let scanFinishedAt: Date
        public let categories: [CategoryEntry]
        public let largestFiles: [FileEntry]
    }

    public struct CategoryEntry: Codable, Sendable, Equatable {
        public let category: String
        public let totalSizeBytes: Int64
        public let fileCount: Int
    }

    public struct FileEntry: Codable, Sendable, Equatable {
        public let path: String
        public let sizeBytes: Int64
        public let kind: String
        public let modified: Date?
    }

    /// Builds the structured report (also used directly by tests).
    public static func makeReport(
        _ result: ScanResult, useAllocated: Bool, topFilesLimit: Int = 100,
        excluding: Set<String> = []
    ) -> Report {
        let categories =
            ScanAnalytics
            .categoryBreakdown(
                in: result.rootNode, useAllocated: useAllocated, excluding: excluding
            )
            .map {
                CategoryEntry(
                    category: $0.category.rawValue, totalSizeBytes: $0.totalSize,
                    fileCount: $0.fileCount)
            }

        let largest =
            ScanAnalytics
            .largestFiles(
                in: result.rootNode, limit: topFilesLimit, useAllocated: useAllocated,
                excluding: excluding
            )
            .map {
                FileEntry(
                    path: $0.url.path(percentEncoded: false),
                    sizeBytes: $0.effectiveSize(useAllocated: useAllocated),
                    kind: $0.type.displayLabel,
                    modified: $0.modifiedDate)
            }

        return Report(
            rootPath: result.rootNode.url.path(percentEncoded: false),
            totalSizeBytes: result.totalSize,
            allocatedTotalBytes: result.allocatedTotal,
            fileCount: result.fileCount,
            folderCount: result.folderCount,
            inaccessibleCount: result.inaccessibleCount,
            scanFinishedAt: result.scanFinishedAt,
            categories: categories,
            largestFiles: largest)
    }

    public static func json(
        _ result: ScanResult, useAllocated: Bool, topFilesLimit: Int = 100,
        excluding: Set<String> = []
    ) -> Data {
        let report = makeReport(
            result, useAllocated: useAllocated, topFilesLimit: topFilesLimit, excluding: excluding)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(report)) ?? Data()
    }

    /// CSV of the largest files (one table, RFC-4180-style quoting).
    public static func csv(
        _ result: ScanResult, useAllocated: Bool, topFilesLimit: Int = 100,
        excluding: Set<String> = []
    ) -> String {
        let report = makeReport(
            result, useAllocated: useAllocated, topFilesLimit: topFilesLimit, excluding: excluding)
        let iso = ISO8601DateFormatter()
        var lines = ["Path,Size (bytes),Kind,Modified"]
        for file in report.largestFiles {
            let modified = file.modified.map { iso.string(from: $0) } ?? ""
            let cells = [file.path, String(file.sizeBytes), file.kind, modified].map(escapeCSV)
            lines.append(cells.joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Quotes a CSV field when it contains a comma, quote, or newline (doubling quotes).
    static func escapeCSV(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else {
            return field
        }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
