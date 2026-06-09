import Foundation

/// Thin, deterministic wrapper around `ByteCountFormatter` for human-readable sizes.
///
/// Centralizing formatting here keeps byte display consistent across the table,
/// inspector, map tooltips, and basket, and lets tests pin the style so results
/// don't depend on a machine's locale.
public struct ByteSizeFormatter: Sendable {
    public enum Style: Sendable {
        /// Decimal units (KB/MB/GB, base 1000) — matches Finder.
        case file
        /// Binary units (KiB/MiB/GiB, base 1024).
        case memory
    }

    public let style: Style
    public let includesActualByteCount: Bool

    public init(style: Style = .file, includesActualByteCount: Bool = false) {
        self.style = style
        self.includesActualByteCount = includesActualByteCount
    }

    /// Shared default formatter (Finder-style).
    public static let shared = ByteSizeFormatter()

    public func string(fromByteCount byteCount: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = (style == .file) ? .file : .memory
        formatter.includesActualByteCount = includesActualByteCount
        formatter.allowsNonnumericFormatting = true
        // Negative sizes are never meaningful here; clamp defensively.
        return formatter.string(fromByteCount: max(0, byteCount))
    }

    /// Convenience for call sites that just want a Finder-style string.
    public static func string(_ byteCount: Int64) -> String {
        shared.string(fromByteCount: byteCount)
    }
}
