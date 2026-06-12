import Foundation

/// Helpers for detecting permission problems and pointing users to Full Disk Access.
/// Contains no network access of any kind — only a local System Settings deep link.
public enum PermissionSupport {

    /// The verbatim privacy note shown in About and Settings.
    public static let privacyNote =
        "Runtahio scans file metadata locally on your Mac. It does not upload file names, paths, sizes, or contents."

    /// Local IPC URL that opens System Settings → Privacy & Security → Full Disk Access.
    /// This is a `x-apple.systempreferences:` scheme — not a network request.
    public static let fullDiskAccessSettingsURLString =
        "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles"

    public static var fullDiskAccessSettingsURL: URL? {
        URL(string: fullDiskAccessSettingsURLString)
    }

    /// Whether an error represents a permission/access denial.
    public static func isPermissionDenied(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSPOSIXErrorDomain,
            nsError.code == Int(EACCES) || nsError.code == Int(EPERM)
        {
            return true
        }
        if nsError.domain == NSCocoaErrorDomain,
            nsError.code == NSFileReadNoPermissionError
        {
            return true
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            return isPermissionDenied(underlying)
        }
        return false
    }

    /// Whether a `ScanError` should route the user to the Full Disk Access guide.
    public static func suggestsFullDiskAccess(_ error: ScanError) -> Bool {
        switch error {
        case .fullDiskAccessRequired, .permissionDenied:
            return true
        default:
            return false
        }
    }

    /// Step-by-step guidance shown in `PermissionGuideView`.
    public static let fullDiskAccessSteps: [String] = [
        "Open System Settings → Privacy & Security → Full Disk Access.",
        "Click the + button and add Runtahio (the Runtahio.app you launched).",
        "Turn the Runtahio switch on.",
        "Quit and reopen Runtahio, then rescan.",
    ]

    /// Honest caveat: ad-hoc-signed rebuilds change identity, so access must be re-granted.
    public static let fullDiskAccessRebuildCaveat =
        "If you rebuild Runtahio from source, macOS sees it as a new app and you may need to grant Full Disk Access again."
}
