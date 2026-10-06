import Foundation

/// Lays a commit list out as a lane graph, one row per commit.
///
/// The lane bookkeeping follows SourceGit's `CommitGraph.Generate`: walk the
/// commits newest-first, keep an ordered list of open lanes that each wait for
/// one hash, and let lanes slide left as soon as one to their left closes.
/// Where SourceGit builds whole-history paths for one big canvas, this emits
/// per-row line pieces, so each list row can draw its own slice.
public enum CommitGraph {

    /// A line crossing one row. Lanes are counted from the left, starting at 0.
    public struct Line: Equatable {
        /// Lane at the row's top edge. `nil` when the line starts at the dot.
        public let from: Int?
        /// Lane at the row's bottom edge. `nil` when the line ends at the dot.
        public let to: Int?
        /// Index into the caller's palette.
        public let color: Int

        public init(from: Int?, to: Int?, color: Int) {
            self.from = from
            self.to = to
            self.color = color
        }
    }

    public struct Row: Equatable {
        /// Lane the commit's dot sits in.
        public let lane: Int
        /// Palette index of the dot.
        public let color: Int
        public let isMerge: Bool
        public let lines: [Line]
        /// Lanes this row needs to be drawn without clipping.
        public let width: Int
    }

    private struct Lane {
        /// Hash this lane is waiting for.
        var next: String
        let color: Int
    }

    /// - Parameters:
    ///   - commits: Newest first, children before parents (`git log --date-order`).
    ///   - paletteSize: Number of colors the caller can draw with.
    /// - Returns: One row per commit, in the same order.
    public static func layout(_ commits: [Commit], paletteSize: Int = 8) -> [Row] {
        var lanes: [Lane] = []
        var colors = ColorPicker(count: max(paletteSize, 1))
        var rows: [Row] = []
        rows.reserveCapacity(commits.count)

        for commit in commits {
            var lines: [Line] = []
            var open: [Lane] = []
            var dot: (lane: Int, color: Int)?

            for (index, lane) in lanes.enumerated() {
                guard lane.next == commit.hash else {
                    // Just passing; slides left if a lane before it closed.
                    lines.append(Line(from: index, to: open.count, color: lane.color))
                    open.append(lane)
                    continue
                }

                if dot == nil, let firstParent = commit.parentHashes.first {
                    // The first lane to reach the commit carries on to its first parent.
                    dot = (index, lane.color)
                    lines.append(Line(from: index, to: open.count, color: lane.color))
                    open.append(Lane(next: firstParent, color: lane.color))
                } else {
                    // Every other lane waiting for this commit closes here.
                    if dot == nil { dot = (index, lane.color) }
                    lines.append(Line(from: index, to: nil, color: lane.color))
                    colors.recycle(lane.color)
                }
            }

            if dot == nil {
                // Nothing was waiting for this commit: it is a branch tip.
                let color = colors.next()
                dot = (open.count, color)
                if let firstParent = commit.parentHashes.first {
                    lines.append(Line(from: nil, to: open.count, color: color))
                    open.append(Lane(next: firstParent, color: color))
                } else {
                    colors.recycle(color)
                }
            }

            // Merge parents: join a lane already heading there, or open a new one.
            for parent in commit.parentHashes.dropFirst() {
                if let existing = open.firstIndex(where: { $0.next == parent }) {
                    lines.append(Line(from: nil, to: existing, color: open[existing].color))
                } else {
                    let color = colors.next()
                    lines.append(Line(from: nil, to: open.count, color: color))
                    open.append(Lane(next: parent, color: color))
                }
            }

            let placed = dot ?? (0, 0)
            rows.append(Row(
                lane: placed.lane,
                color: placed.color,
                isMerge: commit.parentHashes.count > 1,
                lines: lines,
                width: max(lanes.count, open.count, placed.lane + 1)
            ))
            lanes = open
        }

        return rows
    }

    /// Hands out palette indices in rotation, reusing a color once its lane closes.
    private struct ColorPicker {
        private let count: Int
        private var queue: [Int] = []

        init(count: Int) {
            self.count = count
        }

        mutating func next() -> Int {
            if queue.isEmpty { queue = Array(0..<count) }
            return queue.removeFirst()
        }

        mutating func recycle(_ color: Int) {
            if !queue.contains(color) { queue.append(color) }
        }
    }
}
