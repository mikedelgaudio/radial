import SwiftUI

struct RingBezelCanvas: View {
    let bezelRadius: CGFloat
    let innerGlowRadius: CGFloat
    let accent: Color

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)

            func ring(_ r: CGFloat) -> Path {
                Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            }
            ctx.stroke(ring(bezelRadius), with: .color(.gray.opacity(0.35)), lineWidth: 2)
            ctx.stroke(ring(bezelRadius - 10), with: .color(.gray.opacity(0.18)), lineWidth: 1)
            ctx.stroke(ring(innerGlowRadius),
                       with: .color(accent.opacity(0.25)), lineWidth: 1.5)

            // tick marks around the bezel
            let ticks = 120
            for i in 0..<ticks {
                let a = CGFloat(i) / CGFloat(ticks) * 2 * .pi
                let outer = bezelRadius - 2
                let inner = bezelRadius - (i % 10 == 0 ? 10 : 5)
                var p = Path()
                p.move(to: CGPoint(x: c.x + outer * cos(a), y: c.y + outer * sin(a)))
                p.addLine(to: CGPoint(x: c.x + inner * cos(a), y: c.y + inner * sin(a)))
                ctx.stroke(p, with: .color(.gray.opacity(i % 10 == 0 ? 0.5 : 0.28)),
                           lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
    }
}
