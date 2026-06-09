import Foundation

/// A normalized, Sendable description of why a path could not be fully scanned.
///
/// The scanner never throws out of a whole scan; instead it records a `ScanError`
/// on the affected `DiskNode` (and tallies it) so siblings keep scanning.
public enum ScanError: Error, Sendable, Equatable, Hashable {
    /// `EACCES` / `EPERM` / `NSFileReadNoPermissionError` on a path we don't own.
    case permissionDenied
    /// A protected system location that requires Full Disk Access.
    case fullDiskAccessRequired
    /// `ENOENT` — the item vanished during the scan (deleted mid-scan).
    case noSuchFile
    /// `ENODEV` / `EIO` — the backing volume disconnected mid-scan.
    case deviceGone
    /// The user cancelled the scan.
    case cancelled
    /// Anything else, with the raw POSIX code and a message for diagnostics.
    case unknown(code: Int32, message: String)

    /// A short, human-readable, English explanation suitable for the inspector.
    public var humanMessage: String {
        switch self {
        case .permissionDenied:
            return "Permission denied. Runtahio can't read this item."
        case .fullDiskAccessRequired:
            return "Full Disk Access is required to read this location."
        case .noSuchFile:
            return "Item no longer exists (it changed during the scan)."
        case .deviceGone:
            return "The volume became unavailable during the scan."
        case .cancelled:
            return "Scan cancelled."
        case .unknown(let code, let message):
            return message.isEmpty ? "Couldn't read this item (code \(code))." : message
        }
    }

    /// Classifies a thrown `Error` (typically from FileManager) into a `ScanError`.
    ///
    /// - Parameter underProtectedPrefix: when true, an access failure is reported
    ///   as `.fullDiskAccessRequired` rather than a plain `.permissionDenied`,
    ///   so the UI can route the user to the Full Disk Access guide.
    public static func classify(_ error: Error, underProtectedPrefix: Bool = false) -> ScanError {
        let nsError = error as NSError

        // POSIX errors surface through NSPOSIXErrorDomain or Cocoa file errors.
        let posixCode: Int32? = {
            if nsError.domain == NSPOSIXErrorDomain { return Int32(nsError.code) }
            if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError,
               underlying.domain == NSPOSIXErrorDomain {
                return Int32(underlying.code)
            }
            return nil
        }()

        if let posixCode {
            switch posixCode {
            case EACCES, EPERM:
                return underProtectedPrefix ? .fullDiskAccessRequired : .permissionDenied
            case ENOENT:
                return .noSuchFile
            case ENODEV, EIO, ENXIO:
                return .deviceGone
            default:
                return .unknown(code: posixCode, message: nsError.localizedDescription)
            }
        }

        if nsError.domain == NSCocoaErrorDomain {
            switch nsError.code {
            case NSFileReadNoPermissionError:
                return underProtectedPrefix ? .fullDiskAccessRequired : .permissionDenied
            case NSFileNoSuchFileError, NSFileReadNoSuchFileError:
                return .noSuchFile
            default:
                break
            }
        }

        return .unknown(code: Int32(nsError.code), message: nsError.localizedDescription)
    }
}
