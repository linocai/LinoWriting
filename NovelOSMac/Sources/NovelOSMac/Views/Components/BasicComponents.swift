import NovelOSMacCore
import SwiftUI

enum PillTone {
    case blue
    case green
    case orange
    case red
    case purple
    case dark
    case neutral

    var color: Color {
        switch self {
        case .blue: AppTheme.blue
        case .green: AppTheme.green
        case .orange: AppTheme.orange
        case .red: AppTheme.red
        case .purple: AppTheme.purple
        case .dark: AppTheme.dark
        case .neutral: AppTheme.muted
        }
    }
}

struct PillView: View {
    let text: String
    var tone: PillTone = .neutral

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(tone.color)
            .background(tone.color.opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke(tone.color.opacity(0.22), lineWidth: 1))
    }
}

struct CardView<Content: View>: View {
    var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .background(AppTheme.surface)
        .subtleBorder()
    }
}

struct CardHeader<Trailing: View>: View {
    let title: String
    let subtitle: String?
    let trailing: Trailing

    init(title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                if let subtitle {
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 16)
            trailing
        }
        .padding(16)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.border).frame(height: 1)
        }
    }
}

struct CardBody<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content
        }
        .padding(16)
    }
}

struct CardFooter<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 10) {
            Spacer()
            content
        }
        .padding(16)
        .overlay(alignment: .top) {
            Rectangle().fill(AppTheme.border).frame(height: 1)
        }
    }
}

struct ContentBlock<Content: View>: View {
    let title: String?
    let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.headline)
            }
            content
        }
        .padding(12)
        .background(AppTheme.surfaceAlt.opacity(0.55), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct MetricRowView: View {
    let title: String
    let value: String
    var tone: PillTone = .neutral

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.callout)
                .foregroundStyle(AppTheme.muted)
            Spacer()
            Text(value)
                .font(.callout.weight(.semibold))
                .foregroundStyle(tone.color)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
    }
}

struct AuditIssueView: View {
    let issue: AuditIssue

    private var tone: PillTone {
        switch issue.severity {
        case .s0: .red
        case .s1: .orange
        case .s2: .blue
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                PillView(text: issue.severity.rawValue, tone: tone)
                Text(issue.type)
                    .font(.callout.weight(.semibold))
                Spacer()
                if let location = issue.location {
                    Text(location)
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                }
            }
            Text(issue.message)
                .font(.callout)
                .foregroundStyle(AppTheme.text)
            if let suggestion = issue.suggestion {
                Text(suggestion)
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .padding(10)
        .background(tone.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tone.color.opacity(0.2), lineWidth: 1)
        )
    }
}

struct TopBarView<Trailing: View>: View {
    let kicker: String
    let title: String
    let trailing: Trailing

    init(kicker: String, title: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.kicker = kicker
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 16) {
                titleBlock
                Spacer(minLength: 16)
                trailing
            }

            VStack(alignment: .leading, spacing: 12) {
                titleBlock
                trailing
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(kicker)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(AppTheme.blue)
            Text(title)
                .font(.largeTitle.weight(.bold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct EmptyStateView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(AppTheme.muted)
            .frame(maxWidth: .infinity, minHeight: 120)
            .padding()
            .background(AppTheme.surfaceAlt.opacity(0.45), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct EntityChip: View {
    let text: String
    var tone: PillTone = .neutral

    var body: some View {
        Text(text)
            .font(.callout.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tone.color.opacity(0.1), in: Capsule())
            .overlay(Capsule().stroke(tone.color.opacity(0.25), lineWidth: 1))
            .foregroundStyle(tone.color)
    }
}

struct FlowLayout<Content: View>: View {
    let alignment: HorizontalAlignment
    let spacing: CGFloat
    let content: Content

    init(alignment: HorizontalAlignment = .leading, spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: spacing, alignment: .leading)], alignment: alignment, spacing: spacing) {
            content
        }
    }
}
