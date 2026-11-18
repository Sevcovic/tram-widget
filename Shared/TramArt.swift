import SwiftUI

/// Tram + Zelená shelter drawing, ported from design/tram-animation.html.
/// All drawing functions use a context whose origin sits on the rail: +x is forward, negative y is outward (above the rail).
enum TramArt {
    static let segment: CGFloat = 15
    static let gap: CGFloat = 1.2
    static let count = 4
    static var length: CGFloat { CGFloat(count) * segment + CGFloat(count - 1) * gap }
    /// Height of the drawing above the rail (body + pantograph / shelter roof).
    static let height: CGFloat = 14

    static let red = Color(red: 0.85, green: 0.15, blue: 0.18)
    static let window = Color(red: 0.23, green: 0.24, blue: 0.27)
    static let cab = Color(red: 0.16, green: 0.17, blue: 0.19)
    /// Badge palette. Lines at the chosen stop get colours by their order (first blue, second red, …)
    /// unless the user picked one in the app, so lines like 8 and 18 never look the same.
    static let palette: [Color] = [
        Color(red: 0.16, green: 0.42, blue: 0.86),  // blue
        red,
        Color(red: 0.12, green: 0.62, blue: 0.36),  // green
        Color(red: 0.91, green: 0.52, blue: 0.05),  // orange
        Color(red: 0.55, green: 0.32, blue: 0.82),  // purple
        Color(red: 0.05, green: 0.60, blue: 0.66),  // teal
        Color(red: 0.36, green: 0.38, blue: 0.42),  // graphite
    ]

    static func colorIndex(_ line: String, stop: StopChoice = SharedStore.stop) -> Int {
        if let i = SharedStore.lineColors[line] { return i % palette.count }
        if let i = stop.lines.firstIndex(of: line) { return i % palette.count }
        return palette.count - 1
    }

    static func lineColor(_ line: String) -> Color { palette[colorIndex(line)] }

    static func modeSymbol(_ mode: String) -> String {
        switch mode {
        case "t": return "tram.fill"
        case "m": return "tram.fill.tunnel"
        case "r": return "train.side.front.car"
        case "f": return "ferry.fill"
        case "l": return "cablecar.fill"
        default: return "bus.fill"
        }
    }

    static func bodyColor(_ dark: Bool) -> Color { dark ? Color(white: 0.90) : Color(white: 0.95) }

    /// One articulated section, centred on the origin. k = 0 is the front cab.
    static func drawSection(_ ctx: GraphicsContext, k: Int, dark: Bool) {
        let L = segment, h: CGFloat = 10, top: CGFloat = -11, x0 = -L / 2, nose: CGFloat = 4
        let front = k == 0, rear = k == count - 1, redTop = k % 2 == 1
        let bodyC = bodyColor(dark)

        var body = Path()
        if front {
            body.move(to: CGPoint(x: x0, y: top))
            body.addLine(to: CGPoint(x: x0 + L - nose, y: top))
            body.addQuadCurve(to: CGPoint(x: x0 + L, y: top + nose + 1), control: CGPoint(x: x0 + L, y: top))
            body.addLine(to: CGPoint(x: x0 + L, y: -1))
            body.addLine(to: CGPoint(x: x0, y: -1))
            body.closeSubpath()
        } else if rear {
            body.move(to: CGPoint(x: x0 + nose, y: top))
            body.addLine(to: CGPoint(x: x0 + L, y: top))
            body.addLine(to: CGPoint(x: x0 + L, y: -1))
            body.addLine(to: CGPoint(x: x0, y: -1))
            body.addLine(to: CGPoint(x: x0, y: top + nose + 1))
            body.addQuadCurve(to: CGPoint(x: x0 + nose, y: top), control: CGPoint(x: x0, y: top))
            body.closeSubpath()
        } else {
            body = Path(CGRect(x: x0, y: top, width: L, height: h))
        }

        if k == 1 { // pantograph
            var p = Path()
            p.move(to: CGPoint(x: x0 + 4, y: top))
            p.addLine(to: CGPoint(x: x0 + 6, y: top - 2.4))
            p.addLine(to: CGPoint(x: x0 + 8.6, y: top - 2.4))
            p.move(to: CGPoint(x: x0 + 4.6, y: top - 2.4))
            p.addLine(to: CGPoint(x: x0 + 9, y: top - 2.4))
            ctx.stroke(p, with: .color(.gray), style: StrokeStyle(lineWidth: 0.55, lineCap: .round))
        }

        var c = ctx
        c.clip(to: body)
        c.fill(body, with: .color(bodyC))
        if redTop { c.fill(Path(CGRect(x: x0, y: top, width: L, height: 2.2)), with: .color(red)) }
        c.fill(Path(CGRect(x: x0, y: top + 3, width: L, height: 3.6)), with: .color(window))
        if !redTop { c.fill(Path(CGRect(x: x0, y: -3.6, width: L, height: 2.6)), with: .color(red)) }
        if front {
            c.fill(Path(CGRect(x: x0 + L - 5, y: top, width: 5, height: h - 2)), with: .color(cab))
            c.fill(Path(ellipseIn: CGRect(x: x0 + L - 2.1, y: -5.1, width: 1.4, height: 1.4)), with: .color(Color(red: 1, green: 0.97, blue: 0.84)))
        }
        if rear { c.fill(Path(CGRect(x: x0, y: top, width: 4, height: h - 3)), with: .color(cab)) }
        c.fill(Path(CGRect(x: x0 + L / 2 - 1.6, y: top + 3.2, width: 3.2, height: 7.4)), with: .color(.black.opacity(0.25)))

        ctx.stroke(body, with: .color(.black.opacity(0.18)), lineWidth: 0.35)
        ctx.fill(Path(roundedRect: CGRect(x: x0 + 1, y: -1, width: L - 2, height: 0.9), cornerRadius: 0.45),
                 with: .color(.black.opacity(0.35)))
    }

