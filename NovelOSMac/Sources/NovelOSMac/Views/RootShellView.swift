import NovelOSMacCore
import SwiftUI

struct RootShellView: View {
    @Environment(AppStore.self) private var appStore

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 300)
        } detail: {
            HStack(spacing: 0) {
                MainWorkspaceView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if appStore.isInspectorVisible {
                    Divider()
                    InspectorView()
                        .frame(width: 340)
                }
            }
            .background(AppTheme.background)
        }
    }
}

struct SidebarView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(ChapterWorkflowStore.self) private var chapterStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 7) {
                Circle().fill(Color.red.opacity(0.75)).frame(width: 12, height: 12)
                Circle().fill(Color.yellow.opacity(0.85)).frame(width: 12, height: 12)
                Circle().fill(Color.green.opacity(0.75)).frame(width: 12, height: 12)
            }
            .padding(.top, 10)

            VStack(alignment: .leading, spacing: 8) {
                Text("Current Novel")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.muted)
                Text(chapterStore.novel.title)
                    .font(.title2.weight(.bold))
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
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border))

            SidebarSection(title: "Workspace", items: Workspace.allCases.filter { $0.section == .workspace })
            SidebarSection(title: "Library", items: Workspace.allCases.filter { $0.section == .library })

            Spacer()

            Text("设计约束：\n用户只做 5 个动作。Context Pack、Audit、Agent Run 只作为后台能力和调试信息，不进入主流程强制审核。")
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .background(AppTheme.surfaceAlt.opacity(0.5), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(14)
        .background(AppTheme.sidebar)
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
                Button {
                    appStore.selectedWorkspace = workspace
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: workspace.systemImage)
                            .frame(width: 18)
                        Text(workspace.title)
                            .font(.callout.weight(.medium))
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .foregroundStyle(appStore.selectedWorkspace == workspace ? Color.white : AppTheme.text)
                    .background(
                        appStore.selectedWorkspace == workspace
                            ? AppTheme.blue
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            }
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
            VStack(alignment: .leading, spacing: 16) {
                InspectorSection(title: "本章安全边界") {
                    HStack {
                        Text("状态")
                        Spacer()
                        PillView(text: "已就绪", tone: .green)
                    }
                    MetricRowView(title: "Active Cast", value: chapterStore.safetySummary.activeCast.joined(separator: ", "), tone: .green)
                    MetricRowView(title: "Allowed Names", value: "\(chapterStore.safetySummary.allowedNamesCount)", tone: .blue)
                    MetricRowView(title: "Mention Budget", value: "\(chapterStore.safetySummary.mentionBudgetTotal)", tone: .orange)
                    MetricRowView(title: "新增命名角色", value: "禁止", tone: .red)
                }

                InspectorSection(title: "后台运行状态") {
                    PillView(text: "不可见流程", tone: .blue)
                    BackgroundStatus(title: "Context Compiler", detail: "已隐藏非本章人物和无关世界信息。")
                    BackgroundStatus(title: "Knowledge Guard", detail: "A 不能直接知道旧案完整真相。")
                    BackgroundStatus(title: "Named Entity Linter", detail: "正文生成后自动检查非法专名。")
                }

                InspectorSection(title: "用户只需关心") {
                    ForEach(ChapterStep.allCases) { step in
                        HStack(spacing: 8) {
                            Text("\(step.rawValue)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(AppTheme.blue, in: Circle())
                            Text(step.title)
                                .font(.callout)
                        }
                    }
                }

                InspectorSection(title: "macOS 交互建议") {
                    Text("主窗口采用三栏结构：左侧项目导航，中间工作区，右侧上下文状态。右侧只做提示和安全感，不承载必须操作。")
                        .font(.callout)
                        .foregroundStyle(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
        }
        .background(AppTheme.sidebar.opacity(0.65))
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
                .font(.headline)
            content
        }
        .padding(12)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border))
    }
}

private struct BackgroundStatus: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.callout.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
