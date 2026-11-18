import SwiftUI

/// Rounded-rect rail, clockwise from the top-left (just after the corner). Analytic point-at-distance.
struct Rail {
    let size: CGSize, inset: CGFloat, radius: CGFloat
    private var a: CGFloat { size.width - 2 * inset - 2 * radius }   // top / bottom straight
    private var b: CGFloat { size.height - 2 * inset - 2 * radius }  // left / right straight
    private var q: CGFloat { .pi * radius / 2 }                       // quarter arc
    var length: CGFloat { 2 * a + 2 * b + 4 * q }

    var path: Path {
        Path(roundedRect: CGRect(x: inset, y: inset, width: size.width - 2 * inset, height: size.height - 2 * inset),
             cornerRadius: radius, style: .circular)
    }

    /// Point and heading (radians) at distance d along the rail.
    func point(at distance: CGFloat) -> (CGPoint, CGFloat) {
        let W = size.width, H = size.height, i = inset, r = radius
        var d = distance.truncatingRemainder(dividingBy: length)
        if d < 0 { d += length }
        func arc(_ c: CGPoint, _ start: CGFloat) -> (CGPoint, CGFloat) {
            let t = start + d / r
            return (CGPoint(x: c.x + r * cos(t), y: c.y + r * sin(t)), t + .pi / 2)
        }
        if d < a { return (CGPoint(x: i + r + d, y: i), 0) }; d -= a
        if d < q { return arc(CGPoint(x: W - i - r, y: i + r), -.pi / 2) }; d -= q
        if d < b { return (CGPoint(x: W - i, y: i + r + d), .pi / 2) }; d -= b
        if d < q { return arc(CGPoint(x: W - i - r, y: H - i - r), 0) }; d -= q
        if d < a { return (CGPoint(x: W - i - r - d, y: H - i), .pi) }; d -= a
        if d < q { return arc(CGPoint(x: i + r, y: H - i - r), .pi / 2) }; d -= q
        if d < b { return (CGPoint(x: i, y: H - i - r - d), -.pi / 2) }; d -= b
        return arc(CGPoint(x: i + r, y: i + r), .pi)
    }
}

/// Variant A: on every refresh the tram laps the card along the inner rail and stops at the Zelená shelter.
struct LapTrack: View {
    let trigger: Date
    var stopX: CGFloat = 104
    var inset: CGFloat = 15
    var radius: CGFloat = 9

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.distantPast
    @State private var running = false
    private let duration: Double = 2.8

    var body: some View {
        TimelineView(.animation(paused: !running)) { timeline in
            Canvas { ctx, size in
                let rail = Rail(size: size, inset: inset, radius: radius)
                let dark = scheme == .dark
                ctx.stroke(rail.path, with: .color(.secondary.opacity(0.35)), lineWidth: 1)

                var s = ctx
                s.translateBy(x: stopX, y: inset)
                TramArt.drawShelter(s, dark: dark)

                let seg = TramArt.segment, gap = TramArt.gap
                let parked = (stopX - (inset + radius)) + 2 * (seg + gap) - gap / 2   // tram centred on shelter
                let t = min(1, max(0, timeline.date.timeIntervalSince(start) / duration))
                let e = CGFloat(t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2)
                let from = parked - rail.length * 0.85
                let front = from + (parked - from) * e

                for k in 0..<TramArt.count {
                    let (p, heading) = rail.point(at: front - CGFloat(k) * (seg + gap) - seg / 2)
                    var c = ctx
                    c.opacity = min(1, t / 0.08)
                    c.translateBy(x: p.x, y: p.y)
                    c.rotate(by: .radians(heading))
                    TramArt.drawSection(c, k: k, dark: dark)
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear(perform: play)
        .onChange(of: trigger) { _, _ in play() }
    }

    private func play() {
        guard !reduceMotion else { start = .distantPast; return }
        start = .now
        running = true
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1) { running = false }
    }
}
