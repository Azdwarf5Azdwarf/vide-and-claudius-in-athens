#if canImport(SwiftUI)
import SwiftUI
import GitVisualizerCore

/// Draws the day's companion and animates it according to its mood.
///
/// Everything is drawn procedurally into a `Canvas` — there are no image assets
/// to ship, and a new creature costs nothing but a different seed.
@available(macOS 13.0, *)
public struct DailyEntityView: View {
    private let entity: DailyEntity
    private let size: CGFloat

    public init(entity: DailyEntity, size: CGFloat = 96) {
        self.entity = entity
        self.size = size
    }

    public var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, canvasSize in
                draw(in: &context, size: canvasSize, time: t)
            }
            .frame(width: size, height: size)
            .accessibilityLabel("\(entity.name) the \(entity.species.rawValue), \(entity.mood.caption)")
        }
    }

    // MARK: - Motion

    /// Vertical offset in points. Jumping is the whole point of the thing.
    private func bounce(at time: Double) -> CGFloat {
        let speed = 1.2 + entity.energy * 2.0
        let phase = time * speed

        switch entity.mood {
        case .sleeping:
            // Slow breathing, never leaves the ground.
            return CGFloat(sin(phase * 0.5) * 1.5)
        case .celebrating:
            // Repeated hops with a hang at the top.
            let hop = abs(sin(phase * 2.2))
            return CGFloat(-hop * hop * 18 * (0.5 + entity.energy))
        case .waving:
            return CGFloat(sin(phase * 1.6) * 4)
        case .focused:
            // Tight, determined little bobs.
            return CGFloat(sin(phase * 3.0) * 2.5)
        case .thinking:
            return CGFloat(sin(phase * 0.7) * 3)
        case .concerned:
            return CGFloat(sin(phase * 0.9) * 1.5)
        case .idle:
            return CGFloat(sin(phase) * 5)
        }
    }

    /// Horizontal drift, so it wanders instead of hovering in place.
    private func drift(at time: Double, width: CGFloat) -> CGFloat {
        guard entity.mood != .sleeping else { return 0 }
        let range = width * 0.12 * (0.4 + entity.energy)
        return CGFloat(sin(time * 0.4)) * range
    }

    private func squash(at time: Double) -> CGSize {
        // Squash on landing, stretch at the peak — sells the weight of the jump.
        let lift = -bounce(at: time)
        let factor = 1 + (lift / 90)
        return CGSize(width: 1 / factor, height: factor)
    }

    // MARK: - Drawing

    private func draw(in context: inout GraphicsContext, size canvasSize: CGSize, time: Double) {
        let unit = min(canvasSize.width, canvasSize.height)
        let center = CGPoint(
            x: canvasSize.width / 2 + drift(at: time, width: canvasSize.width),
            y: canvasSize.height * 0.62 + bounce(at: time)
        )

        drawShadow(in: &context, canvasSize: canvasSize, unit: unit, time: time)

        let scale = squash(at: time)
        let bodyWidth = unit * 0.52 * (0.85 + entity.traits.roundness * 0.3) * scale.width
        let bodyHeight = unit * 0.46 * (1.15 - entity.traits.roundness * 0.25) * scale.height
        let body = CGRect(
            x: center.x - bodyWidth / 2,
            y: center.y - bodyHeight / 2,
            width: bodyWidth,
            height: bodyHeight
        )

        drawEars(in: &context, body: body, unit: unit, time: time)
        drawBody(in: &context, body: body)
        drawPattern(in: &context, body: body)
        drawFace(in: &context, body: body, unit: unit, time: time)
        drawAccessory(in: &context, body: body, unit: unit)
    }

    private func drawShadow(in context: inout GraphicsContext, canvasSize: CGSize, unit: CGFloat, time: Double) {
        // Shadow shrinks as the creature rises, which is what reads as "airborne".
        let lift = -bounce(at: time)
        let tightening = max(0.45, 1 - lift / 40)
        let width = unit * 0.42 * tightening
        let rect = CGRect(
            x: canvasSize.width / 2 + drift(at: time, width: canvasSize.width) - width / 2,
            y: canvasSize.height * 0.84,
            width: width,
            height: unit * 0.07 * tightening
        )
        context.fill(Path(ellipseIn: rect), with: .color(.black.opacity(0.18 * Double(tightening))))
    }

    private func drawBody(in context: inout GraphicsContext, body: CGRect) {
        let path: Path
        switch entity.species {
        case .ghost:
            path = ghostPath(in: body)
        case .bird:
            path = Path(ellipseIn: body.insetBy(dx: body.width * 0.08, dy: 0))
        default:
            path = Path(roundedRect: body, cornerRadius: body.height * (0.3 + entity.traits.roundness * 0.2))
        }

        context.fill(path, with: .linearGradient(
            Gradient(colors: [bodyColor(lighten: 0.1), bodyColor(lighten: -0.08)]),
            startPoint: CGPoint(x: body.midX, y: body.minY),
            endPoint: CGPoint(x: body.midX, y: body.maxY)
        ))
        context.stroke(path, with: .color(bodyColor(lighten: -0.3)), lineWidth: body.width * 0.02)
    }

    private func ghostPath(in body: CGRect) -> Path {
        var path = Path()
        let waveHeight = body.height * 0.12
        path.addArc(
            center: CGPoint(x: body.midX, y: body.midY),
            radius: body.width / 2,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: body.maxX, y: body.maxY - waveHeight))
        // Three scallops along the bottom edge.
        let step = body.width / 3
        for i in 0..<3 {
            let x = body.maxX - step * CGFloat(i)
            path.addQuadCurve(
                to: CGPoint(x: x - step, y: body.maxY - waveHeight),
                control: CGPoint(x: x - step / 2, y: body.maxY + waveHeight)
            )
        }
        path.closeSubpath()
        return path
    }

    private func drawPattern(in context: inout GraphicsContext, body: CGRect) {
        let accent = accentColor().opacity(0.5)
        switch entity.traits.pattern {
        case .plain:
            break
        case .belly:
            let belly = CGRect(
                x: body.midX - body.width * 0.22,
                y: body.midY,
                width: body.width * 0.44,
                height: body.height * 0.42
            )
            context.fill(Path(ellipseIn: belly), with: .color(accent))
        case .spots:
            for i in 0..<3 {
                let angle = Double(i) * 2.4
                let spot = CGRect(
                    x: body.midX + CGFloat(cos(angle)) * body.width * 0.24 - body.width * 0.06,
                    y: body.midY + CGFloat(sin(angle)) * body.height * 0.22,
                    width: body.width * 0.12,
                    height: body.width * 0.12
                )
                context.fill(Path(ellipseIn: spot), with: .color(accent))
            }
        case .stripes:
            for i in 1...2 {
                let y = body.minY + body.height * (0.45 + CGFloat(i) * 0.18)
                var stripe = Path()
                stripe.move(to: CGPoint(x: body.minX + body.width * 0.2, y: y))
                stripe.addLine(to: CGPoint(x: body.maxX - body.width * 0.2, y: y))
                context.stroke(stripe, with: .color(accent), lineWidth: body.height * 0.05)
            }
        }
    }

    private func drawEars(in context: inout GraphicsContext, body: CGRect, unit: CGFloat, time: Double) {
        let earColor = accentColor()
        switch entity.species {
        case .cat, .fox:
            let earWidth = body.width * (entity.species == .fox ? 0.3 : 0.24)
            let earHeight = body.height * (entity.species == .fox ? 0.5 : 0.38)
            for side in [-1.0, 1.0] {
                var ear = Path()
                let baseX = body.midX + CGFloat(side) * body.width * 0.28
                ear.move(to: CGPoint(x: baseX - earWidth / 2, y: body.minY + body.height * 0.15))
                ear.addLine(to: CGPoint(x: baseX, y: body.minY - earHeight * 0.55))
                ear.addLine(to: CGPoint(x: baseX + earWidth / 2, y: body.minY + body.height * 0.15))
                ear.closeSubpath()
                context.fill(ear, with: .color(earColor))
            }
        case .capybara:
            for side in [-1.0, 1.0] {
                let ear = CGRect(
                    x: body.midX + CGFloat(side) * body.width * 0.34 - body.width * 0.07,
                    y: body.minY - body.height * 0.04,
                    width: body.width * 0.14,
                    height: body.width * 0.14
                )
                context.fill(Path(ellipseIn: ear), with: .color(earColor))
            }
        case .bird:
            // A single crest feather that sways with the bounce.
            var crest = Path()
            let sway = CGFloat(sin(time * 2)) * unit * 0.02
            crest.move(to: CGPoint(x: body.midX, y: body.minY))
            crest.addQuadCurve(
                to: CGPoint(x: body.midX + sway, y: body.minY - body.height * 0.4),
                control: CGPoint(x: body.midX + body.width * 0.18, y: body.minY - body.height * 0.2)
            )
            context.stroke(crest, with: .color(earColor), lineWidth: body.width * 0.06)
        case .blob, .ghost:
            break
        }
    }

    private func drawFace(in context: inout GraphicsContext, body: CGRect, unit: CGFloat, time: Double) {
        let eyeRadius = unit * 0.035 * (0.7 + entity.traits.eyeSize * 0.8)
        let eyeY = body.midY - body.height * 0.08
        let eyeOffset = body.width * 0.2
        let ink = GraphicsContext.Shading.color(.black.opacity(0.82))

        // Blink on a slow, slightly irregular cycle.
        let blinking = sin(time * 0.9) > 0.97
        let closed = entity.mood == .sleeping || blinking

        for side in [-1.0, 1.0] {
            let x = body.midX + CGFloat(side) * eyeOffset
            if closed {
                var lid = Path()
                lid.move(to: CGPoint(x: x - eyeRadius, y: eyeY))
                lid.addQuadCurve(
                    to: CGPoint(x: x + eyeRadius, y: eyeY),
                    control: CGPoint(x: x, y: eyeY + eyeRadius * 0.8)
                )
                context.stroke(lid, with: ink, lineWidth: eyeRadius * 0.45)
            } else if entity.mood == .focused {
                // Narrowed, determined eyes.
                let slit = CGRect(
                    x: x - eyeRadius,
                    y: eyeY - eyeRadius * 0.35,
                    width: eyeRadius * 2,
                    height: eyeRadius * 0.7
                )
                context.fill(Path(roundedRect: slit, cornerRadius: eyeRadius * 0.35), with: ink)
            } else {
                let eye = CGRect(
                    x: x - eyeRadius,
                    y: eyeY - eyeRadius,
                    width: eyeRadius * 2,
                    height: eyeRadius * 2
                )
                context.fill(Path(ellipseIn: eye), with: ink)
                // Catchlight, offset toward where the creature is looking.
                let look = entity.mood == .thinking ? CGFloat(sin(time * 0.6)) * eyeRadius * 0.3 : 0
                let glint = CGRect(
                    x: x - eyeRadius * 0.15 + look,
                    y: eyeY - eyeRadius * 0.55,
                    width: eyeRadius * 0.7,
                    height: eyeRadius * 0.7
                )
                context.fill(Path(ellipseIn: glint), with: .color(.white.opacity(0.9)))
            }
        }

        drawMouth(in: &context, body: body, unit: unit, ink: ink)

        if entity.mood == .concerned {
            // A single sweat drop, because it is having a day.
            let drop = CGRect(
                x: body.midX + body.width * 0.34,
                y: body.minY + body.height * 0.16,
                width: unit * 0.04,
                height: unit * 0.055
            )
            context.fill(Path(ellipseIn: drop), with: .color(.cyan.opacity(0.75)))
        }
    }

    private func drawMouth(in context: inout GraphicsContext, body: CGRect, unit: CGFloat, ink: GraphicsContext.Shading) {
        let mouthY = body.midY + body.height * 0.16
        let width = body.width * 0.16
        var mouth = Path()

        switch entity.mood {
        case .celebrating:
            let open = CGRect(x: body.midX - width * 0.6, y: mouthY - width * 0.2, width: width * 1.2, height: width)
            context.fill(Path(ellipseIn: open), with: ink)
            return
        case .concerned:
            mouth.move(to: CGPoint(x: body.midX - width, y: mouthY + width * 0.35))
            mouth.addQuadCurve(
                to: CGPoint(x: body.midX + width, y: mouthY + width * 0.35),
                control: CGPoint(x: body.midX, y: mouthY - width * 0.3)
            )
        case .sleeping, .thinking:
            mouth.move(to: CGPoint(x: body.midX - width * 0.5, y: mouthY))
            mouth.addLine(to: CGPoint(x: body.midX + width * 0.5, y: mouthY))
        default:
            mouth.move(to: CGPoint(x: body.midX - width, y: mouthY))
            mouth.addQuadCurve(
                to: CGPoint(x: body.midX + width, y: mouthY),
                control: CGPoint(x: body.midX, y: mouthY + width * 0.9)
            )
        }
        context.stroke(mouth, with: ink, lineWidth: unit * 0.018)
    }

    private func drawAccessory(in context: inout GraphicsContext, body: CGRect, unit: CGFloat) {
        let color = accentColor(lighten: -0.15)
        switch entity.traits.accessory {
        case .none:
            break
        case .leaf:
            var leaf = Path()
            let tip = CGPoint(x: body.midX + body.width * 0.3, y: body.minY - body.height * 0.3)
            leaf.move(to: CGPoint(x: body.midX, y: body.minY))
            leaf.addQuadCurve(to: tip, control: CGPoint(x: body.midX + body.width * 0.05, y: body.minY - body.height * 0.25))
            leaf.addQuadCurve(to: CGPoint(x: body.midX, y: body.minY), control: CGPoint(x: body.midX + body.width * 0.3, y: body.minY - body.height * 0.05))
            context.fill(leaf, with: .color(.green.opacity(0.8)))
        case .scarf:
            let scarf = CGRect(
                x: body.midX - body.width * 0.34,
                y: body.maxY - body.height * 0.22,
                width: body.width * 0.68,
                height: body.height * 0.14
            )
            context.fill(Path(roundedRect: scarf, cornerRadius: scarf.height / 2), with: .color(color))
        case .hat:
            var hat = Path()
            hat.move(to: CGPoint(x: body.midX - body.width * 0.3, y: body.minY + body.height * 0.06))
            hat.addLine(to: CGPoint(x: body.midX, y: body.minY - body.height * 0.34))
            hat.addLine(to: CGPoint(x: body.midX + body.width * 0.3, y: body.minY + body.height * 0.06))
            hat.closeSubpath()
            context.fill(hat, with: .color(color))
        case .antenna:
            var stalk = Path()
            stalk.move(to: CGPoint(x: body.midX, y: body.minY))
            stalk.addLine(to: CGPoint(x: body.midX, y: body.minY - body.height * 0.32))
            context.stroke(stalk, with: .color(color), lineWidth: unit * 0.015)
            let bulb = CGRect(
                x: body.midX - unit * 0.035,
                y: body.minY - body.height * 0.32 - unit * 0.035,
                width: unit * 0.07,
                height: unit * 0.07
            )
            context.fill(Path(ellipseIn: bulb), with: .color(color))
        }
    }

    // MARK: - Colour

    private func bodyColor(lighten: Double = 0) -> Color {
        Color(
            hue: entity.palette.hue / 360,
            saturation: entity.palette.saturation,
            brightness: min(max(entity.palette.lightness + lighten, 0), 1)
        )
    }

    private func accentColor(lighten: Double = 0) -> Color {
        Color(
            hue: entity.palette.accentHue / 360,
            saturation: min(entity.palette.saturation + 0.1, 1),
            brightness: min(max(entity.palette.lightness + lighten, 0), 1)
        )
    }
}

/// The entity plus its name and mood caption, sized for a sidebar footer.
@available(macOS 13.0, *)
public struct DailyEntityBadge: View {
    private let entity: DailyEntity

    public init(entity: DailyEntity) {
        self.entity = entity
    }

    public var body: some View {
        HStack(spacing: 10) {
            DailyEntityView(entity: entity, size: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(entity.name)
                    .font(.system(size: 12, weight: .semibold))
                Text(entity.mood.caption)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
    }
}
#endif
