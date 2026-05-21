import NovelOSMacCore
import SwiftUI

private let macOSWindowControlsClearance: CGFloat = 44

struct RootShellView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(NovelLibraryStore.self) private var novelLibraryStore
    @Environment(ChapterWorkflowStore.self) private var chapterStore
    @Environment(BaseDocumentsStore.self) private var baseDocumentsStore
    @Environment(KnowledgeMatrixStore.self) private var knowledgeStore

    var body: some View {
        @Bindable var appStore = appStore

        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 248, ideal: 264, max: 300)
        } detail: {
            GeometryReader { proxy in
                let shouldShowInspector = proxy.size.width >= 1100 && appStore.isInspectorVisible

                ZStack {
                    AppBackgroundView()

                    HStack(spacing: 0) {
                        MainWorkspaceView()
                            .frame(minWidth: 0, maxWidth: .infinity, maxHeight: proxy.size.height, alignment: .topLeading)

                        if shouldShowInspector {
                            Divider()
                                .overlay(AppTheme.line)
                            InspectorView()
                                .frame(width: 348, height: proxy.size.height, alignment: .top)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                    .clipped()
                    .animation(AppTheme.Motion.viewSwitch, value: appStore.selectedWorkspace)
                    .animation(AppTheme.Motion.viewSwitch, value: shouldShowInspector)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .task {
            await novelLibraryStore.loadIfNeeded(
                appStore: appStore,
                chapterStore: chapterStore,
                baseDocumentsStore: baseDocumentsStore,
                knowledgeStore: knowledgeStore
            )
        }
        .onChange(of: appStore.selectedWorkspace) { _, newValue in
            if newValue == .chapterStudio {
                Task { await chapterStore.refreshActiveChapterArtifacts() }
            }
        }
        .onChange(of: appStore.selectedChapterID) { _, newValue in
            guard let newValue, newValue != chapterStore.chapter.id else { return }
            Task { await chapterStore.switchActiveChapter(toID: newValue) }
        }
        .overlay(alignment: .topTrailing) {
            ToasterOverlay()
        }
    }
}

struct SidebarView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(NovelLibraryStore.self) private var novelLibraryStore
    @Environment(ChapterWorkflowStore.self) private var chapterStore
    @Environment(BaseDocumentsStore.self) private var baseDocumentsStore
    @Environment(KnowledgeMatrixStore.self) private var knowledgeStore

    var body: some View {
        @Bindable var novelLibraryStore = novelLibraryStore

        VStack(alignment: .leading, spacing: 18) {
            novelCard

            SidebarSection(title: "Workspace", items: Workspace.allCases.filter { $0.section == .workspace })
            SidebarSection(title: "Library", items: Workspace.allCases.filter { $0.section == .library })

            Spacer(minLength: 18)

            SidebarFooterView()
        }
        .padding(.horizontal, 14)
        .padding(.top, macOSWindowControlsClearance)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.regularMaterial)
        .background(Color.white.opacity(0.86))
        .sheet(isPresented: $novelLibraryStore.isShowingNewNovelSheet) {
            NewNovelSheet()
                .environment(appStore)
                .environment(novelLibraryStore)
                .environment(chapterStore)
                .environment(baseDocumentsStore)
                .environment(knowledgeStore)
        }
    }

    private var novelCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Current Novel")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.muted)
                    Text(chapterStore.novel.title)
                        .font(.title2.weight(.bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                        .foregroundStyle(AppTheme.text)
                }

                Spacer(minLength: 8)

                novelMenu

                Button {
                    novelLibraryStore.isShowingNewNovelSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.blue)
                .background(AppTheme.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .help("新建书")
            }

            HStack(spacing: 6) {
                if chapterStore.isBootstrapReady {
                    Text("第 \(chapterStore.chapter.chapterNo) 章")
                    Text("·")
                    Text("Canon v\(chapterStore.novel.currentCanonVersion ?? 0)")
                } else {
                    Text("等待导入前三章")
                }
            }
            .font(.callout)
            .foregroundStyle(AppTheme.muted)
            HStack {
                PillView(text: chapterStore.novel.genre ?? "未分类", tone: .blue)
                PillView(text: chapterStore.novel.bootstrapStatus.displayName, tone: bootstrapTone)
                Spacer(minLength: 8)
                Text("\(novelLibraryStore.novels.count) 本")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.muted)
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

    private var novelMenu: some View {
        Menu {
            ForEach(novelLibraryStore.sortedNovels) { novel in
                Button {
                    Task {
                        await novelLibraryStore.selectNovel(
                            novel,
                            appStore: appStore,
                            chapterStore: chapterStore,
                            baseDocumentsStore: baseDocumentsStore,
                            knowledgeStore: knowledgeStore
                        )
                    }
                } label: {
                    Label(
                        novel.title,
                        systemImage: novel.id == chapterStore.novel.id ? "checkmark.circle.fill" : "book.closed"
                    )
                }
            }

            Divider()

            Button {
                novelLibraryStore.isShowingNewNovelSheet = true
            } label: {
                Label("新建书", systemImage: "plus")
            }
        } label: {
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 12, weight: .bold))
                .frame(width: 28, height: 28)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .foregroundStyle(AppTheme.muted)
        .background(Color.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .help("切换书")
    }

    private var bootstrapTone: PillTone {
        switch chapterStore.novel.bootstrapStatus {
        case .completed, .analyzed, .imported:
            .green
        case .importing, .analyzing:
            .orange
        case .failed:
            .red
        case .notStarted:
            .neutral
        }
    }
}

private struct SidebarFooterView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.blue)
                Text("后台守护")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.text)
            }
            Text("Context Compiler、Knowledge Guard、Named Entity Linter 默认后台运行。你只需要完成五个用户动作。")
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.60), in: RoundedRectangle(cornerRadius: AppTheme.radiusMD, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMD, style: .continuous)
                .stroke(Color.white.opacity(0.84), lineWidth: 1)
        )
    }
}

