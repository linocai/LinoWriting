import NovelOSMacCore
import SwiftUI

struct TonePalette {
    let foreground: Color
    let background: Color
    let border: Color
}

enum PillTone: Equatable {
    case blue
    case green
    case orange
    case red
    case purple
    case dark
    case neutral

    var color: Color { palette.foreground }

    var palette: TonePalette {
        switch self {
        case .blue:
            TonePalette(foreground: Color(red: 0.02, green: 0.35, blue: 0.74), background: AppTheme.blue.opacity(0.12), border: AppTheme.blue.opacity(0.24))
        case .green:
            TonePalette(foreground: Color(red: 0.08, green: 0.39, blue: 0.20), background: AppTheme.green.opacity(0.13), border: AppTheme.green.opacity(0.26))
        case .orange:
            TonePalette(foreground: Color(red: 0.58, green: 0.28, blue: 0.00), background: AppTheme.orange.opacity(0.13), border: AppTheme.orange.opacity(0.26))
        case .red:
            TonePalette(foreground: Color(red: 0.64, green: 0.05, blue: 0.09), background: AppTheme.red.opacity(0.12), border: AppTheme.red.opacity(0.25))
        case .purple:
            TonePalette(foreground: Color(red: 0.35, green: 0.19, blue: 0.69), background: AppTheme.purple.opacity(0.12), border: AppTheme.purple.opacity(0.24))
        case .dark:
            TonePalette(foreground: Color.white, background: AppTheme.dark, border: AppTheme.dark.opacity(0.18))
        case .neutral:
            TonePalette(foreground: AppTheme.muted, background: Color.black.opacity(0.05), border: AppTheme.line)
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
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .foregroundStyle(tone.palette.foreground)
            .background(tone.palette.background, in: Capsule())
            .overlay(Capsule().stroke(tone.palette.border, lineWidth: 1))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(isEnabled ? Color.white : AppTheme.muted2)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(isEnabled ? AppTheme.dark : AppTheme.panelSubtle, in: RoundedRectangle(cornerRadius: AppTheme.radiusSM, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(AppTheme.Motion.easeOut, value: configuration.isPressed)
    }
}

struct BlueButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(isEnabled ? Color.white : AppTheme.muted2)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(isEnabled ? AppTheme.blue : AppTheme.panelSubtle, in: RoundedRectangle(cornerRadius: AppTheme.radiusSM, style: .continuous))
            .shadow(color: isEnabled ? AppTheme.blue.opacity(0.18) : .clear, radius: 8, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(AppTheme.Motion.easeOut, value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(isEnabled ? AppTheme.muted : AppTheme.muted2)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(configuration.isPressed ? 0.72 : 0.42), in: RoundedRectangle(cornerRadius: AppTheme.radiusSM, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusSM, style: .continuous)
                    .stroke(Color.white.opacity(0.82), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(AppTheme.Motion.easeOut, value: configuration.isPressed)
    }
}

struct DangerButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(isEnabled ? AppTheme.red : AppTheme.muted2)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppTheme.red.opacity(isEnabled ? 0.10 : 0.04), in: RoundedRectangle(cornerRadius: AppTheme.radiusSM, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusSM, style: .continuous)
                    .stroke(AppTheme.red.opacity(isEnabled ? 0.18 : 0.06), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(AppTheme.Motion.easeOut, value: configuration.isPressed)
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
        .glassPanel(radius: AppTheme.radiusXL)
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
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.title3.weight(.bold))
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
        .padding(.top, 16)
        .padding(.horizontal, AppTheme.cardPadding)
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.line).frame(height: 1)
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
        .padding(AppTheme.cardPadding)
    }
}

struct CardFooter<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                Spacer(minLength: 12)
                content
            }

            VStack(alignment: .trailing, spacing: 8) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, AppTheme.cardPadding)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.46))
        .overlay(alignment: .top) {
            Rectangle().fill(AppTheme.line).frame(height: 1)
        }
    }
}

struct ContentBlock<Content: View>: View {
    let title: String?
    let tone: PillTone
    let content: Content

    init(_ title: String? = nil, tone: PillTone = .neutral, @ViewBuilder content: () -> Content) {
        self.title = title
        self.tone = tone
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
            }
            content
        }
        .padding(14)
        .background(tone == .neutral ? AppTheme.panelSubtle : tone.palette.background, in: RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous)
                .stroke(tone == .neutral ? AppTheme.line : tone.palette.border, lineWidth: 1)
        )
    }
}

