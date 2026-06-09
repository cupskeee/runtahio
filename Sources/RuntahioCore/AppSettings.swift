import Foundation
import Observation

/// User-tunable settings, persisted to `UserDefaults`. `@Observable` so SwiftUI views
/// update live; imports `Observation` (not SwiftUI) so it stays in Core and is testable.
@MainActor
@Observable
public final class AppSettings {
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var isLoaded = false

    // MARK: Scanning
    /// Show hidden files (they are always *counted*, this only affects display).
    public var showHidden: Bool { didSet { persist() } }
    public var treatPackagesAsFolders: Bool { didSet { persist() } }
    public var useAllocatedSize: Bool { didSet { persist() } }

    // MARK: Runtah Map
    public var collapseTinySegments: Bool { didSet { persist() } }
    /// Minimum fraction of a parent below which a segment may collapse into "Other".
    public var minSegmentFraction: Double { didSet { persist() } }
    public var animationsEnabled: Bool { didSet { persist() } }

    // MARK: Safety
    /// Always defaults on. Even when off, the destructive Trash action still confirms once.
    public var confirmBeforeTrash: Bool { didSet { persist() } }

    // MARK: Recent scans / language
    public var recentScansLimit: Int { didSet { persist() } }
    public var languageFlavor: LanguageFlavor { didSet { persist() } }

    // MARK: First run
    public var hasSeenOnboarding: Bool { didSet { persist() } }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.showHidden = defaults.object(forKey: Keys.showHidden) as? Bool ?? true
        self.treatPackagesAsFolders = defaults.object(forKey: Keys.treatPackagesAsFolders) as? Bool ?? false
        self.useAllocatedSize = defaults.object(forKey: Keys.useAllocatedSize) as? Bool ?? false
        self.collapseTinySegments = defaults.object(forKey: Keys.collapseTinySegments) as? Bool ?? true
        self.minSegmentFraction = defaults.object(forKey: Keys.minSegmentFraction) as? Double ?? 0.004
        self.animationsEnabled = defaults.object(forKey: Keys.animationsEnabled) as? Bool ?? true
        self.confirmBeforeTrash = defaults.object(forKey: Keys.confirmBeforeTrash) as? Bool ?? true
        self.recentScansLimit = defaults.object(forKey: Keys.recentScansLimit) as? Int ?? 10
        let flavorRaw = defaults.string(forKey: Keys.languageFlavor) ?? LanguageFlavor.standardEnglish.rawValue
        self.languageFlavor = LanguageFlavor(rawValue: flavorRaw) ?? .standardEnglish
        self.hasSeenOnboarding = defaults.object(forKey: Keys.hasSeenOnboarding) as? Bool ?? false
        self.isLoaded = true
    }

    private func persist() {
        guard isLoaded else { return }
        defaults.set(showHidden, forKey: Keys.showHidden)
        defaults.set(treatPackagesAsFolders, forKey: Keys.treatPackagesAsFolders)
        defaults.set(useAllocatedSize, forKey: Keys.useAllocatedSize)
        defaults.set(collapseTinySegments, forKey: Keys.collapseTinySegments)
        defaults.set(minSegmentFraction, forKey: Keys.minSegmentFraction)
        defaults.set(animationsEnabled, forKey: Keys.animationsEnabled)
        defaults.set(confirmBeforeTrash, forKey: Keys.confirmBeforeTrash)
        defaults.set(recentScansLimit, forKey: Keys.recentScansLimit)
        defaults.set(languageFlavor.rawValue, forKey: Keys.languageFlavor)
        defaults.set(hasSeenOnboarding, forKey: Keys.hasSeenOnboarding)
    }

    /// Scan options derived from the current settings.
    public var scanOptions: ScanOptions {
        ScanOptions(
            showHidden: showHidden,
            treatPackagesAsFolders: treatPackagesAsFolders,
            useAllocatedSizeWhenAvailable: useAllocatedSize
        )
    }

    /// Radial layout options derived from the current settings.
    public var radialLayoutOptions: RadialLayoutOptions {
        RadialLayoutOptions(
            collapseTiny: collapseTinySegments,
            minFraction: minSegmentFraction,
            useAllocatedSize: useAllocatedSize
        )
    }

    private enum Keys {
        static let showHidden = "settings.showHidden"
        static let treatPackagesAsFolders = "settings.treatPackagesAsFolders"
        static let useAllocatedSize = "settings.useAllocatedSize"
        static let collapseTinySegments = "settings.collapseTinySegments"
        static let minSegmentFraction = "settings.minSegmentFraction"
        static let animationsEnabled = "settings.animationsEnabled"
        static let confirmBeforeTrash = "settings.confirmBeforeTrash"
        static let recentScansLimit = "settings.recentScansLimit"
        static let languageFlavor = "settings.languageFlavor"
        static let hasSeenOnboarding = "settings.hasSeenOnboarding"
    }
}
