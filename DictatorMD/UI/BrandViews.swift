import SwiftUI

enum DictatorBrand {
    static let yellow = Color(red: 1.0, green: 0.80, blue: 0.13)
    static let yellowSoft = Color(red: 1.0, green: 0.91, blue: 0.35)
    static let ink = Color(red: 0.08, green: 0.08, blue: 0.07)
    static let graphite = Color(red: 0.09, green: 0.095, blue: 0.10)
    static let panel = Color(red: 0.13, green: 0.135, blue: 0.145)
    static let cyan = Color(red: 0.18, green: 0.78, blue: 0.86)
    static let green = Color(red: 0.27, green: 0.86, blue: 0.48)

    static var iconGradient: LinearGradient {
        LinearGradient(
            colors: [yellowSoft, yellow, Color(red: 0.92, green: 0.58, blue: 0.07)],
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
                .rotationEffect(.degrees(-7))
                .offset(x: size * -0.01, y: size * 0.015)

            if showsStars {
                SparkleStar(size: size * 0.055)
                    .fill(DictatorBrand.ink.opacity(0.88))
                    .frame(width: size * 0.055, height: size * 0.055)
                    .offset(x: size * 0.30, y: -size * 0.31)

                SparkleStar(size: size * 0.040)
                    .fill(DictatorBrand.ink.opacity(0.72))
                    .frame(width: size * 0.040, height: size * 0.040)
                    .offset(x: -size * 0.30, y: -size * 0.24)

                SparkleStar(size: size * 0.034)
                    .fill(DictatorBrand.ink.opacity(0.62))
                    .frame(width: size * 0.034, height: size * 0.034)
                    .offset(x: size * 0.32, y: size * 0.25)
            }
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(DictatorBrand.ink.opacity(0.14), lineWidth: max(0.7, size * 0.018))
        )
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
