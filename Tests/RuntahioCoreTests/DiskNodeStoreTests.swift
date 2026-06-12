import XCTest
@testable import RuntahioCore

@MainActor
final class DiskNodeStoreTests: XCTestCase {
    private func sampleTree() -> DiskNode {
        let sub = TestTree.dir(
            "sub", parentID: "/root", depth: 1,
            children: [
                TestTree.file("b", size: 2000, parentID: "/root/sub", depth: 2),
                TestTree.file("c", size: 3000, parentID: "/root/sub", depth: 2),
            ])
        let a = TestTree.file("a", size: 1000, parentID: "/root", depth: 1)
        return TestTree.root("root", children: [a, sub])
    }

    func testEffectiveTotalsBeforeRemoval() {
        let store = DiskNodeStore()
        store.load(TestTree.result(root: sampleTree()))
        XCTAssertEqual(store.effectiveTotalSize(useAllocated: false), 6000)
    }

    func testRemovalAdjustsChildrenAndAncestorTotals() {
        let store = DiskNodeStore()
        store.load(TestTree.result(root: sampleTree()))

        store.markRemoved(ids: ["/root/sub/b"])

        XCTAssertTrue(store.isRemoved("/root/sub/b"))
        let sub = try? XCTUnwrap(store.node(id: "/root/sub"))
        XCTAssertEqual(store.effectiveChildren(of: sub!).map(\.name), ["c"])
        XCTAssertEqual(store.effectiveSize(of: sub!, useAllocated: false), 3000)
        XCTAssertEqual(store.effectiveTotalSize(useAllocated: false), 4000)
    }

    func testRemovalIsIdempotent() {
        let store = DiskNodeStore()
        store.load(TestTree.result(root: sampleTree()))
        store.markRemoved(ids: ["/root/sub/b"])
        store.markRemoved(ids: ["/root/sub/b"])  // again — must not double-subtract
        XCTAssertEqual(store.effectiveTotalSize(useAllocated: false), 4000)
    }

    func testBreadcrumbAndParent() {
        let store = DiskNodeStore()
        store.load(TestTree.result(root: sampleTree()))
        let c = try? XCTUnwrap(store.node(id: "/root/sub/c"))
        XCTAssertEqual(store.breadcrumb(to: c!).map(\.name), ["root", "sub", "c"])
        XCTAssertEqual(store.parent(of: c!)?.name, "sub")
    }
}
