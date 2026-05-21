import SwiftUI

enum AppTheme {
    static let backgroundBase = Color(red: 0.956, green: 0.956, blue: 0.972)
    static let sidebarBase = Color(red: 0.925, green: 0.925, blue: 0.945)

    static let panel = Color.white.opacity(0.72)
    static let panelSolid = Color.white
    static let panelSubtle = Color.black.opacity(0.04)
    static let editor = Color.white.opacity(0.82)

    static let line = Color.black.opacity(0.12)
    static let lineStrong = Color.black.opacity(0.20)

    static let text = Color(red: 0.12, green: 0.14, blue: 0.16)
    static let muted = Color(red: 0.42, green: 0.45, blue: 0.50)
    static let muted2 = Color(red: 0.54, green: 0.56, blue: 0.60)

    static let blue = Color(red: 0.04, green: 0.52, blue: 1.00)
    static let green = Color(red: 0.18, green: 0.64, blue: 0.31)
    static let orange = Color(red: 0.75, green: 0.42, blue: 0.01)
    static let red = Color(red: 0.82, green: 0.14, blue: 0.18)
    static let purple = Color(red: 0.51, green: 0.31, blue: 0.87)
    static let dark = Color(red: 0.15, green: 0.17, blue: 0.20)

    static let radiusXL: CGFloat = 22
    static let radiusLG: CGFloat = 16
    static let radiusMD: CGFloat = 12
    static let radiusSM: CGFloat = 10

    static let pagePadding: CGFloat = 22
    static let cardPadding: CGFloat = 18
    static let sectionGap: CGFloat = 16

    static let shadow = Color.black.opacity(0.08)

    enum Motion {
        static let easeOut = Animation.timingCurve(0.2, 0.7, 0.2, 1, duration: 0.18)
        static let spring = Animation.spring(response: 0.32, dampingFraction: 0.78)
        static let viewSwitch = Animation.timingCurve(0.2, 0.7, 0.2, 1, duration: 0.22)
    }

    // Backward-compatible semantic aliases while older views are migrated.
    static let background = backgroundBase
    static let sidebar = sidebarBase
    static let surface = panelSolid.opacity(0.82)
    static let surfaceAlt = panelSubtle
    static let border = line
}

struct AppBackgroundView: View {
    var body: some View {
        ZStack {
            AppTheme.backgroundBase
            RadialGradient(
                colors: [AppTheme.blue.opacity(0.08), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 520
            )
            RadialGradient(
                colors: [AppTheme.purple.opacity(0.08), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 520
            )
        }
        .ignoresSafeArea()
    }
}

extension View {
    func subtleBorder(_ radius: CGFloat = 8) -> some View {
        clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
    }

    func glassPanel(radius: CGFloat = AppTheme.radiusXL) -> some View {
        background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.white.opacity(0.85), lineWidth: 1)
            )
            .shadow(color: AppTheme.shadow, radius: 24, x: 0, y: 14)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    func glassCard(radius: CGFloat = AppTheme.radiusLG) -> some View {
        background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .background(Color.white.opacity(0.64), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.white.opacity(0.86), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 16, x: 0, y: 8)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    func softControl(radius: CGFloat = AppTheme.radiusMD) -> some View {
        padding(10)
            .background(AppTheme.editor, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(AppTheme.lineStrong, lineWidth: 1)
            )
    }

    func focusRing(active: Bool) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMD, style: .continuous)
                .stroke(active ? AppTheme.blue.opacity(0.45) : Color.clear, lineWidth: 1)
        )
        .shadow(color: active ? AppTheme.blue.opacity(0.18) : .clear, radius: active ? 8 : 0, x: 0, y: 0)
    }
}

extension String {
    var linesFromEditor: [String] {
        split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