struct SideNoteView: View {
    let title: String
    let text: String
    var tone: PillTone = .neutral

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.text)
            Text(text)
                .font(.callout)
                .foregroundStyle(AppTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tone == .neutral ? AppTheme.panelSubtle : tone.palette.background, in: RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous)
                .stroke(tone == .neutral ? AppTheme.line : tone.palette.border, lineWidth: 1)
        )
    }
}

struct PromptCard<Content: View>: View {
    let title: String
    var badge: String?
    var tone: PillTone = .neutral
    let content: Content

    init(title: String, badge: String? = nil, tone: PillTone = .neutral, @ViewBuilder content: () -> Content) {
        self.title = title
        self.badge = badge
        self.tone = tone
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                if let badge {
                    PillView(text: badge, tone: tone)
                }
                Spacer(minLength: 8)
            }
            content
        }
        .padding(14)
        .background(Color.white.opacity(0.62), in: RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous)
                .stroke(Color.white.opacity(0.82), lineWidth: 1)
        )
    }
}

struct TemplateCard<Content: View, HeaderAction: View>: View {
    let title: String
    var badge: String?
    var tone: PillTone
    let headerAction: HeaderAction
    let content: Content

    init(
        title: String,
        badge: String? = nil,
        tone: PillTone = .neutral,
        @ViewBuilder headerAction: () -> HeaderAction = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.badge = badge
        self.tone = tone
        self.headerAction = headerAction()
        self.content = content()
    }

    init(
        title: String,
        badge: String? = nil,
        tone: PillTone = .neutral,
        @ViewBuilder content: () -> Content
    ) where HeaderAction == EmptyView {
        self.title = title
        self.badge = badge
        self.tone = tone
        self.headerAction = EmptyView()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                if let badge {
                    PillView(text: badge, tone: tone)
                }
                Spacer(minLength: 8)
                headerAction
            }
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.64), in: RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous)
                .stroke(tone == .neutral ? Color.white.opacity(0.84) : tone.palette.border, lineWidth: 1)
        )
    }
}

struct StatusBanner: View {
    let message: String
    var tone: PillTone = .blue

    var body: some View {
        Text(message)
            .font(.callout.weight(.semibold))
            .foregroundStyle(tone.palette.foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tone.palette.background, in: RoundedRectangle(cornerRadius: AppTheme.radiusMD, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMD, style: .continuous)
                    .stroke(tone.palette.border, lineWidth: 1)
            )
    }
}

struct SoftTextEditor: View {
    @Binding var text: String
    var placeholder: String = ""
    var minHeight: CGFloat
    var idealHeight: CGFloat?
    var maxHeight: CGFloat?
    var font: Font = .body
    var lineSpacing: CGFloat = 0

    @FocusState private var isFocused: Bool

    init(
        text: Binding<String>,
        placeholder: String = "",
        minHeight: CGFloat = 120,
        idealHeight: CGFloat? = nil,
        maxHeight: CGFloat? = nil,
        font: Font = .body,
        lineSpacing: CGFloat = 0
    ) {
        _text = text
        self.placeholder = placeholder
        self.minHeight = minHeight
        self.idealHeight = idealHeight
        self.maxHeight = maxHeight
        self.font = font
        self.lineSpacing = lineSpacing
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(font)
                .lineSpacing(lineSpacing)
                .scrollContentBackground(.hidden)
                .focused($isFocused)
                .frame(minHeight: minHeight, idealHeight: idealHeight, maxHeight: maxHeight)

            if text.isEmpty, !placeholder.isEmpty {
                Text(placeholder)
                    .font(font)
                    .foregroundStyle(AppTheme.muted2)
                    .padding(.top, 8)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }
        }
        .padding(8)
        .background(AppTheme.editor, in: RoundedRectangle(cornerRadius: AppTheme.radiusMD, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMD, style: .continuous)
                .stroke(AppTheme.lineStrong, lineWidth: 1)
        )
        .focusRing(active: isFocused)
    }
}

struct SoftTextField: View {
    let title: String
    @Binding var text: String
    var axis: Axis = .horizontal

    @FocusState private var isFocused: Bool

    init(_ title: String, text: Binding<String>, axis: Axis = .horizontal) {
        self.title = title
        _text = text
        self.axis = axis
    }

    init(title: String, text: Binding<String>, axis: Axis = .horizontal) {
        self.title = title
        _text = text
        self.axis = axis
    }

    var body: some View {
        TextField(title, text: $text, axis: axis)
            .textFieldStyle(.plain)
            .font(.callout)
            .focused($isFocused)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(AppTheme.editor, in: RoundedRectangle(cornerRadius: AppTheme.radiusMD, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMD, style: .continuous)
                    .stroke(AppTheme.lineStrong, lineWidth: 1)
            )
            .focusRing(active: isFocused)
    }
}