    /// Whole tram drawn straight, front at x = 0 facing +x.
    static func drawStraight(_ ctx: GraphicsContext, dark: Bool) {
        for k in 0..<count {
            var c = ctx
            c.translateBy(x: -CGFloat(k) * (segment + gap) - segment / 2, y: 0)
            drawSection(c, k: k, dark: dark)
        }
    }

    /// Zelená shelter centred on the origin: slatted canopy, two white posts, glass panel, bench, info display.
    static func drawShelter(_ ctx: GraphicsContext, dark: Bool) {
        let roof = dark ? Color(white: 0.56) : Color(red: 0.23, green: 0.24, blue: 0.26)
        let post = dark ? Color(white: 0.90) : Color(white: 0.79)
        let glass = Color(red: 0.59, green: 0.72, blue: 0.78).opacity(dark ? 0.22 : 0.28)
        let glassEdge = dark ? Color(white: 0.85).opacity(0.4) : Color(red: 0.24, green: 0.27, blue: 0.31).opacity(0.35)
        let roofY: CGFloat = -13.2

        let panel = Path(CGRect(x: -0.5, y: -10.6, width: 11.5, height: 10))
        ctx.fill(panel, with: .color(glass))
        ctx.stroke(panel, with: .color(glassEdge), lineWidth: 0.3)
        ctx.stroke(line(2, -10.6, 2, -0.6), with: .color(glassEdge), lineWidth: 0.25)

        ctx.fill(Path(roundedRect: CGRect(x: -3.6, y: -7.4, width: 2.6, height: 1.8), cornerRadius: 0.3),
                 with: .color(Color(red: 0.17, green: 0.2, blue: 0.25)))
        ctx.fill(Path(CGRect(x: -3.3, y: -7.1, width: 2, height: 1.2)), with: .color(Color(red: 0.5, green: 0.7, blue: 0.85)))

        ctx.fill(Path(roundedRect: CGRect(x: -10, y: -3.1, width: 10, height: 0.8), cornerRadius: 0.3), with: .color(roof))
        ctx.stroke(line(-9, -2.3, -9, -0.4), with: .color(roof), lineWidth: 0.5)
        ctx.stroke(line(-1, -2.3, -1, -0.4), with: .color(roof), lineWidth: 0.5)

        ctx.stroke(line(-13, roofY + 1, -13, -0.3), with: .color(post), lineWidth: 0.9)
        ctx.stroke(line(12.5, roofY + 1, 12.5, -0.3), with: .color(post), lineWidth: 0.9)

        ctx.fill(Path(roundedRect: CGRect(x: -18, y: roofY, width: 36, height: 1.5), cornerRadius: 0.4), with: .color(roof))
        for k in 0..<9 {
            let x = -17 + CGFloat(k) * 4.2
            ctx.stroke(line(x, roofY + 1.5, x + 1.6, roofY + 2.6), with: .color(roof), lineWidth: 0.45)
        }
    }

    private static func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) -> Path {
        var p = Path(); p.move(to: CGPoint(x: x1, y: y1)); p.addLine(to: CGPoint(x: x2, y: y2)); return p
    }
}

/// Fixed-size views for the widget (rail at the bottom edge of the frame).
struct TramStraightView: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        Canvas { ctx, size in
            var c = ctx
            c.translateBy(x: size.width, y: size.height)
            TramArt.drawStraight(c, dark: scheme == .dark)
        }
        .frame(width: TramArt.length, height: TramArt.height)
    }
}

struct ShelterView: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        Canvas { ctx, size in
            var c = ctx
            c.translateBy(x: size.width / 2, y: size.height)
            TramArt.drawShelter(c, dark: scheme == .dark)
        }
        .frame(width: 36, height: TramArt.height)
    }
}
