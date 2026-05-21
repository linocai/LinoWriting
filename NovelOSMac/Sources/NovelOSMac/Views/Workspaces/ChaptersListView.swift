import NovelOSMacCore
import SwiftUI

struct ChaptersListView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(NovelLibraryStore.self) private var novelLibraryStore
    @Environment(ChapterWorkflowStore.self) private var chapterStore
    @Environment(BaseDocumentsStore.self) private var baseDocumentsStore
    @Environment(KnowledgeMatrixStore.self) private var knowledgeStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                TopBarView(kicker: "章节列表", title: chapterStore.isBootstrapReady ? "查看已导入和已生成的正文" : "先导入前三章") {
                    if chapterStore.isBootstrapReady {
                        Button {
                            appStore.selectedWorkspace = .chapterStudio
                        } label: {
                            Label("继续写当前章", systemImage: "square.and.pencil")
                        }
                        .buttonStyle(BlueButtonStyle())
                    }
                }

                if chapterStore.isBootstrapReady {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 16) {
                            chapterListCard
                                .frame(minWidth: 340, idealWidth: 420, maxWidth: 460)
                            chapterReaderCard
                                .frame(maxWidth: .infinity)
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            chapterListCard
                            chapterReaderCard
                        }
                    }
                } else {
                    BootstrapImportPanel()
                        .environment(appStore)
                        .environment(novelLibraryStore)
                        .environment(chapterStore)
                        .environment(baseDocumentsStore)
                        .environment(knowledgeStore)
                }
            }
            .padding(AppTheme.pagePadding)
        }
        .scrollIndicators(.visible)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppBackgroundView())
        .task {
            await chapterStore.loadIfNeeded()
        }
    }

    private var sortedChapters: [Chapter] {
        chapterStore.chapters.sorted { $0.chapterNo < $1.chapterNo }
    }

    private var selectedChapter: Chapter? {
        guard let selectedID = chapterStore.selectedReadableChapterID else {
            return sortedChapters.first
        }
        return sortedChapters.first { $0.id == selectedID } ?? sortedChapters.first
    }

    private var chapterListCard: some View {
        CardView {
            CardHeader(title: "章节", subtitle: "导入的前三章和后续生成章节都可以在这里打开。")
            CardBody {
                if sortedChapters.isEmpty {
                    EmptyStateView(text: "还没有章节。")
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(sortedChapters) { chapter in
                            Button {
                                chapterStore.selectedReadableChapterID = chapter.id
                            } label: {
                                ChapterTimelineRow(
                                    chapter: "第 \(chapter.chapterNo) 章",
                                    title: chapter.title ?? "未命名章节",
                                    subtitle: subtitle(for: chapter),
                                    wordCount: wordCountLabel(for: chapter),
                                    canon: canonLabel(for: chapter),
                                    pill: pillLabel(for: chapter),
                                    tone: tone(for: chapter),
                                    isSelected: selectedChapter?.id == chapter.id
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var chapterReaderCard: some View {
        CardView {
            if let chapter = selectedChapter {
                let draft = chapterStore.chapterDrafts[chapter.id]
                CardHeader(title: readerTitle(for: chapter), subtitle: readerSubtitle(for: chapter, draft: draft)) {
                    Button {
                        let targetID = chapter.id
                        if targetID == chapterStore.chapter.id {
                            appStore.selectedWorkspace = .chapterStudio
                        } else {
                            Task {
                                await chapterStore.switchActiveChapter(toID: targetID)
                                appStore.selectedChapterID = targetID
                                appStore.selectedWorkspace = .chapterStudio
                            }
                        }
                    } label: {
                        Label("打开工作台", systemImage: "arrow.right.circle.fill")
                    }
                    .buttonStyle(GhostButtonStyle())
                }
                CardBody {
                    if let draft {
                        ScrollView {
                            Text(draft.text)
                                .font(.body)
                                .lineSpacing(7)
                                .foregroundStyle(AppTheme.text)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(minHeight: 320, maxHeight: 620)
                    } else {
                        EmptyStateView(text: "这一章还没有可阅读正文。")
                    }
                }
            } else {
                CardHeader(title: "正文", subtitle: nil)
                CardBody {
                    EmptyStateView(text: "请选择一个章节。")
                }
            }
        }
    }

    private func subtitle(for chapter: Chapter) -> String {
        if chapter.id == chapterStore.chapter.id {
            return "当前位于 \(chapterStore.currentStep.title) 阶段。"
        }
        return chapterStore.chapterDrafts[chapter.id] == nil ? "暂无正文版本。" : "已保存正文，可直接阅读。"
    }

    private func wordCountLabel(for chapter: Chapter) -> String {
        guard let draft = chapterStore.chapterDrafts[chapter.id] else {
            return "0"
        }
        return "\(draft.wordCount)"
    }

    private func canonLabel(for chapter: Chapter) -> String {
        "Canon v\(chapter.canonVersionUsed ?? chapterStore.novel.currentCanonVersion ?? 1)"
    }

    private func pillLabel(for chapter: Chapter) -> String {
        if chapter.id == chapterStore.chapter.id && chapter.status != .completed {
            return "当前章"
        }
        if chapterStore.chapterDrafts[chapter.id] != nil {
            return "可阅读"
        }
        return "待生成"
    }

    private func tone(for chapter: Chapter) -> PillTone {
        if chapter.id == chapterStore.chapter.id && chapter.status != .completed {
            return .blue
        }
        return chapterStore.chapterDrafts[chapter.id] == nil ? .neutral : .green
    }

    private func readerTitle(for chapter: Chapter) -> String {
        "第 \(chapter.chapterNo) 章 \(chapter.title ?? "未命名章节")"
    }

    private func readerSubtitle(for chapter: Chapter, draft: Draft?) -> String {
        guard let draft else {
            return "\(canonLabel(for: chapter)) · 暂无正文"
        }
        return "\(draft.wordCount) 字 · 版本 \(draft.versionNo) · \(canonLabel(for: chapter))"
    }
}

private struct BootstrapImportPanel: View {
    @Environment(AppStore.self) private var appStore
    @Environment(NovelLibraryStore.self) private var novelLibraryStore
    @Environment(ChapterWorkflowStore.self) private var chapterStore
    @Environment(BaseDocumentsStore.self) private var baseDocumentsStore
    @Environment(KnowledgeMatrixStore.self) private var knowledgeStore

    var body: some View {
        @Bindable var novelLibraryStore = novelLibraryStore

        CardView {
            CardHeader(
                title: "导入前三章",
                subtitle: "新书必须先导入第 1、2、3 章。系统会保存原文、分析基础资料，然后自动准备第 4 章作为当前写作章。"
            ) {
                PillView(text: chapterStore.novel.bootstrapStatus.displayName, tone: .orange)
            }

            CardBody {
                VStack(alignment: .leading, spacing: 14) {
                    ChapterImportEditor(
                        chapterNumber: 1,
                        title: $novelLibraryStore.importChapter1Title,
                        text: $novelLibraryStore.importChapter1Text
                    )
                    ChapterImportEditor(
                        chapterNumber: 2,
                        title: $novelLibraryStore.importChapter2Title,
                        text: $novelLibraryStore.importChapter2Text
                    )
                    ChapterImportEditor(
                        chapterNumber: 3,
                        title: $novelLibraryStore.importChapter3Title,
                        text: $novelLibraryStore.importChapter3Text
                    )
                }

                if let message = novelLibraryStore.statusMessage {
                    StatusBanner(message: message, tone: novelLibraryStore.error == nil ? .blue : .red)
                }
            }

            CardFooter {
                Button {
                    Task {
                        await novelLibraryStore.importFirstThreeChaptersAndPrepareNext(
                            appStore: appStore,
                            chapterStore: chapterStore,
                            baseDocumentsStore: baseDocumentsStore,
                            knowledgeStore: knowledgeStore
                        )
                    }
                } label: {
                    if novelLibraryStore.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("导入并分析前三章", systemImage: "tray.and.arrow.down")
                    }
                }
                .buttonStyle(BlueButtonStyle())
                .disabled(!novelLibraryStore.canImportFirstThreeChapters || novelLibraryStore.isLoading)
            }
        }
    }
}

private struct ChapterImportEditor: View {
    let chapterNumber: Int
    @Binding var title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                PillView(text: "第 \(chapterNumber) 章", tone: .blue)
                SoftTextField("章节标题", text: $title)
            }

            SoftTextEditor(
                text: $text,
                placeholder: "粘贴第 \(chapterNumber) 章正文。",
                minHeight: 160,
                idealHeight: 190,
                maxHeight: 240
            )

            HStack {
                Text("\(text.trimmingCharacters(in: .whitespacesAndNewlines).count) 字")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.muted)
                Spacer()
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.58), in: RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous)
                .stroke(Color.white.opacity(0.82), lineWidth: 1)
        )
    }
}

private struct ChapterTimelineRow: View {
    let chapter: String
    let title: String
    let subtitle: String
    let wordCount: String
    let canon: String
    let pill: String
    let tone: PillTone
    let isSelected: Bool

    var body: some View {
        TimelineItemView(
            badge: chapter,
            title: title,
            subtitle: subtitle,
            tone: tone
        ) {
            HStack(spacing: 12) {
                ChapterMetricInline(title: "字数", value: wordCount)
                ChapterMetricInline(title: "Canon", value: canon)
                Spacer()
            }
        } trailing: {
            PillView(text: pill, tone: tone)
        }
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous)
                .stroke(isSelected ? AppTheme.blue.opacity(0.56) : Color.clear, lineWidth: 1.5)
        )
    }
}

private struct ChapterMetricInline: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.muted)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.text)
        }
    }
}
