import Foundation
import XCTest
@testable import RuntahioCore

/// Builders for synthetic `DiskNode` trees (no filesystem needed) and on-disk fixtures.
enum TestTree {
    static func file(_ name: String, size: Int64, parentID: String, depth: Int, ext: String? = nil) -> DiskNode {
        let id = parentID + "/" + name
        return DiskNode(
            id: id, parentID: parentID, name: name, url: URL(fileURLWithPath: id),
            type: .file, depth: depth, isHidden: false, isReadable: true, isPackage: false,
            isSymlink: false, fileExtension: ext, modifiedDate: nil, createdDate: nil,
            byteSize: size, allocatedSize: size, children: [],
            fileCount: 0, folderCount: 0, inaccessibleCount: 0, scanError: nil)
    }

    static func dir(_ name: String, parentID: String, depth: Int, children: [DiskNode]) -> DiskNode {
        let id = parentID + "/" + name
        return container(id: id, name: name, parentID: parentID, depth: depth, type: .directory, children: children)
    }

    static func root(_ name: String, children: [DiskNode]) -> DiskNode {
        container(id: "/" + name, name: name, parentID: nil, depth: 0, type: .directory, children: children)
    }

    private static func container(
        id: String, name: String, parentID: String?, depth: Int, type: NodeType, children: [DiskNode]
    ) -> DiskNode {
        let byteSize = children.reduce(Int64(0)) { $0 + $1.byteSize }
        let allocated = children.reduce(Int64(0)) { $0 + $1.allocatedSize }
        var f = 0, d = 0, i = 0
        for c in children {
            switch c.type {
            case .file, .symlink, .unknown: f += 1
            case .directory, .package: d += 1
            case .inaccessible: i += 1
            }
            f += c.fileCount; d += c.folderCount; i += c.inaccessibleCount
        }
        return DiskNode(
            id: id, parentID: parentID, name: name, url: URL(fileURLWithPath: id),
            type: type, depth: depth, isHidden: false, isReadable: true, isPackage: false,
            isSymlink: false, fileExtension: nil, modifiedDate: nil, createdDate: nil,
            byteSize: byteSize, allocatedSize: allocated, children: children,
            fileCount: f, folderCount: d, inaccessibleCount: i, scanError: nil)
    }

    static func index(of root: DiskNode) -> [String: DiskNode] {
        var dict: [String: DiskNode] = [:]
        func visit(_ n: DiskNode) { dict[n.id] = n; n.children.forEach(visit) }
        visit(root)
        return dict
    }

    static func result(root: DiskNode) -> ScanResult {
        ScanResult(
            rootNode: root, totalSize: root.byteSize, allocatedTotal: root.allocatedSize,
            fileCount: root.fileCount, folderCount: root.folderCount,
            inaccessibleCount: root.inaccessibleCount,
            scanStartedAt: Date(), scanFinishedAt: Date(), warnings: [], index: index(of: root))
    }
}

/// Temp-directory fixture helpers for scanner/cleanup tests.
enum TempFixture {
    static func makeUniqueDir() throws -> URL {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("runtahio-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    @discardableResult
    static func writeFile(_ name: String, bytes: Int, in dir: URL) throws -> URL {
        let url = dir.appendingPathComponent(name)
        try Data(count: bytes).write(to: url)
        return url
    }

    @discardableResult
    static func makeDir(_ name: String, in dir: URL) throws -> URL {
        let url = dir.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Best-effort recursive removal; restores permissions so chmod-000 dirs can be deleted.
    static func cleanup(_ url: URL) {
        let fm = FileManager.default
        if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: nil) {
            for case let child as URL in enumerator {
                try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: child.path)
            }
        }
        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        try? fm.removeItem(at: url)
    }
}

/// Drives a scan to completion and returns the terminal outcome plus collected progress.
extension ScannerService {
    func scanToCompletion(root: URL, options: ScanOptions) async -> (result: ScanResult?, failure: ScanError?, progressCount: Int) {
        var result: ScanResult?
        var failure: ScanError?
        var progressCount = 0
        for await event in scan(root: root, options: options) {
            switch event {
            case .progress: progressCount += 1
            case .finished(let r): result = r
            case .failed(let e): failure = e
            }
        }
        return (result, failure, progressCount)
    }
}
