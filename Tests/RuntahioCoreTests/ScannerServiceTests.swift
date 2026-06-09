import XCTest
@testable import RuntahioCore

final class ScannerServiceTests: XCTestCase {

    func testNestedKnownSizesAggregate() async throws {
        let root = try TempFixture.makeUniqueDir()
        defer { TempFixture.cleanup(root) }
        try TempFixture.writeFile("a.txt", bytes: 1000, in: root)
        let sub = try TempFixture.makeDir("sub", in: root)
        try TempFixture.writeFile("b.txt", bytes: 2000, in: sub)
        try TempFixture.writeFile("c.bin", bytes: 3000, in: sub)
        _ = try TempFixture.makeDir("empty", in: root)

        let scanner = ScannerService()
        let (result, failure, _) = await scanner.scanToCompletion(root: root, options: ScanOptions())

        XCTAssertNil(failure)
        let r = try XCTUnwrap(result)
        XCTAssertEqual(r.totalSize, 6000)
        XCTAssertEqual(r.fileCount, 3)
        XCTAssertEqual(r.folderCount, 2) // sub + empty
        XCTAssertEqual(r.inaccessibleCount, 0)
        XCTAssertGreaterThanOrEqual(r.allocatedTotal, r.totalSize)

        let subNode = try XCTUnwrap(r.rootNode.children.first { $0.name == "sub" })
        XCTAssertEqual(subNode.byteSize, 5000)
        let emptyNode = try XCTUnwrap(r.rootNode.children.first { $0.name == "empty" })
        XCTAssertEqual(emptyNode.byteSize, 0)
        XCTAssertEqual(emptyNode.type, .directory)
    }

    func testZeroByteFile() async throws {
        let root = try TempFixture.makeUniqueDir()
        defer { TempFixture.cleanup(root) }
        try TempFixture.writeFile("zero", bytes: 0, in: root)
        let scanner = ScannerService()
        let (result, _, _) = await scanner.scanToCompletion(root: root, options: ScanOptions())
        let r = try XCTUnwrap(result)
        let zero = try XCTUnwrap(r.rootNode.children.first { $0.name == "zero" })
        XCTAssertEqual(zero.byteSize, 0)
        XCTAssertEqual(zero.type, .file)
    }

    func testHiddenFilesAreAlwaysCounted() async throws {
        let root = try TempFixture.makeUniqueDir()
        defer { TempFixture.cleanup(root) }
        try TempFixture.writeFile("visible.txt", bytes: 100, in: root)
        try TempFixture.writeFile(".secret", bytes: 500, in: root)

        let scanner = ScannerService()
        // showHidden = false should NOT change counting — only display does.
        let (result, _, _) = await scanner.scanToCompletion(
            root: root, options: ScanOptions(showHidden: false))
        let r = try XCTUnwrap(result)
        let hidden = try XCTUnwrap(r.rootNode.children.first { $0.name == ".secret" })
        XCTAssertTrue(hidden.isHidden)
        XCTAssertEqual(r.fileCount, 2)
    }

    func testExcludedNamesAreSkipped() async throws {
        let root = try TempFixture.makeUniqueDir()
        defer { TempFixture.cleanup(root) }
        try TempFixture.writeFile("keep.txt", bytes: 100, in: root)
        let nofollow = try TempFixture.makeDir(".nofollow", in: root)
        try TempFixture.writeFile("dup.bin", bytes: 999_999, in: nofollow)

        let scanner = ScannerService()

        // Default options exclude ".nofollow", so it doesn't inflate the total.
        let (result, _, _) = await scanner.scanToCompletion(root: root, options: ScanOptions())
        let r = try XCTUnwrap(result)
        XCTAssertFalse(r.rootNode.children.contains { $0.name == ".nofollow" })
        XCTAssertEqual(r.totalSize, 100)

        // With exclusions cleared, the directory IS scanned and counted.
        let (included, _, _) = await scanner.scanToCompletion(
            root: root, options: ScanOptions(excludedNames: []))
        let i = try XCTUnwrap(included)
        XCTAssertTrue(i.rootNode.children.contains { $0.name == ".nofollow" })
        XCTAssertEqual(i.totalSize, 999_999 + 100)
    }

