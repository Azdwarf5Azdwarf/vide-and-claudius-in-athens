#if canImport(SwiftUI)
import SwiftUI
import GitVisualizerCore

/// Draws one row's slice of the commit graph.
///
/// The cell fills whatever height its row has, and lines run edge to edge, so
/// stacked rows join up into continuous lanes.
@available(macOS 13.0, *)
public struct CommitGraphCell: View {
    private let row: CommitGraph.Row

    /// Horizontal space one lane takes up.
    public static let laneWidth: CGFloat = 12

    public static let palette: [Color] = [
        .orange, .green, .teal, .purple, .pink, .red, .yellow, .blue
    ]

    public init(row: CommitGraph.Row) {
        self.row = row
    }

    /// Width needed to show `lanes` lanes side by side.
    public static func width(lanes: Int) -> CGFloat {
        CGFloat(max(lanes, 1)) * laneWidth
    }

    public var body: some View {
        Canvas { context, size in
            draw(in: &context, size: size)
        }
        .accessibilityHidden(true)
    }

    private func x(_ lane: Int) -> CGFloat {
        (CGFloat(lane) + 0.5) * Self.laneWidth
    }

    private func color(_ index: Int) -> Color {
        Self.palette[index % Self.palette.count]
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let midY = size.height / 2
        let dot = CGPoint(x: x(row.lane), y: midY)

        for line in row.lines {
            var path = Path()
            switch (line.from, line.to) {
            case let (from?, to?):
                let start = CGPoint(x: x(from), y: 0)
                let end = CGPoint(x: x(to), y: size.height)
                path.move(to: start)
                if from == to {
                    path.addLine(to: end)
                } else {
                    path.addCurve(
                        to: end,
                        control1: CGPoint(x: start.x, y: midY),
                        control2: CGPoint(x: end.x, y: midY)
                    )
                }
            case let (from?, nil):
                path.move(to: CGPoint(x: x(from), y: 0))
                path.addQuadCurve(to: dot, control: CGPoint(x: x(from), y: midY))
            case let (nil, to?):
                path.move(to: dot)
                path.addQuadCurve(
                    to: CGPoint(x: x(to), y: size.height),
                    control: CGPoint(x: x(to), y: midY)
                )
            case (nil, nil):
                continue
            }
            context.stroke(path, with: .color(color(line.color)), lineWidth: 2)
        }

        let radius: CGFloat = row.isMerge ? 3 : 4
        let circle = Path(ellipseIn: CGRect(
            x: dot.x - radius, y: dot.y - radius, width: radius * 2, height: radius * 2
        ))
        if row.isMerge {
            // Merges read as hollow rings, so the eye can skip along real work.
            context.fill(circle, with: .color(Color(nsColor: .textBackgroundColor)))
            context.stroke(circle, with: .color(color(row.color)), lineWidth: 2)
        } else {
            context.fill(circle, with: .color(color(row.color)))
        }
    }
}
#endif
