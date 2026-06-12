import Foundation
import Observation

/// A previously scanned root.
public struct RecentScanEntry: Identifiable, Sendable, Equatable, Codable {
    public var id: String { path }
    public let path: String
    public let name: String
    public let lastScanned: Date

    public init(path: String, name: String, lastScanned: Date) {
        self.path = path
        self.name = name
        self.lastScanned = lastScanned
    }

    public var url: URL { URL(fileURLWithPath: path) }
}

/// Persists the list of recent scan roots (most-recent first) in `UserDefaults` as JSON.
/// Non-sandboxed, so plain paths are stored (no security-scoped bookmarks needed).
@MainActor
@Observable
public final class RecentScansStore {
    public private(set) var entries: [RecentScanEntry] = []
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let key = "recentScans.entries"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
            let decoded = try? JSONDecoder().decode([RecentScanEntry].self, from: data)
        else {
            entries = []
            return
        }
        entries = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: key)
        }
    }

    /// Records a scan of `url`, moving it to the front and trimming to `limit`.
    public func record(_ url: URL, name: String, date: Date = Date(), limit: Int) {
        let path = url.standardizedFileURL.path(percentEncoded: false)
        entries.removeAll { $0.path == path }
        entries.insert(RecentScanEntry(path: path, name: name, lastScanned: date), at: 0)
        if entries.count > max(0, limit) {
            entries = Array(entries.prefix(max(0, limit)))
        }
        save()
    }

    public func remove(path: String) {
        entries.removeAll { $0.path == path }
        save()
    }

    public func clear() {
        entries.removeAll()
        save()
    }

    /// Trims the list to `limit` (e.g. after the user lowers the setting).
    public func trim(to limit: Int) {
        guard entries.count > max(0, limit) else { return }
        entries = Array(entries.prefix(max(0, limit)))
        save()
    }
}
