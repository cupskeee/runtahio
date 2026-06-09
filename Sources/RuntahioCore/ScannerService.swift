import Foundation

/// Recursively scans a folder/volume off the main thread and emits a single ordered
/// stream of `ScanEvent`s: throttled `.progress` snapshots, then exactly one terminal
/// `.finished` / `.failed`.
///
/// Reads **metadata only** (`URLResourceValues`) — never file contents. Never follows
/// symlinks (so there are no symlink cycles); guards firmlink/hardlink loops with a
/// resolved-real-path visited set. Per-item errors become `.inaccessible` nodes so
/// siblings keep scanning; the whole scan never throws.
public actor ScannerService {
    public init() {}

    /// Resource keys prefetched once per entry. Metadata only — reading these never
    /// materializes cloud-backed (dataless) files.
    private static let resourceKeys: Set<URLResourceKey> = [
        .nameKey, .isDirectoryKey, .isSymbolicLinkKey, .isPackageKey, .isRegularFileKey,
        .isHiddenKey, .isReadableKey, .fileSizeKey, .totalFileAllocatedSizeKey,
        .fileAllocatedSizeKey, .contentModificationDateKey, .creationDateKey, .isAliasFileKey
    ]

    /// Begins a scan. The returned stream's `onTermination` cancels the worker, so
    /// breaking out of the consuming `for await` (or cancelling its task) stops the scan.
    public func scan(root: URL, options: ScanOptions) -> AsyncStream<ScanEvent> {
        AsyncStream(bufferingPolicy: .bufferingNewest(2)) { continuation in
            let worker = Task.detached(priority: .userInitiated) {
                Self.runScan(root: root, options: options, continuation: continuation)
            }
            continuation.onTermination = { _ in worker.cancel() }
        }
    }

    private struct Cancelled: Error {}

    /// Lightweight aggregate used when measuring a package without building its nodes.
    private struct Measurement {
        var logical: Int64 = 0
        var allocated: Int64 = 0
        var fileCount: Int = 0
        var folderCount: Int = 0
        var inaccessibleCount: Int = 0
    }

    // The whole walk runs synchronously on the detached worker (no per-file actor hop).
    private static func runScan(
        root: URL,
        options: ScanOptions,
        continuation: AsyncStream<ScanEvent>.Continuation
    ) {
        let fileManager = FileManager.default
        let startedAt = Date()
        var progress = ScanProgress()
        var index: [String: DiskNode] = [:]
        var warnings: [String] = []
        var didWarnDeviceGone = false
        var visitedRealPaths = Set<String>()
        var lastEmit = ContinuousClock.now
        let interval = Duration.milliseconds(max(16, options.emitIntervalMilliseconds))

        func canonicalID(_ url: URL) -> String {
            url.standardizedFileURL.path(percentEncoded: false)
        }

        func realPath(_ url: URL) -> String {
            url.resolvingSymlinksInPath().standardizedFileURL.path(percentEncoded: false)
        }

        func emitProgress(force: Bool = false) {
            let now = ContinuousClock.now
            let dueByCount = options.emitEveryNItems > 0
                && progress.scannedItemCount % options.emitEveryNItems == 0
            let dueByTime = now - lastEmit >= interval
            guard force || dueByCount || dueByTime else { return }
            lastEmit = now
            continuation.yield(.progress(progress))
        }

        func makeInaccessible(_ url: URL, parentID: String?, depth: Int, error: Error) -> DiskNode {
            let scanError = ScanError.classify(error, underProtectedPrefix: needsFullDiskAccess(url))
            if scanError == .deviceGone, !didWarnDeviceGone {
                didWarnDeviceGone = true
                warnings.append("A volume became unavailable during the scan; some sizes may be incomplete.")
            }
            progress.inaccessibleCount += 1
            return DiskNode(
                id: canonicalID(url), parentID: parentID, name: url.lastPathComponent, url: url,
                type: .inaccessible, depth: depth, isHidden: false, isReadable: false,
                isPackage: false, isSymlink: false, fileExtension: nil,
                modifiedDate: nil, createdDate: nil, byteSize: 0, allocatedSize: 0,
                children: [], fileCount: 0, folderCount: 0, inaccessibleCount: 0, scanError: scanError
            )
        }

        func childCounts(_ children: [DiskNode]) -> (file: Int, folder: Int, inaccessible: Int) {
            var f = 0, d = 0, i = 0
            for c in children {
                switch c.type {
                case .file, .symlink, .unknown: f += 1
                case .directory, .package: d += 1
                case .inaccessible: i += 1
                }
                f += c.fileCount; d += c.folderCount; i += c.inaccessibleCount
            }
            return (f, d, i)
        }

        // Measures a package interior (size + counts) without building child nodes.
        func measure(_ url: URL, depth: Int) throws -> Measurement {
            if Task.isCancelled { throw Cancelled() }
            var m = Measurement()
            let entries: [URL]
            do {
                entries = try fileManager.contentsOfDirectory(
                    at: url, includingPropertiesForKeys: Array(resourceKeys), options: [])
            } catch {
                m.inaccessibleCount += 1
                return m
            }
            for entry in entries {
                if Task.isCancelled { throw Cancelled() }
                let v = try? entry.resourceValues(forKeys: resourceKeys)
                let isSymlink = v?.isSymbolicLink ?? false
                let isDir = v?.isDirectory ?? false
                let logical = Int64(v?.fileSize ?? 0)
                let allocated = Int64(v?.totalFileAllocatedSize ?? v?.fileAllocatedSize ?? v?.fileSize ?? 0)
                if isDir && !isSymlink {
                    let sub = try measure(entry, depth: depth + 1)
                    m.logical += sub.logical; m.allocated += sub.allocated
                    m.fileCount += sub.fileCount; m.folderCount += sub.folderCount + 1
                    m.inaccessibleCount += sub.inaccessibleCount
                } else {
                    m.logical += logical; m.allocated += allocated; m.fileCount += 1
                }
            }
            return m
        }

        func register(_ node: DiskNode, leafSize: Int64?) {
            index[node.id] = node
            progress.scannedItemCount += 1
            switch node.type {
            case .file, .symlink, .unknown: progress.scannedFileCount += 1
            case .directory, .package: progress.scannedFolderCount += 1
            case .inaccessible: break // already tallied in makeInaccessible
            }
            if let leafSize { progress.discoveredSize += leafSize }
            progress.currentPath = node.url.path(percentEncoded: false)
            progress.currentDisplayName = node.name
            progress.statusText = "Scanning \(node.name)…"
            emitProgress()
        }

        // Returns nil to *skip* an entry (vanished mid-scan, or a firmlink/hardlink cycle).
        // Throws `Cancelled` to unwind fast on cancellation. Per-item failures yield an
        // inaccessible node (not a throw).
        func walk(_ url: URL, parentID: String?, depth: Int) throws -> DiskNode? {
            if Task.isCancelled { throw Cancelled() }

            let values: URLResourceValues
            do {
                values = try url.resourceValues(forKeys: resourceKeys)
            } catch {
                let nsError = error as NSError
                if nsError.code == NSFileReadNoSuchFileError || nsError.code == NSFileNoSuchFileError {
                    return nil // vanished during scan
                }
                return makeInaccessible(url, parentID: parentID, depth: depth, error: error)
            }

            let id = canonicalID(url)
            let name = values.name ?? url.lastPathComponent
            let isSymlink = values.isSymbolicLink ?? false
            let isDirectory = values.isDirectory ?? false
            let isPackage = values.isPackage ?? false
            let isRegularFile = values.isRegularFile ?? false
            let isHidden = values.isHidden ?? false
            let isReadable = values.isReadable ?? true
            let ext = url.pathExtension.isEmpty ? nil : url.pathExtension.lowercased()
            let modified = values.contentModificationDate
            let created = values.creationDate
            let logicalSize = Int64(values.fileSize ?? 0)
            let allocatedSize = Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? values.fileSize ?? 0)

            // 1) Symlink — tested first (probe: symlinks also report isAlias). Never descend.
            if isSymlink {
                let node = DiskNode(
                    id: id, parentID: parentID, name: name, url: url, type: .symlink, depth: depth,
                    isHidden: isHidden, isReadable: isReadable, isPackage: false, isSymlink: true,
                    fileExtension: ext, modifiedDate: modified, createdDate: created,
                    byteSize: logicalSize, allocatedSize: allocatedSize, children: [],
                    fileCount: 0, folderCount: 0, inaccessibleCount: 0, scanError: nil)
                register(node, leafSize: logicalSize)
                return node
            }

            // 2) Package presented as a leaf (unless treatPackagesAsFolders) — measured.
            if isPackage && !options.treatPackagesAsFolders {
                var m = Measurement()
                do { m = try measure(url, depth: depth) }
                catch is Cancelled { throw Cancelled() }
                catch { /* keep zero measurement */ }
                let node = DiskNode(
                    id: id, parentID: parentID, name: name, url: url, type: .package, depth: depth,
                    isHidden: isHidden, isReadable: isReadable, isPackage: true, isSymlink: false,
                    fileExtension: ext, modifiedDate: modified, createdDate: created,
                    byteSize: m.logical, allocatedSize: m.allocated, children: [],
                    fileCount: m.fileCount, folderCount: m.folderCount,
                    inaccessibleCount: m.inaccessibleCount, scanError: nil)
                register(node, leafSize: m.logical)
                return node
            }

            // 3) Directory (or package treated as folder) — recurse if readable.
            if isDirectory {
                // Guard firmlink/hardlink loops via the resolved real path.
                let real = realPath(url)
                if visitedRealPaths.contains(real) { return nil }
                visitedRealPaths.insert(real)

                let entries: [URL]
                do {
                    entries = try fileManager.contentsOfDirectory(
                        at: url, includingPropertiesForKeys: Array(resourceKeys), options: [])
                } catch {
                    return makeInaccessible(url, parentID: parentID, depth: depth, error: error)
                }

                var children: [DiskNode] = []
                children.reserveCapacity(entries.count)
                for entry in entries {
                    if Task.isCancelled { throw Cancelled() }
                    // Skip excluded names (e.g. `.nofollow`, which mirrors the whole disk).
                    if options.excludedNames.contains(entry.lastPathComponent) { continue }
                    if let child = try walk(entry, parentID: id, depth: depth + 1) {
                        children.append(child)
                    }
                }

                let byteSize = children.reduce(Int64(0)) { $0 + $1.byteSize }
                let allocated = children.reduce(Int64(0)) { $0 + $1.allocatedSize }
                let counts = childCounts(children)
                let type: NodeType = (isPackage && options.treatPackagesAsFolders) ? .package : .directory
                let node = DiskNode(
                    id: id, parentID: parentID, name: name, url: url, type: type, depth: depth,
                    isHidden: isHidden, isReadable: isReadable, isPackage: isPackage, isSymlink: false,
                    fileExtension: ext, modifiedDate: modified, createdDate: created,
                    byteSize: byteSize, allocatedSize: allocated, children: children,
                    fileCount: counts.file, folderCount: counts.folder,
                    inaccessibleCount: counts.inaccessible, scanError: nil)
                register(node, leafSize: nil) // container size already counted via leaves
                return node
            }

            // 4) Regular file.
            if isRegularFile {
                let node = DiskNode(
                    id: id, parentID: parentID, name: name, url: url, type: .file, depth: depth,
                    isHidden: isHidden, isReadable: isReadable, isPackage: false, isSymlink: false,
                    fileExtension: ext, modifiedDate: modified, createdDate: created,
                    byteSize: logicalSize, allocatedSize: allocatedSize, children: [],
                    fileCount: 0, folderCount: 0, inaccessibleCount: 0, scanError: nil)
                register(node, leafSize: logicalSize)
                return node
            }

            // 5) Unknown object — keep it as a leaf with whatever size we have.
            let node = DiskNode(
                id: id, parentID: parentID, name: name, url: url, type: .unknown, depth: depth,
                isHidden: isHidden, isReadable: isReadable, isPackage: false, isSymlink: false,
                fileExtension: ext, modifiedDate: modified, createdDate: created,
                byteSize: logicalSize, allocatedSize: allocatedSize, children: [],
                fileCount: 0, folderCount: 0, inaccessibleCount: 0, scanError: nil)
            register(node, leafSize: logicalSize)
            return node
        }

        // Drive the scan.
        do {
            guard let rootNode = try walk(root, parentID: nil, depth: 0) else {
                continuation.yield(.failed(.noSuchFile))
                continuation.finish()
                return
            }

            if rootNode.type == .inaccessible {
                continuation.yield(.failed(rootNode.scanError ?? .permissionDenied))
                continuation.finish()
                return
            }

            progress.statusText = "Finishing up…"
            emitProgress(force: true)

            let result = ScanResult(
                rootNode: rootNode,
                totalSize: rootNode.byteSize,
                allocatedTotal: rootNode.allocatedSize,
                // Counts describe the root's *contents* (the aggregated subtree excludes
                // the scan root itself), which is what users expect to see.
                fileCount: rootNode.fileCount,
                folderCount: rootNode.folderCount,
                inaccessibleCount: rootNode.inaccessibleCount,
                scanStartedAt: startedAt,
                scanFinishedAt: Date(),
                warnings: warnings,
                index: index
            )
            continuation.yield(.finished(result))
            continuation.finish()
        } catch {
            // Cancellation (or any unwinding throw) ends the scan cleanly with no result.
            progress.isCancelled = true
            continuation.yield(.failed(.cancelled))
            continuation.finish()
        }
    }

    /// Heuristic: is `url` under a location that typically needs Full Disk Access?
    /// Used only to upgrade a permission error's message, never to gate scanning.
    private static func needsFullDiskAccess(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path(percentEncoded: false)
        let protectedFragments = [
            "/Library/Application Support/com.apple",
            "/Library/Mail", "/Library/Messages", "/Library/Safari",
            "/Library/Suggestions", "/Library/Cookies", "/Library/HomeKit",
            "/Library/Containers/com.apple",
            "/System/", "/private/var/db", "/Library/Application Support/MobileSync"
        ]
        if protectedFragments.contains(where: { path.contains($0) }) { return true }
        // ~/Library/<protected> areas.
        let home = FileManager.default.homeDirectoryForCurrentUser.path(percentEncoded: false)
        if path.hasPrefix(home + "/Library/") { return true }
        return false
    }
}
