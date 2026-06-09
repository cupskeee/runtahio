import XCTest
@testable import RuntahioCore

@MainActor
final class RuntahBasketTests: XCTestCase {
    let policy = ProtectedPathPolicy(homeDirectory: URL(fileURLWithPath: "/Users/tester"))

    private func node(_ path: String, size: Int64, allocated: Int64? = nil, type: NodeType = .file) -> DiskNode {
        let comps = path.split(separator: "/").map(String.init)
        let name = comps.last ?? path
        let parent = "/" + comps.dropLast().joined(separator: "/")
        return DiskNode(
            id: path, parentID: parent, name: name, url: URL(fileURLWithPath: path),
            type: type, depth: comps.count - 1, isHidden: false, isReadable: true,
            isPackage: false, isSymlink: false, fileExtension: nil, modifiedDate: nil,
            createdDate: nil, byteSize: size, allocatedSize: allocated ?? size, children: [],
            fileCount: 0, folderCount: 0, inaccessibleCount: 0, scanError: nil)
    }

    func testAddSingleItem() {
        let basket = RuntahBasket()
        let result = basket.add(node("/Users/tester/Documents/a.txt", size: 1000), policy: policy, scanRoot: nil)
        XCTAssertEqual(result, .added)
        XCTAssertEqual(basket.count, 1)
        XCTAssertEqual(basket.totalReclaimable, 1000)
    }

    func testDuplicateIgnored() {
        let basket = RuntahBasket()
        let n = node("/Users/tester/Documents/a.txt", size: 1000)
        XCTAssertEqual(basket.add(n, policy: policy, scanRoot: nil), .added)
        XCTAssertEqual(basket.add(n, policy: policy, scanRoot: nil), .duplicateIgnored)
        XCTAssertEqual(basket.count, 1)
    }

    func testChildUnderExistingParentRejected() {
        let basket = RuntahBasket()
        XCTAssertEqual(basket.add(node("/Users/tester/Documents/folder", size: 5000, type: .directory),
                                  policy: policy, scanRoot: nil), .added)
        XCTAssertEqual(basket.add(node("/Users/tester/Documents/folder/child.txt", size: 100),
                                  policy: policy, scanRoot: nil), .nestedUnderExisting)
        XCTAssertEqual(basket.count, 1)
        XCTAssertEqual(basket.totalReclaimable, 5000)
    }

    func testParentAbsorbsExistingChildren() {
        let basket = RuntahBasket()
        XCTAssertEqual(basket.add(node("/Users/tester/Documents/folder/a.txt", size: 100), policy: policy, scanRoot: nil), .added)
        XCTAssertEqual(basket.add(node("/Users/tester/Documents/folder/b.txt", size: 200), policy: policy, scanRoot: nil), .added)
        let result = basket.add(node("/Users/tester/Documents/folder", size: 5000, type: .directory), policy: policy, scanRoot: nil)
        XCTAssertEqual(result, .absorbedDescendants(2))
        XCTAssertEqual(basket.count, 1)
        XCTAssertEqual(basket.totalReclaimable, 5000)
    }

    func testTotalReclaimableNoDoubleCount() {
        let basket = RuntahBasket()
        basket.add(node("/Users/tester/a.txt", size: 100), policy: policy, scanRoot: nil)
        basket.add(node("/Users/tester/b.txt", size: 250), policy: policy, scanRoot: nil)
        XCTAssertEqual(basket.totalReclaimable, 350)
    }

    func testProtectedPathRejected() {
        let basket = RuntahBasket()
        let result = basket.add(node("/Library/Caches/big", size: 9999, type: .directory), policy: policy, scanRoot: nil)
        XCTAssertEqual(result, .rejectedProtected(.systemDomain))
        XCTAssertTrue(basket.isEmpty)
    }

    func testScanRootNeedsConfirmThenAddsWhenConfirmed() {
        let basket = RuntahBasket()
        let root = node("/Users/tester/Projects", size: 4242, type: .directory)
        let scanRoot = URL(fileURLWithPath: "/Users/tester/Projects")
        XCTAssertEqual(basket.add(root, policy: policy, scanRoot: scanRoot), .needsConfirm(.scanRootItself))
        XCTAssertTrue(basket.isEmpty)
        XCTAssertEqual(basket.add(root, policy: policy, scanRoot: scanRoot, confirmedScanRoot: true), .added)
        XCTAssertEqual(basket.count, 1)
    }

    func testRemoveAndClear() {
        let basket = RuntahBasket()
        basket.add(node("/Users/tester/a.txt", size: 100), policy: policy, scanRoot: nil)
        basket.add(node("/Users/tester/b.txt", size: 200), policy: policy, scanRoot: nil)
        basket.remove(id: "/Users/tester/a.txt")
        XCTAssertEqual(basket.count, 1)
        XCTAssertEqual(basket.totalReclaimable, 200)
        basket.clear()
        XCTAssertTrue(basket.isEmpty)
        XCTAssertEqual(basket.totalReclaimable, 0)
    }

    func testReclaimableUsesAllocatedWhenEnabled() {
        let basket = RuntahBasket()
        basket.useAllocatedForReclaimable = true
        basket.add(node("/Users/tester/a.bin", size: 1000, allocated: 4096), policy: policy, scanRoot: nil)
        XCTAssertEqual(basket.totalReclaimable, 4096)
    }

    func testLargestItemsOrdering() {
        let basket = RuntahBasket()
        basket.add(node("/Users/tester/small.txt", size: 10), policy: policy, scanRoot: nil)
        basket.add(node("/Users/tester/big.txt", size: 9000), policy: policy, scanRoot: nil)
        basket.add(node("/Users/tester/mid.txt", size: 500), policy: policy, scanRoot: nil)
        let largest = basket.largestItems(limit: 2)
        XCTAssertEqual(largest.map(\.name), ["big.txt", "mid.txt"])
    }
}
