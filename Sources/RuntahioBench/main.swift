import Foundation
import RuntahioCore

#if canImport(Darwin)
    import Darwin
#endif

// Minimal benchmark harness: scans a path with the same metadata-only scanner the app
// uses, then prints the file/folder counts, wall-clock time, and peak resident memory.
//
// Usage: swift run -c release RuntahioBench <path>
// Driven by Scripts/benchmark.sh, which generates synthetic trees and tabulates results.

/// Peak resident set size of this process, in bytes. `ru_maxrss` is bytes on Darwin.
func peakResidentBytes() -> Int64 {
    var usage = rusage()
    guard getrusage(RUSAGE_SELF, &usage) == 0 else { return 0 }
    return Int64(usage.ru_maxrss)
}

guard CommandLine.arguments.count > 1 else {
    FileHandle.standardError.write(Data("usage: RuntahioBench <path>\n".utf8))
    exit(2)
}

let url = URL(fileURLWithPath: CommandLine.arguments[1])
let scanner = ScannerService()

let started = Date()
var result: ScanResult?
for await event in await scanner.scan(root: url, options: ScanOptions()) {
    switch event {
    case .finished(let scanResult): result = scanResult
    case .failed(let error):
        FileHandle.standardError.write(Data("scan failed: \(error)\n".utf8))
        exit(1)
    case .progress: break
    }
}
let wallSeconds = Date().timeIntervalSince(started)

guard let result else {
    FileHandle.standardError.write(Data("no result\n".utf8))
    exit(1)
}

let peakMB = Double(peakResidentBytes()) / 1_048_576
let summary = String(
    format: "files=%d folders=%d inaccessible=%d wall=%.2f peakMB=%.0f",
    result.fileCount, result.folderCount, result.inaccessibleCount, wallSeconds, peakMB)
print(summary)
