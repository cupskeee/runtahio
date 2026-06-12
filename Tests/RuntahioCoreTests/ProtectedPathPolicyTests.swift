import XCTest
@testable import RuntahioCore

final class ProtectedPathPolicyTests: XCTestCase {
    // Pin the home directory so tests are independent of the running user.
    let policy = ProtectedPathPolicy(homeDirectory: URL(fileURLWithPath: "/Users/tester"))

    private func u(_ path: String) -> URL { URL(fileURLWithPath: path) }
    private func verdict(_ path: String, scanRoot: String? = nil) -> ProtectionVerdict {
        policy.isProtected(u(path), scanRoot: scanRoot.map(u))
    }

    func testDiskRootIsBlocked() {
        XCTAssertEqual(verdict("/"), .blocked(reason: .systemRoot))
    }

    func testSystemDomainRootsAreBlocked() {
        for p in [
            "/System", "/Library", "/bin", "/sbin", "/usr", "/opt", "/private",
            "/System/Library/Fonts", "/usr/local/bin",
        ] {
            XCTAssertEqual(verdict(p), .blocked(reason: .systemDomain), "expected \(p) blocked")
        }
    }

    func testFirmlinkSpellingsBothBlocked() {
        for p in [
            "/etc", "/var", "/tmp", "/cores",
            "/private/etc", "/private/var", "/private/tmp", "/private/cores",
            "/var/db", "/private/var/db",
        ] {
            XCTAssertEqual(verdict(p), .blocked(reason: .systemDomain), "expected \(p) blocked")
        }
    }

    func testComponentWiseMatchingDoesNotOverBlock() {
        // String-prefix matching would wrongly block these; component-wise must allow them.
        XCTAssertEqual(verdict("/Libraryfoo"), .allowed)
        XCTAssertEqual(verdict("/Users/tester/Systemic"), .allowed)
        XCTAssertEqual(verdict("/Users/tester/usrdata/file.txt"), .allowed)
    }

    func testHomeRootBlockedButSubfoldersAllowed() {
        XCTAssertEqual(verdict("/Users/tester"), .blocked(reason: .homeDirectoryRoot))
        XCTAssertEqual(verdict("/Users/tester/Downloads"), .allowed)
        XCTAssertEqual(verdict("/Users/tester/Downloads/big.zip"), .allowed)
    }

    func testSiblingHomeIsAllowed() {
        XCTAssertEqual(verdict("/Users/someoneelse"), .allowed)
        XCTAssertEqual(verdict("/Users/someoneelse/Movies"), .allowed)
    }

    func testVolumesMountRootBlockedButChildrenAllowed() {
        XCTAssertEqual(verdict("/Volumes"), .blocked(reason: .volumesMountRoot))
        XCTAssertEqual(verdict("/Volumes/External"), .blocked(reason: .volumesMountRoot))
        XCTAssertEqual(verdict("/Volumes/External/Backups"), .allowed)
        XCTAssertEqual(verdict("/Volumes/External/Backups/old.dmg"), .allowed)
    }

    func testDotDotIsCanonicalized() {
        // /Users/tester/Downloads/.. resolves to /Users/tester (home root) → blocked.
        XCTAssertEqual(verdict("/Users/tester/Downloads/.."), .blocked(reason: .homeDirectoryRoot))
        // One level further up lands on /Users, which is allowed.
        XCTAssertEqual(verdict("/Users/tester/Downloads/../.."), .allowed)
    }

    func testScanRootNeedsConfirmationWhenOtherwiseAllowed() {
        let p = "/Users/tester/Projects"
        XCTAssertEqual(verdict(p, scanRoot: p), .needsExplicitConfirm(reason: .scanRootItself))
    }

    func testScanRootChildIsAllowed() {
        XCTAssertEqual(
            verdict("/Users/tester/Projects/build", scanRoot: "/Users/tester/Projects"), .allowed)
    }

    func testProtectedScanRootStaysBlockedEvenIfItIsTheRoot() {
        // A system scan root is still hard-blocked, not merely confirm-required.
        XCTAssertEqual(verdict("/Library", scanRoot: "/Library"), .blocked(reason: .systemDomain))
    }

    func testVerdictFlags() {
        XCTAssertTrue(ProtectionVerdict.blocked(reason: .systemRoot).isBlocked)
        XCTAssertFalse(ProtectionVerdict.allowed.isBlocked)
        XCTAssertTrue(
            ProtectionVerdict.needsExplicitConfirm(reason: .scanRootItself).isAllowedToAttempt)
        XCTAssertFalse(ProtectionVerdict.blocked(reason: .systemDomain).isAllowedToAttempt)
    }

    func testReasonRawValuesAreStable() {
        XCTAssertEqual(BlockReason.systemRoot.rawValue, "systemRoot")
        XCTAssertEqual(BlockReason.systemDomain.rawValue, "systemDomain")
        XCTAssertEqual(BlockReason.volumesMountRoot.rawValue, "volumesMountRoot")
        XCTAssertEqual(BlockReason.homeDirectoryRoot.rawValue, "homeDirectoryRoot")
        XCTAssertEqual(ConfirmReason.scanRootItself.rawValue, "scanRootItself")
    }
}
