import Foundation

/// Centralized, flavor-aware user-facing strings.
///
/// The UI is mainly English. A light Indonesian/Sundanese flavor (the product's
/// personality) appears only in status/branding microcopy when the user opts in.
/// Brand nouns ("Runtahio", "Runtah Basket", "Runtah Map") are constant either way.
/// Organized as one type so it's straightforward to make `String(localized:)`-ready later.
public struct Microcopy: Sendable {
    public let flavor: LanguageFlavor
    public init(flavor: LanguageFlavor) { self.flavor = flavor }

    private var flavored: Bool { flavor == .lightIndonesian }

    // MARK: Brand (constant regardless of flavor)
    public let appName = "Runtahio"
    public let basketName = "Runtah Basket"
    public let mapName = "Runtah Map"
    public let tagline = "Find the clutter. Free your Mac."
    public let taglineIndonesian = "Beresin storage Mac kamu."

    /// The branding line shown in the sidebar footer.
    public var brandingSubtitle: String {
        flavored ? taglineIndonesian : tagline
    }

    // MARK: Scan status
    public func scanningStatus(displayName: String) -> String {
        if displayName.isEmpty {
            return flavored ? "Ningali runtah digital…" : "Scanning…"
        }
        return flavored ? "Ningali runtah digital… (\(displayName))" : "Scanning \(displayName)…"
    }

    public func analyzingStatus(itemCount: Int) -> String {
        let count = itemCount.formatted(.number)
        return flavored ? "Nganalisis \(count) item…" : "Analyzing \(count) items…"
    }

    public var preparingStatus: String {
        flavored ? "Siap-siap mindai…" : "Preparing to scan…"
    }

    public var finishingStatus: String {
        flavored ? "Beberes hasil…" : "Finishing up…"
    }

    public var findingLargeFilesStatus: String {
        flavored ? "Néangan berkas gedé…" : "Finding large files…"
    }

    public var cancelledStatus: String {
        flavored ? "Mindai dibatalkeun." : "Scan cancelled."
    }

    // MARK: Empty / done states
    public let emptyTitle = "Find your digital runtah."
    public let emptySubtitle = "Choose a folder or disk to see what is taking up space."
    public let emptyButton = "Choose Folder…"

    public func clutterFoundHeadline(totalSize: String) -> String {
        flavored ? "Kapanggih \(totalSize) runtah digital." : "Found \(totalSize) to explore."
    }

    // MARK: Cleanup
    public let moveToTrashTitle = "Move to Trash"
    public let moveSelectedClutter = "Move selected clutter to Trash."
    public let filesStayLocal = "Your files stay local."

    public func trashConfirmationMessage(count: Int, totalSize: String) -> String {
        let itemWord = count == 1 ? "item" : "items"
        return
            "Move \(count) \(itemWord) (\(totalSize)) to the Trash? You can recover them from the Trash."
    }
}
