import XCTest
@testable import RuntahioCore

/// Guardrails that lock in Runtahio's privacy/safety promises so a refactor can't quietly
/// break them: no network, Trash-only wording, verbatim privacy note.
final class PrivacyWordingGuardrailTests: XCTestCase {

    func testPrivacyNoteIsVerbatim() {
        XCTAssertEqual(
            PermissionSupport.privacyNote,
            "Runtahio scans file metadata locally on your Mac. It does not upload file names, paths, sizes, or contents.")
    }

    func testTrashWordingNeverSaysDeleteOrPermanent() {
        let mc = Microcopy(flavor: .standardEnglish)
        XCTAssertEqual(mc.moveToTrashTitle, "Move to Trash")
        let message = mc.trashConfirmationMessage(count: 3, totalSize: "1 MB")
        XCTAssertTrue(message.contains("Trash"))
        XCTAssertFalse(message.lowercased().contains("delete"))
        XCTAssertFalse(message.lowercased().contains("permanent"))
    }

    func testSettingsLinkIsLocalSchemeNotNetwork() {
        XCTAssertTrue(PermissionSupport.fullDiskAccessSettingsURLString.hasPrefix("x-apple.systempreferences:"))
        XCTAssertNotNil(PermissionSupport.fullDiskAccessSettingsURL)
        XCTAssertFalse(PermissionSupport.fullDiskAccessSettingsURLString.contains("http"))
    }

    /// Best-effort static check: the Core sources must contain no http(s) URLs.
    func testNoNetworkURLsInCoreSources() throws {
        let thisFile = URL(fileURLWithPath: #filePath)
        let coreDir = thisFile
            .deletingLastPathComponent()   // RuntahioCoreTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // project root
            .appendingPathComponent("Sources/RuntahioCore", isDirectory: true)

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: coreDir, includingPropertiesForKeys: nil) else {
            throw XCTSkip("Core source directory not reachable from test bundle")
        }

        for file in files where file.pathExtension == "swift" {
            let content = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
            XCTAssertFalse(content.contains("http://"), "\(file.lastPathComponent) contains http://")
            XCTAssertFalse(content.contains("https://"), "\(file.lastPathComponent) contains https://")
        }
    }
}