private struct NewNovelSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var appStore
    @Environment(NovelLibraryStore.self) private var novelLibraryStore
    @Environment(ChapterWorkflowStore.self) private var chapterStore
    @Environment(BaseDocumentsStore.self) private var baseDocumentsStore
    @Environment(KnowledgeMatrixStore.self) private var knowledgeStore

    var body: some View {
        @Bindable var novelLibraryStore = novelLibraryStore

        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("新建书")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                Text("创建后会自动生成第 1 章草稿入口，你可以再导入前三章或继续配置基础文件。")
                    .font(.callout)
                    .foregroundStyle(AppTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                LabeledField("书名") {
                    SoftTextField("例如：长夜回声", text: $novelLibraryStore.newNovelTitle)
                }

                LabeledField("类型") {
                    SoftTextField("例如：悬疑、现实向、奇幻", text: $novelLibraryStore.newNovelGenre)
                }
            }

            if let message = novelLibraryStore.statusMessage {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(novelLibraryStore.error == nil ? AppTheme.muted : AppTheme.red)
            }

            HStack(spacing: 10) {
                Spacer()
                Button("取消") {
                    novelLibraryStore.isShowingNewNovelSheet = false
                    dismiss()
                }
                .buttonStyle(GhostButtonStyle())

                Button {
                    Task {
                        await novelLibraryStore.createNovelAndSelect(
                            appStore: appStore,
                            chapterStore: chapterStore,
                            baseDocumentsStore: baseDocumentsStore,
                            knowledgeStore: knowledgeStore
                        )
                        if !novelLibraryStore.isShowingNewNovelSheet {
                            dismiss()
                        }
                    }
                } label: {
                    if novelLibraryStore.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("创建并切换")
                    }
                }
                .buttonStyle(BlueButtonStyle())
                .disabled(novelLibraryStore.newNovelTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || novelLibraryStore.isLoading)
            }
        }
        .padding(22)
        .frame(width: 420)
        .background(AppBackgroundView())
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
                        .fill(isSelected ? AppTheme.blue.opacity(0.10) : Color.white.opacity(isHovered ? 0.62 : 0.34))
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
                Color.white.opacity(isSelected ? 0.94 : (isHovered ? 0.58 : 0)),
                in: RoundedRectangle(cornerRadius: AppTheme.radiusMD, style: .continuous)
            )
            .shadow(color: isSelected ? Color.black.opacity(0.06) : .clear, radius: 12, x: 0, y: 6)
            .animation(AppTheme.Motion.easeOut, value: isSelected)
            .animation(AppTheme.Motion.easeOut, value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
        .id(appStore.selectedWorkspace)
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(AppTheme.Motion.viewSwitch, value: appStore.selectedWorkspace)
    }
}

