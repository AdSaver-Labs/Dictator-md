import SwiftUI

enum DictatorBrand {
    static let yellow = Color(red: 0.92, green: 0.61, blue: 0.06)
    static let yellowSoft = Color(red: 0.98, green: 0.77, blue: 0.16)
    static let ink = Color(red: 0.08, green: 0.08, blue: 0.07)
    static let graphite = Color(red: 0.09, green: 0.095, blue: 0.10)
    static let panel = Color(red: 0.13, green: 0.135, blue: 0.145)
    static let cyan = Color(red: 0.42, green: 0.78, blue: 1.0)
    static let green = yellow

    static var iconGradient: LinearGradient {
        LinearGradient(
            colors: [yellowSoft, yellow, Color(red: 0.78, green: 0.40, blue: 0.03)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct DictatorLogoMark: View {
    let size: CGFloat
    var showsStars = true
    var cornerRadius: CGFloat? = nil

    var body: some View {
        let radius = cornerRadius ?? size * 0.24

        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(DictatorBrand.iconGradient)

            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.13), Color.white.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Image(systemName: "mic.fill")
                .font(.system(size: size * 0.44, weight: .bold))
                .foregroundStyle(DictatorBrand.ink)
                .rotationEffect(.degrees(-5))

            if showsStars {
                SparkleStar(size: size * 0.138)
                    .fill(DictatorBrand.ink.opacity(0.88))
                    .frame(width: size * 0.138, height: size * 0.138)
                    .offset(x: size * 0.18, y: -size * 0.14)

                SparkleStar(size: size * 0.078)
                    .fill(DictatorBrand.ink.opacity(0.72))
                    .frame(width: size * 0.078, height: size * 0.078)
                    .offset(x: size * 0.30, y: -size * 0.25)

                SparkleStar(size: size * 0.086)
                    .fill(DictatorBrand.ink.opacity(0.68))
                    .frame(width: size * 0.086, height: size * 0.086)
                    .offset(x: size * 0.29, y: -size * 0.01)
            }
        }
        .frame(width: size, height: size)
    }
}

struct SparkleStar: Shape {
    let size: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let long = min(rect.width, rect.height) / 2
        let short = long * 0.34
        var path = Path()

        let points = [
            CGPoint(x: center.x, y: center.y - long),
            CGPoint(x: center.x + short, y: center.y - short),
            CGPoint(x: center.x + long, y: center.y),
            CGPoint(x: center.x + short, y: center.y + short),
            CGPoint(x: center.x, y: center.y + long),
            CGPoint(x: center.x - short, y: center.y + short),
            CGPoint(x: center.x - long, y: center.y),
            CGPoint(x: center.x - short, y: center.y - short)
        ]

        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}
