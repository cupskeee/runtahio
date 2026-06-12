import Foundation

/// A mounted, browsable local volume the user can scan.
public struct VolumeInfo: Identifiable, Sendable, Equatable {
    public var id: String { path }
    public let path: String
    public let name: String
    public let isInternal: Bool
    public let isRemovable: Bool
    public let isEjectable: Bool
    public let totalCapacity: Int64
    public let availableCapacity: Int64

    public init(
        path: String, name: String, isInternal: Bool, isRemovable: Bool, isEjectable: Bool,
        totalCapacity: Int64, availableCapacity: Int64
    ) {
        self.path = path
        self.name = name
        self.isInternal = isInternal
        self.isRemovable = isRemovable
        self.isEjectable = isEjectable
        self.totalCapacity = totalCapacity
        self.availableCapacity = availableCapacity
    }

    public var url: URL { URL(fileURLWithPath: path) }
    public var isExternal: Bool { !isInternal }
    public var canEject: Bool { isEjectable || isRemovable }
    public var usedCapacity: Int64 { max(0, totalCapacity - availableCapacity) }
    public var usedFraction: Double {
        totalCapacity > 0 ? Double(usedCapacity) / Double(totalCapacity) : 0
    }

    public var systemImage: String {
        if canEject { return "externaldrive" }
        return isInternal ? "internaldrive" : "externaldrive.connected.to.line.below"
    }

    /// e.g. "120 GB free of 500 GB".
    public var capacityDescription: String {
        guard totalCapacity > 0 else { return "Unknown capacity" }
        return
            "\(ByteSizeFormatter.string(availableCapacity)) free of \(ByteSizeFormatter.string(totalCapacity))"
    }
}

/// Reads currently mounted local volumes. Thin FileManager wrapper (not pure), but the
/// `VolumeInfo` classification it produces is.
public enum VolumeScanner {
    public static let resourceKeys: [URLResourceKey] = [
        .volumeNameKey, .volumeIsInternalKey, .volumeIsRemovableKey, .volumeIsEjectableKey,
        .volumeTotalCapacityKey, .volumeAvailableCapacityKey, .volumeIsLocalKey,
        .volumeIsBrowsableKey,
    ]

    public static func currentVolumes() -> [VolumeInfo] {
        let keys = Set(resourceKeys)
        let urls =
            FileManager.default.mountedVolumeURLs(
                includingResourceValuesForKeys: resourceKeys, options: [.skipHiddenVolumes]) ?? []
        var result: [VolumeInfo] = []
        for url in urls {
            guard let values = try? url.resourceValues(forKeys: keys),
                values.volumeIsBrowsable ?? false,
                values.volumeIsLocal ?? false
            else { continue }
            result.append(
                VolumeInfo(
                    path: url.path(percentEncoded: false),
                    name: values.volumeName ?? url.lastPathComponent,
                    isInternal: values.volumeIsInternal ?? true,
                    isRemovable: values.volumeIsRemovable ?? false,
                    isEjectable: values.volumeIsEjectable ?? false,
                    totalCapacity: Int64(values.volumeTotalCapacity ?? 0),
                    availableCapacity: Int64(values.volumeAvailableCapacity ?? 0)))
        }
        // Internal volumes first, then external; each group sorted by name.
        return result.sorted { a, b in
            if a.isInternal != b.isInternal { return a.isInternal && !b.isInternal }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }
}