    func testSymlinksAreNotFollowed() async throws {
        let root = try TempFixture.makeUniqueDir()
        defer { TempFixture.cleanup(root) }
        let target = try TempFixture.writeFile("target.txt", bytes: 100, in: root)
        let realDir = try TempFixture.makeDir("realdir", in: root)
        try TempFixture.writeFile("inside.txt", bytes: 777, in: realDir)
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("flink"), withDestinationURL: target)
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("dlink"), withDestinationURL: realDir)

        let scanner = ScannerService()
        let (result, _, _) = await scanner.scanToCompletion(root: root, options: ScanOptions())
        let r = try XCTUnwrap(result)

        let flink = try XCTUnwrap(r.rootNode.children.first { $0.name == "flink" })
        XCTAssertEqual(flink.type, .symlink)
        XCTAssertTrue(flink.children.isEmpty)

        let dlink = try XCTUnwrap(r.rootNode.children.first { $0.name == "dlink" })
        XCTAssertEqual(dlink.type, .symlink)
        XCTAssertTrue(dlink.children.isEmpty, "a symlink to a directory must not be descended")

        // inside.txt counted once (via realdir only), plus target + 2 symlinks = 4 files.
        XCTAssertEqual(r.fileCount, 4)
        XCTAssertEqual(r.folderCount, 1)
    }

    func testPackageIsLeafByDefaultButDrillableWhenRequested() async throws {
        let root = try TempFixture.makeUniqueDir()
        defer { TempFixture.cleanup(root) }
        // A .app-like package directory with an inner file.
        let pkg = try TempFixture.makeDir("Thing.app", in: root)
        let contents = try TempFixture.makeDir("Contents", in: pkg)
        try TempFixture.writeFile("Info.plist", bytes: 400, in: contents)

        let scanner = ScannerService()

        let (leafResult, _, _) = await scanner.scanToCompletion(root: root, options: ScanOptions())
        let leaf = try XCTUnwrap(leafResult)
        let pkgNode = try XCTUnwrap(leaf.rootNode.children.first { $0.name == "Thing.app" })
        XCTAssertEqual(pkgNode.type, .package)
        XCTAssertTrue(pkgNode.children.isEmpty, "package presented as a leaf by default")
        XCTAssertEqual(pkgNode.byteSize, 400, "package still reports aggregated interior size")

        let (folderResult, _, _) = await scanner.scanToCompletion(
            root: root, options: ScanOptions(treatPackagesAsFolders: true))
        let folder = try XCTUnwrap(folderResult)
        let drillable = try XCTUnwrap(folder.rootNode.children.first { $0.name == "Thing.app" })
        XCTAssertFalse(drillable.children.isEmpty, "package drillable when treatPackagesAsFolders is on")
        XCTAssertEqual(drillable.byteSize, 400)
    }

    func testInaccessibleDirectoryIsIsolated() async throws {
        let root = try TempFixture.makeUniqueDir()
        defer { TempFixture.cleanup(root) }
        let locked = try TempFixture.makeDir("locked", in: root)
        try TempFixture.writeFile("secret", bytes: 10, in: locked)
        try TempFixture.writeFile("readable.txt", bytes: 50, in: root)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)

        let scanner = ScannerService()
        let (result, failure, _) = await scanner.scanToCompletion(root: root, options: ScanOptions())

        // Restore permissions so the fixture can be torn down.
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path)

        XCTAssertNil(failure)
        let r = try XCTUnwrap(result)
        XCTAssertGreaterThanOrEqual(r.inaccessibleCount, 1)
        XCTAssertTrue(r.rootNode.children.contains { $0.name == "readable.txt" },
                      "siblings of an inaccessible directory keep scanning")
        let lockedNode = try XCTUnwrap(r.rootNode.children.first { $0.name == "locked" })
        XCTAssertEqual(lockedNode.type, .inaccessible)
        XCTAssertNotNil(lockedNode.scanError)
    }

    func testNormalScanEmitsProgressAndFinishes() async throws {
        let root = try TempFixture.makeUniqueDir()
        defer { TempFixture.cleanup(root) }
        for i in 0..<50 { try TempFixture.writeFile("f\(i).txt", bytes: 10, in: root) }

        let scanner = ScannerService()
        let (result, failure, progressCount) = await scanner.scanToCompletion(
            root: root, options: ScanOptions(emitEveryNItems: 8))
        XCTAssertNil(failure)
        XCTAssertNotNil(result)
        XCTAssertGreaterThan(progressCount, 0)
    }

    func testCancellationStopsScanAndActorStaysUsable() async throws {
        let root = try TempFixture.makeUniqueDir()
        defer { TempFixture.cleanup(root) }
        for i in 0..<3000 { try TempFixture.writeFile("f\(i).txt", bytes: 4, in: root) }

        let scanner = ScannerService()
        // Break out of the stream on the first progress event → cancels the worker.
        let consume = Task { () -> Bool in
            var sawProgress = false
            for await event in await scanner.scan(root: root, options: ScanOptions(emitEveryNItems: 4)) {
                if case .progress = event { sawProgress = true; break }
            }
            return sawProgress
        }
        let sawProgress = await consume.value
        XCTAssertTrue(sawProgress)

        // The actor must still complete a fresh scan after a cancellation.
        let small = try TempFixture.makeUniqueDir()
        defer { TempFixture.cleanup(small) }
        try TempFixture.writeFile("only.txt", bytes: 5, in: small)
        let (result, _, _) = await scanner.scanToCompletion(root: small, options: ScanOptions())
        XCTAssertNotNil(result)
    }
}