struct SoftPicker<SelectionValue: Hashable, Content: View>: View {
    let title: String
    @Binding var selection: SelectionValue
    let content: Content

    init(_ title: String, selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content) {
        self.title = title
        _selection = selection
        self.content = content()
    }

    var body: some View {
        Picker(title, selection: $selection) {
            content
        }
        .pickerStyle(.menu)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(AppTheme.editor, in: RoundedRectangle(cornerRadius: AppTheme.radiusMD, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMD, style: .continuous)
                .stroke(AppTheme.lineStrong, lineWidth: 1)
        )
    }
}

struct LabeledField<Content: View>: View {
    let label: String
    let hint: String?
    let content: Content

    init(_ label: String, hint: String? = nil, @ViewBuilder content: () -> Content) {
        self.label = label
        self.hint = hint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.text)
                Spacer(minLength: 8)
                if let hint {
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                }
            }
            content
        }
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
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                PillView(text: issue.severity.rawValue, tone: tone)
                Text(issue.type)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                Spacer(minLength: 8)
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
        .padding(12)
        .background(tone.palette.background, in: RoundedRectangle(cornerRadius: AppTheme.radiusMD, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMD, style: .continuous)
                .stroke(tone.palette.border, lineWidth: 1)
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
                .font(.system(size: 13, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(AppTheme.muted)
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .default))
                .tracking(0)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(AppTheme.text)
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
            .background(AppTheme.panelSubtle, in: RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous)
                    .stroke(AppTheme.line, lineWidth: 1)
            )
    }
}

struct EntityChip: View {
    let text: String
    var tone: PillTone = .neutral

    var body: some View {
        Text(text)
            .font(.callout.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tone.palette.background, in: Capsule())
            .overlay(Capsule().stroke(tone.palette.border, lineWidth: 1))
            .foregroundStyle(tone.palette.foreground)
    }
}

struct EntityChipGrid: View {
    let entities: [AllowedEntity]

    var body: some View {
        FlowLayout {
            ForEach(entities) { entity in
                EntityChip(text: entity.displayLabel, tone: entity.tone)
            }
        }
    }
}

extension AllowedEntity {
    var displayLabel: String {
        if let mentionBudget {
            return "\(name) · \(activation.displayName) \(mentionBudget)"
        }
        return "\(name) · \(activation.displayName)"
    }

    var tone: PillTone {
        switch activation {
        case .active: .green
        case .mentionAllowed: .orange
        case .background: .blue
        case .lockedOut: .neutral
        case .newAllowed: .purple
        }
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

struct KnowledgeStatePillPicker: View {
    @Binding var state: KnowledgeState

    var body: some View {
        Menu {
            ForEach(KnowledgeState.allCases) { option in
                Button(option.displayName) {
                    state = option
                }
            }
        } label: {
            PillView(text: state.displayName, tone: state.tone)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(.plain)
    }
}

extension KnowledgeState {
    var tone: PillTone {
        switch self {
        case .known, .stronglySuspects:
            .green
        case .suspects, .hinted, .partial, .mayKnow:
            .orange
        case .readerKnown:
            .blue
        case .authorOnly:
            .purple
        case .unknown, .readerUnknown:
            .neutral
        }
    }
}

struct TimelineItemView<Content: View, Trailing: View>: View {
    let badge: String
    let title: String
    let subtitle: String
    var tone: PillTone = .blue
    let content: Content
    let trailing: Trailing

    init(
        badge: String,
        title: String,
        subtitle: String,
        tone: PillTone = .blue,
        @ViewBuilder content: () -> Content = { EmptyView() },
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.badge = badge
        self.title = title
        self.subtitle = subtitle
        self.tone = tone
        self.content = content()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 6) {
                Circle()
                    .fill(tone.palette.foreground)
                    .frame(width: 10, height: 10)
                Rectangle()
                    .fill(tone.palette.border)
                    .frame(width: 2)
            }
            .frame(width: 18)
            .frame(minHeight: 44)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 10) {
                    PillView(text: badge, tone: tone)
                        .frame(minWidth: 92, alignment: .leading)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppTheme.text)
                        Text(subtitle)
                            .font(.callout)
                            .foregroundStyle(AppTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 10)
                    trailing
                }
                content
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.58), in: RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous)
                .stroke(Color.white.opacity(0.82), lineWidth: 1)
        )
    }
}
