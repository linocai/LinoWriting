import NovelOSMacCore
import SwiftUI

private let macOSWindowControlsClearance: CGFloat = 44

struct RootShellView: View {
    @Environment(AppStore.self) private var appStore

    var body: some View {
        @Bindable var appStore = appStore

        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 240, ideal: 260, max: 300)
        } detail: {
            GeometryReader { proxy in
                let shouldShowInspector = proxy.size.width >= 1100 && appStore.isInspectorVisible

                ZStack {
                    AppBackgroundView()

                    HStack(spacing: 0) {
                        MainWorkspaceView()
                            .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)

                        if shouldShowInspector {
                            Divider()
                                .overlay(AppTheme.line)
                            InspectorView()
                                .frame(width: 340)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                }
            }
        }
    }
}

struct SidebarView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(ChapterWorkflowStore.self) private var chapterStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            novelCard

            SidebarSection(title: "Workspace", items: Workspace.allCases.filter { $0.section == .workspace })
            SidebarSection(title: "Library", items: Workspace.allCases.filter { $0.section == .library })

            Spacer(minLength: 18)
            SidebarFooter()
        }
        .padding(.horizontal, 14)
        .padding(.top, macOSWindowControlsClearance)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.regularMaterial)
        .background(AppTheme.sidebarBase.opacity(0.82))
    }

    private var novelCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Novel")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.muted)
            Text(chapterStore.novel.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.text)
            HStack(spacing: 6) {
                Text("第 \(chapterStore.chapter.chapterNo) 章")
                Text("·")
                Text("Canon v\(chapterStore.novel.currentCanonVersion ?? 0)")
            }
            .font(.callout)
            .foregroundStyle(AppTheme.muted)
            HStack {
                PillView(text: chapterStore.novel.genre ?? "未分类", tone: .blue)
                PillView(text: "已导入前三章", tone: .green)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.65), in: RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous)
                .stroke(Color.white.opacity(0.80), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 22, x: 0, y: 8)
    }
}

private struct SidebarSection: View {
    @Environment(AppStore.self) private var appStore

    let title: String
    let items: [Workspace]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.muted)
                .padding(.horizontal, 4)

            ForEach(items) { workspace in
                SidebarNavItem(
                    workspace: workspace,
                    isSelected: appStore.selectedWorkspace == workspace
                ) {
                    appStore.selectedWorkspace = workspace
                }
            }
        }
    }
}

private struct SidebarNavItem: View {
    let workspace: Workspace
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? AppTheme.blue.opacity(0.12) : Color.white.opacity(isHovered ? 0.62 : 0.34))
                    Image(systemName: workspace.systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? AppTheme.blue : AppTheme.muted)
                }
                .frame(width: 28, height: 28)

                Text(workspace.title)
                    .font(.callout.weight(isSelected ? .bold : .medium))
                    .foregroundStyle(AppTheme.text)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Color.white.opacity(isSelected ? 0.90 : (isHovered ? 0.58 : 0)),
                in: RoundedRectangle(cornerRadius: AppTheme.radiusMD, style: .continuous)
            )
            .overlay(alignment: .leading) {
                if isSelected {
                    Capsule()
                        .fill(AppTheme.blue)
                        .frame(width: 3, height: 22)
                        .padding(.leading, 1)
                }
            }
            .shadow(color: isSelected ? Color.black.opacity(0.06) : .clear, radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

private struct SidebarFooter: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("后台默认运行")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.muted)
            VStack(alignment: .leading, spacing: 6) {
                footerLine("Context Compiler")
                footerLine("Knowledge Guard")
                footerLine("Named Entity Linter")
            }
            Text("你只需要完成五个用户动作。")
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.48), in: RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
    }

    private func footerLine(_ text: String) -> some View {
        HStack(spacing: 7) {
            Circle()
                .fill(AppTheme.green)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.text)
        }
    }
}

struct MainWorkspaceView: View {
    @Environment(AppStore.self) private var appStore

    var body: some View {
        Group {
            switch appStore.selectedWorkspace {
            case .chapterStudio:
                ChapterStudioView()
            case .baseFiles:
                BaseFilesView()
            case .knowledgeMatrix:
                KnowledgeMatrixView()
            case .versionsDebug:
                VersionsDebugView()
            case .chaptersList:
                ChaptersListView()
            case .writingSettings:
                WritingSettingsView()
            }
        }
    }
}

struct InspectorView: View {
    @Environment(ChapterWorkflowStore.self) private var chapterStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                InspectorSection(title: "本章安全边界") {
                    HStack {
                        Text("状态")
                            .foregroundStyle(AppTheme.muted)
                        Spacer()
                        PillView(text: "已就绪", tone: .green)
                    }
                    .font(.callout)
                    MetricRowView(title: "Active Cast", value: chapterStore.safetySummary.activeCast.joined(separator: ", "), tone: .green)
                    MetricRowView(title: "Allowed Names", value: "\(chapterStore.safetySummary.allowedNamesCount)", tone: .blue)
                    MetricRowView(title: "Mention Budget", value: "\(chapterStore.safetySummary.mentionBudgetTotal)", tone: .orange)
                    MetricRowView(title: "新增命名角色", value: "禁止", tone: .red)
                }

                InspectorSection(title: "后台运行状态") {
                    PillView(text: "不可见流程", tone: .blue)
                    InspectorStatusCard(title: "Context Compiler", text: "已隐藏非本章人物和无关世界信息。")
                    InspectorStatusCard(title: "Knowledge Guard", text: "A 不能直接知道旧案完整真相。")
                    InspectorStatusCard(title: "Named Entity Linter", text: "正文生成后自动检查非法专名。")
                }

                InspectorSection(title: "用户只需关心") {
                    ForEach(ChapterStep.allCases) { step in
                        InspectorStepRow(step: step)
                    }
                }

                InspectorSection(title: "macOS 交互建议") {
                    Text("主窗口采用三栏结构：左侧项目导航，中间工作区，右侧上下文状态。右侧只做提示和安全感，不承载必须操作。")
                        .font(.callout)
                        .foregroundStyle(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(.regularMaterial)
        .background(AppTheme.sidebarBase.opacity(0.78))
    }
}

private struct InspectorSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.text)
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.64), in: RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous)
                .stroke(Color.white.opacity(0.86), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 14, x: 0, y: 8)
    }
}

private struct InspectorStatusCard: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.callout.weight(.bold))
                .foregroundStyle(AppTheme.text)
            Text(text)
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: AppTheme.radiusMD, style: .continuous))
    }
}

private struct InspectorStepRow: View {
    let step: ChapterStep

    var body: some View {
        HStack(spacing: 10) {
            Text("\(step.rawValue)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(AppTheme.blue, in: Circle())
            Text(step.title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(AppTheme.text)
            Spacer()
        }
    }
}
