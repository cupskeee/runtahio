import XCTest
import Foundation
@testable import RuntahioCore

final class RadialLayoutEngineTests: XCTestCase {
    let size = CGSize(width: 600, height: 600)
    let options = RadialLayoutOptions()

    private func ring1SweepSum(_ segments: [RadialSegment]) -> Double {
        segments.filter { $0.depth == 1 }.reduce(0) { $0 + $1.sweep }
    }

    func testRing1SweepsSumToFullCircle() {
        let focus = TestTree.root(
            "focus",
            children: [
                TestTree.file("a", size: 100, parentID: "/focus", depth: 1),
                TestTree.file("b", size: 50, parentID: "/focus", depth: 1),
                TestTree.file("c", size: 30, parentID: "/focus", depth: 1),
                TestTree.file("d", size: 20, parentID: "/focus", depth: 1),
                TestTree.file("e", size: 10, parentID: "/focus", depth: 1),
            ])
        let segments = RadialLayoutEngine.layout(focus: focus, geometry: size, options: options)
        XCTAssertEqual(ring1SweepSum(segments), 2 * .pi, accuracy: 1e-9)
    }

    func testChildSweepsSumToParentArc() {
        let a = TestTree.dir(
            "A", parentID: "/focus", depth: 1,
            children: [
                TestTree.file("a1", size: 300, parentID: "/focus/A", depth: 2),
                TestTree.file("a2", size: 200, parentID: "/focus/A", depth: 2),
            ])
        let f1 = TestTree.file("f1", size: 500, parentID: "/focus", depth: 1)
        let focus = TestTree.root("focus", children: [a, f1])

        let segments = RadialLayoutEngine.layout(focus: focus, geometry: size, options: options)
        guard let aSeg = segments.first(where: { $0.nodeID == a.id }) else {
            return XCTFail("missing segment for A")
        }
        let childSweepSum =
            segments
            .filter { $0.parentNodeID == a.id }
            .reduce(0) { $0 + $1.sweep }
        XCTAssertEqual(childSweepSum, aSeg.sweep, accuracy: 1e-9)
        XCTAssertEqual(aSeg.sweep, .pi, accuracy: 1e-9)  // 500/1000 of the circle
    }

    func testOtherAggregationCarriesSizeAndClosesArc() {
        var children = [TestTree.file("big", size: 100_000, parentID: "/focus", depth: 1)]
        for i in 0..<100 {
            children.append(TestTree.file("tiny\(i)", size: 1, parentID: "/focus", depth: 1))
        }
        let focus = TestTree.root("focus", children: children)
        let segments = RadialLayoutEngine.layout(focus: focus, geometry: size, options: options)

        let others = segments.filter { $0.isOther && $0.depth == 1 }
        XCTAssertEqual(others.count, 1, "tiny siblings should collapse into one Other")
        XCTAssertEqual(others.first?.byteSize, 100, "Other carries the summed collapsed size")
        XCTAssertEqual(
            others.first?.endAngle ?? 0, 2 * .pi, accuracy: 1e-9, "Other closes the ring")
        XCTAssertEqual(ring1SweepSum(segments), 2 * .pi, accuracy: 1e-9)
    }

    func testHitTestRoundTrip() {
        let focus = TestTree.root(
            "focus",
            children: [
                TestTree.file("a", size: 100, parentID: "/focus", depth: 1),
                TestTree.file("b", size: 60, parentID: "/focus", depth: 1),
                TestTree.file("c", size: 40, parentID: "/focus", depth: 1),
            ])
        let segments = RadialLayoutEngine.layout(focus: focus, geometry: size, options: options)
        let cx = size.width / 2, cy = size.height / 2

        for seg in segments {
            let midA = (seg.startAngle + seg.endAngle) / 2
            let midR = (seg.innerRadius + seg.outerRadius) / 2
            let point = CGPoint(x: cx + midR * sin(midA), y: cy - midR * cos(midA))
            let hit = RadialLayoutEngine.hitTest(segments, at: point, geometry: size)
            XCTAssertEqual(hit?.id, seg.id, "hit-test should return the segment we sampled")
        }
    }

    func testLayoutIsDeterministic() {
        let focus = TestTree.root(
            "focus",
            children: [
                TestTree.dir(
                    "A", parentID: "/focus", depth: 1,
                    children: [
                        TestTree.file("a1", size: 30, parentID: "/focus/A", depth: 2)
                    ]),
                TestTree.file("f", size: 70, parentID: "/focus", depth: 1),
            ])
        let first = RadialLayoutEngine.layout(focus: focus, geometry: size, options: options)
        let second = RadialLayoutEngine.layout(focus: focus, geometry: size, options: options)
        XCTAssertEqual(first, second)
    }

    func testMaxSegmentsBudgetRespected() {
        var dirs: [DiskNode] = []
        for d in 0..<30 {
            var files: [DiskNode] = []
            for f in 0..<30 {
                files.append(TestTree.file("f\(f)", size: 100, parentID: "/focus/d\(d)", depth: 2))
            }
            dirs.append(TestTree.dir("d\(d)", parentID: "/focus", depth: 1, children: files))
        }
        let focus = TestTree.root("focus", children: dirs)
        let capped = RadialLayoutOptions(maxSegments: 100, collapseTiny: false)
        let segments = RadialLayoutEngine.layout(focus: focus, geometry: size, options: capped)
        XCTAssertLessThanOrEqual(segments.count, 100)
    }

    func testCenterDiskDetection() {
        XCTAssertTrue(
            RadialLayoutEngine.isInCenterDisk(
                CGPoint(x: 300, y: 300), geometry: size, options: options))
        XCTAssertFalse(
            RadialLayoutEngine.isInCenterDisk(
                CGPoint(x: 10, y: 10), geometry: size, options: options))
    }

    func testExcludedNodesAreOmittedAndRescale() {
        let focus = TestTree.root(
            "focus",
            children: [
                TestTree.file("a", size: 100, parentID: "/focus", depth: 1),
                TestTree.file("b", size: 100, parentID: "/focus", depth: 1),
            ])
        let segments = RadialLayoutEngine.layout(
            focus: focus, geometry: size, options: options, excludingIDs: ["/focus/b"])
        let depth1 = segments.filter { $0.depth == 1 }
        XCTAssertEqual(depth1.count, 1)
        XCTAssertEqual(depth1.first?.nodeID, "/focus/a")
        // The remaining single child now fills the whole circle.
        XCTAssertEqual(ring1SweepSum(segments), 2 * .pi, accuracy: 1e-9)
    }
}
