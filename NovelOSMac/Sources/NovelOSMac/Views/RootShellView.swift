import NovelOSMacCore
import SwiftUI

private let macOSTitlebarInset: CGFloat = 78
private let macOSWindowControlsClearance: CGFloat = 84

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
                        .frame(width: 300)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.background)
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear.frame(height: macOSTitlebarInset)
            }
        }
    }
}

struct SidebarView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(ChapterWorkflowStore.self) private var chapterStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Color.clear
                .frame(height: macOSWindowControlsClearance)

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
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
                InspectorSection(title: "本章边界") {
                    HStack {
                        Text("状态")
                        Spacer()
                        PillView(text: "已就绪", tone: .green)
                    }
                    MetricRowView(title: "本章出场", value: chapterStore.safetySummary.activeCast.joined(separator: ", "), tone: .green)
                    MetricRowView(title: "可用专名数", value: "\(chapterStore.safetySummary.allowedNamesCount)", tone: .blue)
                    MetricRowView(title: "弱提及额度", value: "\(chapterStore.safetySummary.mentionBudgetTotal)", tone: .orange)
                    MetricRowView(title: "新增命名角色", value: "禁止", tone: .red)
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
