import XCTest
import CoreGraphics
@testable import RuntahioCore

final class TreemapLayoutEngineTests: XCTestCase {
    let rect = CGRect(x: 0, y: 0, width: 400, height: 300)
    let options = TreemapLayoutOptions()

    private func sampleTree() -> DiskNode {
        let bigdir = TestTree.dir(
            "bigdir", parentID: "/root", depth: 1,
            children: [
                TestTree.file("a1", size: 4000, parentID: "/root/bigdir", depth: 2),
                TestTree.file("a2", size: 2000, parentID: "/root/bigdir", depth: 2),
            ])
        return TestTree.root(
            "root",
            children: [
                bigdir,
                TestTree.file("f1", size: 2000, parentID: "/root", depth: 1),
                TestTree.file("f2", size: 1000, parentID: "/root", depth: 1),
            ])
    }

    func testSquarifyConservesArea() {
        let areas = [120_000.0, 50_000, 30_000, 12_000, 8_000].map { $0 / 220_000 * (400 * 300) }
        let rects = TreemapLayoutEngine.squarify(areas: areas, in: rect)
        XCTAssertEqual(rects.count, areas.count)
        let totalArea = rects.reduce(0.0) { $0 + Double($1.width) * Double($1.height) }
        XCTAssertEqual(totalArea, 400 * 300, accuracy: 1.0)
        for r in rects {
            XCTAssertGreaterThan(r.width, 0)
            XCTAssertGreaterThan(r.height, 0)
            XCTAssertGreaterThanOrEqual(r.minX, rect.minX - 0.001)
            XCTAssertLessThanOrEqual(r.maxX, rect.maxX + 0.001)
            XCTAssertLessThanOrEqual(r.maxY, rect.maxY + 0.001)
        }
    }

    func testLayoutEmitsTilesContainedInRect() {
        let tiles = TreemapLayoutEngine.layout(focus: sampleTree(), rect: rect, options: options)
        XCTAssertGreaterThanOrEqual(tiles.count, 3)
        for tile in tiles {
            XCTAssertGreaterThanOrEqual(tile.rect.minX, rect.minX - 0.001)
            XCTAssertLessThanOrEqual(tile.rect.maxX, rect.maxX + 0.001)
        }
    }

    func testFolderTileContainsItsChildren() {
        let tree = sampleTree()
        let tiles = TreemapLayoutEngine.layout(focus: tree, rect: rect, options: options)
        guard let bigdir = tiles.first(where: { $0.nodeID == "/root/bigdir" }) else {
            return XCTFail("missing bigdir tile")
        }
        XCTAssertTrue(bigdir.isDrillable)
        XCTAssertEqual(bigdir.depth, 1)
        let children = tiles.filter { $0.parentNodeID == "/root/bigdir" }
        XCTAssertEqual(children.count, 2, "bigdir should be recursed into")
        for child in children {
            XCTAssertEqual(child.depth, 2)
            XCTAssertGreaterThanOrEqual(child.rect.minX, bigdir.rect.minX - 0.001)
            XCTAssertLessThanOrEqual(child.rect.maxX, bigdir.rect.maxX + 0.001)
            XCTAssertLessThanOrEqual(child.rect.maxY, bigdir.rect.maxY + 0.001)
        }
    }

    func testHitTestReturnsDeepestTile() {
        let tiles = TreemapLayoutEngine.layout(focus: sampleTree(), rect: rect, options: options)
        guard let a2 = tiles.first(where: { $0.nodeID == "/root/bigdir/a2" }) else {
            return XCTFail("missing nested tile a2")
        }
        let center = CGPoint(x: a2.rect.midX, y: a2.rect.midY)
        let hit = TreemapLayoutEngine.hitTest(tiles, at: center)
        XCTAssertEqual(
            hit?.nodeID, "/root/bigdir/a2", "should hit the deepest tile, not its parent")
    }

    func testOtherAggregation() {
        var children = [TestTree.file("huge", size: 1_000_000, parentID: "/root", depth: 1)]
        for i in 0..<60 {
            children.append(TestTree.file("tiny\(i)", size: 100, parentID: "/root", depth: 1))
        }
        let tiles = TreemapLayoutEngine.layout(
            focus: TestTree.root("root", children: children), rect: rect, options: options)
        XCTAssertTrue(
            tiles.contains { $0.isOther && $0.depth == 1 }, "tiny tiles should collapse into Other")
    }

    func testExcludingOmitsNodes() {
        let tiles = TreemapLayoutEngine.layout(
            focus: sampleTree(), rect: rect, options: options, excludingIDs: ["/root/bigdir"])
        XCTAssertFalse(tiles.contains { $0.nodeID == "/root/bigdir" })
        XCTAssertFalse(tiles.contains { $0.parentNodeID == "/root/bigdir" })
    }
}