struct InspectorView: View {
    @Environment(ChapterWorkflowStore.self) private var chapterStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                safetySection
                agentStatusSection
                userActionsSection
                auditPreviewSection
                macInteractionSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .scrollIndicators(.visible)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.regularMaterial)
        .background(AppTheme.sidebarBase.opacity(0.78))
    }

    private var safetySection: some View {
        InspectorSection(title: "本章安全边界", trailing: AnyView(PillView(text: "已就绪", tone: .green))) {
            MetricRowView(title: "本章出场", value: chapterStore.safetySummary.activeCast.joined(separator: ", "), tone: .green)
            MetricRowView(title: "可用专名数", value: "\(chapterStore.safetySummary.allowedNamesCount)", tone: .blue)
            MetricRowView(title: "弱提及额度", value: "\(chapterStore.safetySummary.mentionBudgetTotal)", tone: .orange)
            MetricRowView(title: "新增命名角色", value: chapterStore.safetySummary.newNamedCharacterPolicy, tone: .red)
        }
    }

    private var agentStatusSection: some View {
        InspectorSection(title: "后台运行状态") {
            VStack(alignment: .leading, spacing: 8) {
                AgentStatusRow(name: "Writing Agent", status: draftStatusLabel, tone: draftStatusTone)
                if chapterStore.isDraftStreaming {
                    MetricRowView(title: "实时字数", value: "\(chapterStore.streamedWordCount)", tone: .blue)
                } else if chapterStore.visibleDraftWordCount > 0 {
                    MetricRowView(title: "当前正文", value: "\(chapterStore.visibleDraftWordCount) 字", tone: .blue)
                }
                AgentStatusRow(name: "Context Compiler", status: promptPipelineStatusLabel, tone: promptPipelineStatusTone)
                AgentStatusRow(name: "Prompt Expander", status: promptPipelineStatusLabel, tone: promptPipelineStatusTone)
                AgentStatusRow(name: "Named Entity Auditor", status: auditStatusLabel, tone: auditStatusTone)
                AgentStatusRow(name: "Knowledge Auditor", status: auditStatusLabel, tone: auditStatusTone)
                AgentStatusRow(name: "Continuity Auditor", status: auditStatusLabel, tone: auditStatusTone)
            }
        }
    }

    private var userActionsSection: some View {
        InspectorSection(title: "你只需要关心") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(ChapterStep.allCases) { step in
                    StepProgressRow(
                        step: step,
                        isCurrent: step == chapterStore.currentStep,
                        isUnlocked: chapterStore.canMove(to: step),
                        isDone: step.rawValue < chapterStore.currentStep.rawValue || step.rawValue < chapterStore.highestUnlockedStep.rawValue
                    )
                }
            }
        }
    }

    private var auditPreviewSection: some View {
        InspectorSection(title: "本章 Audit 预览") {
            if let summary = chapterStore.auditSummary {
                HStack(spacing: 8) {
                    PillView(text: "S0 \(summary.s0Count)", tone: summary.s0Count == 0 ? .green : .red)
                    PillView(text: "S1 \(summary.s1Count)", tone: summary.s1Count == 0 ? .green : .orange)
                    PillView(text: "S2 \(summary.s2Count)", tone: summary.s2Count == 0 ? .green : .blue)
                }
                MetricRowView(title: "非法专名", value: "\(summary.illegalNamedEntityCount)", tone: summary.illegalNamedEntityCount == 0 ? .green : .red)
                MetricRowView(title: "知识越界", value: "\(summary.knowledgeViolationCount)", tone: summary.knowledgeViolationCount == 0 ? .green : .red)
            } else {
                Text("正文生成后会显示本章 S0 / S1 / S2 预览。")
                    .font(.callout)
                    .foregroundStyle(AppTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var macInteractionSection: some View {
        InspectorSection(title: "macOS 交互") {
            VStack(alignment: .leading, spacing: 8) {
                ShortcutRow(title: "继续 / 确认", keys: ["⌘", "↩"])
                ShortcutRow(title: "保存当前页", keys: ["⌘", "S"])
                ShortcutRow(title: "切换 Inspector", keys: ["⌘", "⇧", "I"])
                ShortcutRow(title: "切换工作区", keys: ["⌘", "1-4"])
            }
        }
    }

    private var draftStatusLabel: String {
        if chapterStore.isDraftStreaming { return "流式生成中 · \(chapterStore.streamedWordCount) 字" }
        if chapterStore.isLoading { return "运行中" }
        return chapterStore.draft == nil ? "待运行" : "完成"
    }

    private var draftStatusTone: PillTone {
        if chapterStore.isDraftStreaming { return .blue }
        if chapterStore.isLoading { return .blue }
        return chapterStore.draft == nil ? .neutral : .green
    }

    private var auditStatusLabel: String {
        chapterStore.auditSummary == nil ? "待运行" : "完成"
    }

    private var auditStatusTone: PillTone {
        chapterStore.auditSummary == nil ? .neutral : .green
    }

    private var promptPipelineStatusLabel: String {
        if chapterStore.structuredPrompt != nil || chapterStore.currentStep.rawValue >= ChapterStep.structuredPromptReview.rawValue {
            return "完成"
        }
        return "待运行"
    }

    private var promptPipelineStatusTone: PillTone {
        promptPipelineStatusLabel == "完成" ? .green : .neutral
    }
}

private struct InspectorSection<Content: View>: View {
    let title: String
    let trailing: AnyView?
    let content: Content

    init(title: String, trailing: AnyView? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.trailing = trailing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                Spacer(minLength: 8)
                if let trailing {
                    trailing
                }
            }
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

private struct AgentStatusRow: View {
    let name: String
    let status: String
    let tone: PillTone

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(tone.palette.foreground)
                .frame(width: 7, height: 7)
            Text(name)
                .font(.callout)
                .foregroundStyle(AppTheme.text)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(status)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tone.palette.foreground)
        }
    }
}

private struct StepProgressRow: View {
    let step: ChapterStep
    let isCurrent: Bool
    let isUnlocked: Bool
    let isDone: Bool

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(badgeTone.palette.background)
                Image(systemName: isDone ? "checkmark" : "\(step.rawValue).circle.fill")
                    .font(.system(size: isDone ? 10 : 12, weight: .bold))
                    .foregroundStyle(badgeTone.palette.foreground)
            }
            .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                    .lineLimit(1)
                Text(statusLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(badgeTone.palette.foreground)
            }
            Spacer(minLength: 4)
        }
        .padding(8)
        .background(isCurrent ? AppTheme.blue.opacity(0.10) : Color.white.opacity(0.42), in: RoundedRectangle(cornerRadius: AppTheme.radiusSM, style: .continuous))
    }

    private var badgeTone: PillTone {
        if isCurrent { return .blue }
        if isDone { return .green }
        return isUnlocked ? .orange : .neutral
    }

    private var statusLabel: String {
        if isCurrent { return "当前" }
        if isDone { return "完成" }
        return isUnlocked ? "可进入" : "未就绪"
    }
}

