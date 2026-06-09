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
    /// Which explorer visualization to show (radial map or treemap).
    public var visualization: VisualizationStyle { didSet { persist() } }

    // MARK: Safety
    /// Always defaults on. Even when off, the destructive Trash action still confirms once.
    public var confirmBeforeTrash: Bool { didSet { persist() } }

    // MARK: Recent scans / language
    public var recentScansLimit: Int { didSet { persist() } }
    public var language: AppLanguage { didSet { persist() } }

    /// The playful status-microcopy flavor implied by the chosen interface language.
    public var flavor: LanguageFlavor { language.flavor }
    /// Localized UI strings for the chosen interface language.
    public var strings: Strings { Strings(language: language) }

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
        let vizRaw = defaults.string(forKey: Keys.visualization) ?? VisualizationStyle.radial.rawValue
        self.visualization = VisualizationStyle(rawValue: vizRaw) ?? .radial
        self.confirmBeforeTrash = defaults.object(forKey: Keys.confirmBeforeTrash) as? Bool ?? true
        self.recentScansLimit = defaults.object(forKey: Keys.recentScansLimit) as? Int ?? 10
        let langRaw = defaults.string(forKey: Keys.language) ?? AppLanguage.system.rawValue
        self.language = AppLanguage(rawValue: langRaw) ?? .system
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
        defaults.set(visualization.rawValue, forKey: Keys.visualization)
        defaults.set(confirmBeforeTrash, forKey: Keys.confirmBeforeTrash)
        defaults.set(recentScansLimit, forKey: Keys.recentScansLimit)
        defaults.set(language.rawValue, forKey: Keys.language)
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
        static let visualization = "settings.visualization"
        static let confirmBeforeTrash = "settings.confirmBeforeTrash"
        static let recentScansLimit = "settings.recentScansLimit"
        static let language = "settings.language"
        static let hasSeenOnboarding = "settings.hasSeenOnboarding"
    }
}
