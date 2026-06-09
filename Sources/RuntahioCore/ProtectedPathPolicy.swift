import Foundation

/// Why a path may not be added to the Runtah Basket.
public enum BlockReason: String, Sendable, Equatable {
    case emptyOrInvalidPath
    case systemRoot
    case systemDomain
    case volumesMountRoot
    case homeDirectoryRoot

    public var explanation: String {
        switch self {
        case .emptyOrInvalidPath:
            return "This path is empty or invalid."
        case .systemRoot:
            return "The root of the disk (/) is protected and can't be moved to Trash."
        case .systemDomain:
            return "This is a macOS system location and is protected from cleanup."
        case .volumesMountRoot:
            return "This is a volume's mount point. Add items inside it instead of the whole volume."
        case .homeDirectoryRoot:
            return "Your Home folder is protected. Add specific items inside it instead."
        }
    }
}

/// Why a path can be added but only after the user explicitly confirms.
public enum ConfirmReason: String, Sendable, Equatable {
    case scanRootItself

    public var explanation: String {
        switch self {
        case .scanRootItself:
            return "This is the folder you scanned. Moving the entire scanned folder to Trash needs explicit confirmation."
        }
    }
}

/// The result of evaluating a path against the protection rules.
public enum ProtectionVerdict: Equatable, Sendable {
    case allowed
    case blocked(reason: BlockReason)
    case needsExplicitConfirm(reason: ConfirmReason)

    /// True only for `.blocked` — the item must never be added.
    public var isBlocked: Bool {
        if case .blocked = self { return true }
        return false
    }

    /// True when the item may at least be *attempted* (allowed or confirm-required).
    public var isAllowedToAttempt: Bool { !isBlocked }

    /// A user-facing explanation for non-allowed verdicts (empty when allowed).
    public var explanation: String {
        switch self {
        case .allowed: return ""
        case .blocked(let reason): return reason.explanation
        case .needsExplicitConfirm(let reason): return reason.explanation
        }
    }
}

/// Decides which paths are too dangerous to move to Trash.
///
/// Matching is done **component-wise** on standardized, symlink-resolved paths, never
/// with string `hasPrefix` — so `/Libraryfoo` is allowed while `/Library` is blocked,
/// and `/private/var` (firmlink of `/var`) is caught under both spellings.
public struct ProtectedPathPolicy: Sendable {
    /// The user's home directory (injected so tests can pin it).
    public let homeDirectory: URL

    public init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.homeDirectory = homeDirectory
    }

    /// System-domain roots, listed under **both** firmlink spellings (e.g. `var` and
    /// `private/var`) so a path can't sidestep the rule depending on how it resolves.
    static let systemDomainRoots: [[String]] = [
        ["System"], ["Library"], ["bin"], ["sbin"], ["usr"], ["opt"], ["private"],
        ["etc"], ["var"], ["tmp"], ["cores"], ["dev"], ["Network"], ["Applications"],
        ["private", "etc"], ["private", "var"], ["private", "tmp"], ["private", "cores"],
    ]

    static func canonical(_ url: URL) -> URL {
        url.resolvingSymlinksInPath().standardizedFileURL
    }

    static func components(_ url: URL) -> [String] {
        canonical(url).pathComponents.filter { $0 != "/" }
    }

    private static func hasComponentPrefix(_ comps: [String], _ prefix: [String]) -> Bool {
        guard comps.count >= prefix.count, !prefix.isEmpty else { return false }
        return Array(comps.prefix(prefix.count)) == prefix
    }

    /// Evaluates `url` for basket eligibility, most-dangerous rules first.
    public func isProtected(_ url: URL, scanRoot: URL?) -> ProtectionVerdict {
        let canonical = Self.canonical(url)
        let path = canonical.path(percentEncoded: false)
        guard !path.isEmpty else { return .blocked(reason: .emptyOrInvalidPath) }

        let comps = Self.components(url)

        // Root of the disk.
        if comps.isEmpty { return .blocked(reason: .systemRoot) }

        // Entire home directory (but subfolders like ~/Downloads are allowed).
        if comps == Self.components(homeDirectory) {
            return .blocked(reason: .homeDirectoryRoot)
        }

        // /Volumes itself, or a volume's mount root /Volumes/<name>. Subfolders allowed.
        if comps == ["Volumes"] || (comps.count == 2 && comps[0] == "Volumes") {
            return .blocked(reason: .volumesMountRoot)
        }

        // Any macOS system-domain location.
        for root in Self.systemDomainRoots where Self.hasComponentPrefix(comps, root) {
            return .blocked(reason: .systemDomain)
        }

        // The scanned root itself — allowed only with explicit confirmation.
        if let scanRoot, comps == Self.components(scanRoot) {
            return .needsExplicitConfirm(reason: .scanRootItself)
        }

        return .allowed
    }

    /// Convenience: may this path at least be attempted (allowed or confirm-required)?
    public func canAttemptAdd(_ url: URL, scanRoot: URL?) -> Bool {
        isProtected(url, scanRoot: scanRoot).isAllowedToAttempt
    }
}