private struct ShortcutRow: View {
    let title: String
    let keys: [String]

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.callout)
                .foregroundStyle(AppTheme.muted)
            Spacer()
            HStack(spacing: 4) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.text)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(AppTheme.line, lineWidth: 1)
                        )
                }
            }
        }
    }
}

struct ToasterOverlay: View {
    @Environment(AppStore.self) private var appStore
    @Environment(NovelLibraryStore.self) private var novelLibraryStore
    @Environment(ChapterWorkflowStore.self) private var chapterStore
    @Environment(BaseDocumentsStore.self) private var baseDocumentsStore
    @Environment(KnowledgeMatrixStore.self) private var knowledgeStore

    var body: some View {
        @Bindable var appStore = appStore

        Group {
            if let toast = appStore.toast {
                ToastBubble(toast: toast) {
                    appStore.toast = nil
                }
                .id(toast.id)
                .padding(.top, 56)
                .padding(.trailing, 24)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: toast.id) {
                    try? await Task.sleep(nanoseconds: 3_500_000_000)
                    if appStore.toast?.id == toast.id {
                        appStore.toast = nil
                    }
                }
            } else {
                EmptyView()
            }
        }
        .animation(AppTheme.Motion.easeOut, value: appStore.toast?.id)
        .onChange(of: novelLibraryStore.error) { _, newValue in
            forward(newValue)
        }
        .onChange(of: chapterStore.error) { _, newValue in
            forward(newValue)
        }
        .onChange(of: baseDocumentsStore.error) { _, newValue in
            forward(newValue)
        }
        .onChange(of: knowledgeStore.error) { _, newValue in
            forward(newValue)
        }
    }

    private func forward(_ error: APIError?) {
        guard let error else { return }
        appStore.toast = ToastState(
            id: UUID().uuidString,
            message: error.userMessage,
            kind: .error
        )
    }
}

private struct ToastBubble: View {
    let toast: ToastState
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(accent))
            Text(toast.message)
                .font(.callout)
                .foregroundStyle(AppTheme.text)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 360, alignment: .leading)
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.muted)
                    .padding(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.96), in: RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous)
                .stroke(accent.opacity(0.32), lineWidth: 1)
        )
        .shadow(color: accent.opacity(0.22), radius: 18, x: 0, y: 12)
        .frame(maxWidth: 460, alignment: .topTrailing)
    }

    private var accent: Color {
        switch toast.kind {
        case .success: AppTheme.green
        case .warning: AppTheme.orange
        case .error: AppTheme.red
        case .info: AppTheme.blue
        }
    }

    private var iconName: String {
        switch toast.kind {
        case .success: "checkmark"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        case .info: "info.circle.fill"
        }
    }
}
