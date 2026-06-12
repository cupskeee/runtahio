import XCTest
@testable import RuntahioCore

final class VolumeInfoTests: XCTestCase {
    private func volume(
        internalDrive: Bool, removable: Bool = false, ejectable: Bool = false,
        total: Int64 = 500_000_000_000, available: Int64 = 200_000_000_000
    ) -> VolumeInfo {
        VolumeInfo(
            path: "/Volumes/Test", name: "Test", isInternal: internalDrive,
            isRemovable: removable, isEjectable: ejectable,
            totalCapacity: total, availableCapacity: available)
    }

    func testUsedCapacityAndFraction() {
        let v = volume(internalDrive: true, total: 1000, available: 250)
        XCTAssertEqual(v.usedCapacity, 750)
        XCTAssertEqual(v.usedFraction, 0.75, accuracy: 0.0001)
    }

    func testInternalVolumeClassification() {
        let v = volume(internalDrive: true)
        XCTAssertFalse(v.isExternal)
        XCTAssertFalse(v.canEject)
        XCTAssertEqual(v.systemImage, "internaldrive")
    }

    func testExternalEjectableClassification() {
        let v = volume(internalDrive: false, ejectable: true)
        XCTAssertTrue(v.isExternal)
        XCTAssertTrue(v.canEject)
        XCTAssertEqual(v.systemImage, "externaldrive")
    }

    func testExternalNonEjectableUsesConnectedIcon() {
        let v = volume(internalDrive: false, removable: false, ejectable: false)
        XCTAssertEqual(v.systemImage, "externaldrive.connected.to.line.below")
    }

    func testCapacityDescription() {
        let v = volume(internalDrive: true, total: 1000, available: 1000)
        XCTAssertTrue(v.capacityDescription.contains("free of"))
        let unknown = VolumeInfo(
            path: "/x", name: "x", isInternal: true, isRemovable: false,
            isEjectable: false, totalCapacity: 0, availableCapacity: 0)
        XCTAssertEqual(unknown.capacityDescription, "Unknown capacity")
    }

    func testCurrentVolumesIncludesBootVolume() {
        // The running Mac always has at least one browsable local volume.
        let volumes = VolumeScanner.currentVolumes()
        XCTAssertFalse(volumes.isEmpty)
        XCTAssertTrue(volumes.contains { $0.isInternal })
    }
}
