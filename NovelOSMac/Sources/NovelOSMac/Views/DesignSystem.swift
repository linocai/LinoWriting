import SwiftUI

enum AppTheme {
    static let background = Color(nsColor: .windowBackgroundColor)
    static let sidebar = Color(nsColor: .controlBackgroundColor)
    static let surface = Color(nsColor: .textBackgroundColor)
    static let surfaceAlt = Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
    static let border = Color(nsColor: .separatorColor).opacity(0.65)
    static let text = Color.primary
    static let muted = Color.secondary
    static let blue = Color(red: 0.20, green: 0.38, blue: 0.72)
    static let green = Color(red: 0.14, green: 0.48, blue: 0.32)
    static let orange = Color(red: 0.72, green: 0.42, blue: 0.16)
    static let red = Color(red: 0.68, green: 0.20, blue: 0.22)
    static let purple = Color(red: 0.45, green: 0.32, blue: 0.66)
    static let dark = Color(red: 0.20, green: 0.22, blue: 0.26)
}

extension View {
    func subtleBorder(_ radius: CGFloat = 8) -> some View {
        clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
    }
}

extension String {
    var linesFromEditor: [String] {
        split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
