import XCTest
@testable import GitVisualizerCore

final class CommitGraphTests: XCTestCase {

    private typealias Line = CommitGraph.Line

    private func commit(_ hash: String, parents: [String] = []) -> Commit {
        Commit(
            hash: hash,
            author: "Ada",
            authorEmail: "ada@example.com",
            timestamp: Date(),
            message: hash,
            parentHashes: parents
        )
    }

    func testEmptyHistoryHasNoRows() {
        XCTAssertTrue(CommitGraph.layout([]).isEmpty)
    }

    func testLinearHistoryStaysInOneLane() {
        let rows = CommitGraph.layout([
            commit("c", parents: ["b"]),
            commit("b", parents: ["a"]),
            commit("a")
        ])

        XCTAssertEqual(rows.map(\.lane), [0, 0, 0])
        XCTAssertEqual(rows.map(\.width), [1, 1, 1])
        XCTAssertEqual(Set(rows.map(\.color)).count, 1)
        XCTAssertEqual(rows[0].lines, [Line(from: nil, to: 0, color: rows[0].color)])
        XCTAssertEqual(rows[1].lines, [Line(from: 0, to: 0, color: rows[0].color)])
        XCTAssertEqual(rows[2].lines, [Line(from: 0, to: nil, color: rows[0].color)])
    }

    func testMergeOpensASecondLaneThatClosesAtTheForkPoint() {
        let rows = CommitGraph.layout([
            commit("merge", parents: ["main", "topic"]),
            commit("topic", parents: ["base"]),
            commit("main", parents: ["base"]),
            commit("base")
        ])

        XCTAssertEqual(rows.map(\.lane), [0, 1, 0, 0])
        XCTAssertEqual(rows.map(\.isMerge), [true, false, false, false])
        XCTAssertEqual(rows.map(\.width), [2, 2, 2, 2])

        let main = rows[0].color
        let topic = rows[1].color
        XCTAssertNotEqual(main, topic)

        XCTAssertEqual(rows[0].lines, [
            Line(from: nil, to: 0, color: main),
            Line(from: nil, to: 1, color: topic)
        ])
        // Both lanes arrive at the fork point and end there.
        XCTAssertEqual(rows[3].lines, [
            Line(from: 0, to: nil, color: main),
            Line(from: 1, to: nil, color: topic)
        ])
    }

    func testMergeJoinsALaneAlreadyHeadingToThatParent() {
        // `side` is already waiting for `shared` when the merge comes along;
        // the merge's second parent must reuse that lane, not open a duplicate.
        let rows = CommitGraph.layout([
            commit("side", parents: ["shared"]),
            commit("merge", parents: ["old", "shared"]),
            commit("shared", parents: ["old"]),
            commit("old")
        ])

        let side = rows[0].color
        let merge = rows[1].color
        XCTAssertEqual(rows[1].lines, [
            Line(from: 0, to: 0, color: side),
            Line(from: nil, to: 1, color: merge),
            Line(from: nil, to: 0, color: side)
        ])
        XCTAssertEqual(rows.map(\.width).max(), 2)
    }

    func testLanesSlideLeftWhenOneClosesBeforeThem() {
        let rows = CommitGraph.layout([
            commit("merge", parents: ["left", "right"]),
            commit("left"),
            commit("right")
        ])

        // `left` is a root, so its lane closes and `right` moves over.
        XCTAssertEqual(rows[1].lines, [
            Line(from: 0, to: nil, color: rows[0].color),
            Line(from: 1, to: 0, color: rows[2].color)
        ])
        XCTAssertEqual(rows[2].lane, 0)
    }

    func testParentsOutsideTheWindowLeaveTheLaneOpen() {
        // `git log -N` cuts history off; the last commit's parent never shows up.
        let rows = CommitGraph.layout([
            commit("b", parents: ["a"]),
            commit("a", parents: ["not-loaded"])
        ])

        XCTAssertEqual(rows[1].lines, [Line(from: 0, to: 0, color: rows[0].color)])
    }

    func testUnrelatedTipsGetTheirOwnLanes() {
        let rows = CommitGraph.layout([
            commit("x2", parents: ["x1"]),
            commit("y2", parents: ["y1"]),
            commit("x1"),
            commit("y1")
        ])

        XCTAssertEqual(rows.map(\.lane), [0, 1, 0, 0])
        XCTAssertNotEqual(rows[0].color, rows[1].color)
    }

    func testClosedLaneColorsAreReused() {
        // Far more side branches than colors, but never more than two at once.
        var commits: [Commit] = []
        for i in 0..<20 {
            commits.append(commit("m\(i)", parents: ["m\(i + 1)", "s\(i)"]))
            commits.append(commit("s\(i)", parents: ["m\(i + 1)"]))
        }
        commits.append(commit("m20"))

        let rows = CommitGraph.layout(commits, paletteSize: 4)

        XCTAssertTrue(rows.allSatisfy { (0..<4).contains($0.color) })
        XCTAssertTrue(rows.allSatisfy { row in row.lines.allSatisfy { (0..<4).contains($0.color) } })
        // The main lane keeps its color the whole way down.
        let mainColors = Set(zip(commits, rows).filter { $0.0.hash.hasPrefix("m") }.map(\.1.color))
        XCTAssertEqual(mainColors.count, 1)
    }

    /// The property the drawing relies on: whatever leaves the bottom of one
    /// row enters the top of the next, in the same lane and the same color.
    func testRowsJoinUpIntoContinuousLanes() {
        let commits = [
            commit("h", parents: ["g", "f"]),
            commit("g", parents: ["e"]),
            commit("f", parents: ["d", "c"]),
            commit("e", parents: ["d"]),
            commit("d", parents: ["b"]),
            commit("c", parents: ["b"]),
            commit("b", parents: ["a"]),
            commit("a")
        ]
        let rows = CommitGraph.layout(commits)

        XCTAssertTrue(rows[0].lines.allSatisfy { $0.from == nil })
        XCTAssertTrue(rows[rows.count - 1].lines.allSatisfy { $0.to == nil })

        for (upper, lower) in zip(rows, rows.dropFirst()) {
            var leaving: [Int: Int] = [:]
            for line in upper.lines {
                guard let lane = line.to else { continue }
                XCTAssertEqual(leaving[lane] ?? line.color, line.color, "two colors leave lane \(lane)")
                leaving[lane] = line.color
            }
            var entering: [Int: Int] = [:]
            for line in lower.lines {
                guard let lane = line.from else { continue }
                XCTAssertNil(entering[lane], "two lines enter lane \(lane)")
                entering[lane] = line.color
            }
            XCTAssertEqual(leaving, entering)
        }
    }

    func testDotSitsOnALineOfItsOwnColor() {
        let rows = CommitGraph.layout([
            commit("merge", parents: ["main", "topic"]),
            commit("topic", parents: ["base"]),
            commit("main", parents: ["base"]),
            commit("base")
        ])

        for row in rows {
            XCTAssertTrue(row.lines.contains { line in
                line.color == row.color
                    && (line.from == row.lane || line.from == nil)
                    && (line.to == row.lane || line.to == nil)
            })
            XCTAssertLessThan(row.lane, row.width)
        }
    }
}
