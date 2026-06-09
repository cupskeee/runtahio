import Foundation

/// The interface language. `.system` follows the OS preferred languages.
public enum AppLanguage: String, Sendable, Codable, CaseIterable, Identifiable {
    case system
    case english
    case indonesian

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: return "System"
        case .english: return "English"
        case .indonesian: return "Bahasa Indonesia"
        }
    }

    /// Resolves `.system` to a concrete language from the user's preferred languages.
    public var resolved: AppLanguage {
        guard self == .system else { return self }
        if let first = Locale.preferredLanguages.first, first.lowercased().hasPrefix("id") {
            return .indonesian
        }
        return .english
    }

    /// The playful status-microcopy flavor implied by this language.
    public var flavor: LanguageFlavor {
        resolved == .indonesian ? .lightIndonesian : .standardEnglish
    }
}

/// Localized UI strings (English + Bahasa Indonesia). Compile-time checked (no string
/// keys), driven by the resolved `AppLanguage`. Brand nouns stay constant.
public struct Strings: Sendable {
    public let language: AppLanguage

    public init(language: AppLanguage) {
        self.language = language.resolved
    }

    private func t(_ english: String, _ indonesian: String) -> String {
        language == .indonesian ? indonesian : english
    }

    // Sidebar sections
    public var scan: String { t("Scan", "Pindai") }
    public var volumes: String { t("Volumes", "Volume") }
    public var recentScans: String { t("Recent Scans", "Pindai Terakhir") }
    public var analyze: String { t("Analyze", "Analisis") }

    // Buttons / actions
    public var chooseFolder: String { t("Choose Folder…", "Pilih Folder…") }
    public var rescan: String { t("Rescan", "Pindai Ulang") }
    public var cancelScan: String { t("Cancel Scan", "Batalkan Pindai") }
    public var moveToTrash: String { t("Move to Trash", "Pindahkan ke Sampah") }
    public var clear: String { t("Clear", "Kosongkan") }
    public var export: String { t("Export", "Ekspor") }
    public var getStarted: String { t("Get Started", "Mulai") }
    public var backToMap: String { t("Back to Map", "Kembali ke Peta") }
    public var addToBasket: String { t("Add to Runtah Basket", "Tambah ke Runtah Basket") }
    public var eject: String { t("Eject", "Keluarkan") }

    // Totals
    public var total: String { t("Total", "Total") }
    public var files: String { t("Files", "Berkas") }
    public var folders: String { t("Folders", "Folder") }
    public var inaccessible: String { t("Inaccessible", "Tak Terbaca") }
    public var freed: String { t("Freed", "Dibebaskan") }

    // Basket
    public var basketEmptyHint: String { t("Empty — add items to clean up.", "Kosong — tambah item untuk dibersihkan.") }
    public var reclaimable: String { t("reclaimable", "bisa dibebaskan") }

    // Empty / onboarding / inspector
    public var emptyTitle: String { t("Find your digital runtah.", "Temukan runtah digital kamu.") }
    public var emptySubtitle: String {
        t("Choose a folder or disk to see what is taking up space.",
          "Pilih folder atau disk untuk melihat apa yang memakan ruang.")
    }
    public var welcome: String { t("Welcome to Runtahio", "Selamat datang di Runtahio") }
    public var noSelection: String { t("No selection", "Tidak ada pilihan") }
    public var inspectHint: String {
        t("Select an item in the Runtah Map or the list to inspect it.",
          "Pilih item di Runtah Map atau daftar untuk memeriksanya.")
    }

    // Settings section titles
    public var scanning: String { t("Scanning", "Pemindaian") }
    public var safety: String { t("Safety", "Keamanan") }
    public var languageTitle: String { t("Language", "Bahasa") }
    public var about: String { t("About", "Tentang") }
    public var interfaceLanguage: String { t("Interface language", "Bahasa antarmuka") }

    // Content modes
    public func modeTitle(_ mode: ContentModeKey) -> String {
        switch mode {
        case .explorer: return t("Explorer", "Penjelajah")
        case .largest: return t("Largest Files", "Berkas Terbesar")
        case .oldest: return t("Old Files", "Berkas Lama")
        case .types: return t("File Types", "Jenis Berkas")
        case .duplicates: return t("Duplicates", "Duplikat")
        case .inaccessible: return t("Inaccessible Items", "Item Tak Terbaca")
        }
    }
}

/// A Core-side mirror of the app's content modes, so `Strings` can localize their titles
/// without depending on the executable target.
public enum ContentModeKey: String, Sendable, CaseIterable {
    case explorer, largest, oldest, types, duplicates, inaccessible
}
