import XCTest
@testable import RuntahioCore

final class LocalizationTests: XCTestCase {
    func testEnglishStrings() {
        let s = Strings(language: .english)
        XCTAssertEqual(s.chooseFolder, "Choose Folder…")
        XCTAssertEqual(s.moveToTrash, "Move to Trash")
        XCTAssertEqual(s.modeTitle(.duplicates), "Duplicates")
    }

    func testIndonesianStrings() {
        let s = Strings(language: .indonesian)
        XCTAssertEqual(s.chooseFolder, "Pilih Folder…")
        XCTAssertEqual(s.moveToTrash, "Pindahkan ke Sampah")
        XCTAssertEqual(s.modeTitle(.largest), "Berkas Terbesar")
        XCTAssertNotEqual(s.emptyTitle, Strings(language: .english).emptyTitle)
    }

    func testSystemResolvesToConcreteLanguage() {
        let resolved = AppLanguage.system.resolved
        XCTAssertTrue(resolved == .english || resolved == .indonesian)
        XCTAssertNotEqual(resolved, .system)
    }

    func testLanguageDrivesFlavor() {
        XCTAssertEqual(AppLanguage.indonesian.flavor, .lightIndonesian)
        XCTAssertEqual(AppLanguage.english.flavor, .standardEnglish)
    }

    func testStringsInitResolvesSystem() {
        // A .system Strings should behave like a concrete language (never crash / passthrough).
        let s = Strings(language: .system)
        XCTAssertFalse(s.total.isEmpty)
    }
}
