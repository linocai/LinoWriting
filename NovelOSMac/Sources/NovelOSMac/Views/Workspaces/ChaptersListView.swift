import NovelOSMacCore
import SwiftUI

struct ChaptersListView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(ChapterWorkflowStore.self) private var chapterStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                TopBarView(kicker: "章节列表", title: "章节是版本化资产，不是聊天记录") {
                    Button {
                        chapterStore.statusMessage = "新建下一章会在接入真实 API 后启用。"
                    } label: {
                        Label("新建下一章", systemImage: "plus")
                    }
                    .buttonStyle(BlueButtonStyle())
                }

                CardView {
                    CardHeader(title: "章节资产", subtitle: "每一章都保留状态、字数和 Canon 版本。")
                    CardBody {
                        VStack(alignment: .leading, spacing: 10) {
                            ChapterTimelineRow(chapter: "第 1 章", title: "导入原文", subtitle: "作为前三章导入基础，用于初始 Canon。", wordCount: "3,120", canon: "Canon v4", pill: "locked", tone: .green)
                            ChapterTimelineRow(chapter: "第 2 章", title: "导入原文", subtitle: "已提取人物、Memory、World Bible 片段。", wordCount: "3,380", canon: "Canon v8", pill: "locked", tone: .green)
                            ChapterTimelineRow(chapter: "第 3 章", title: "导入原文", subtitle: "初始基础文件完成。", wordCount: "3,460", canon: "Canon v12", pill: "locked", tone: .green)
                            Button {
                                appStore.selectedWorkspace = .chapterStudio
                            } label: {
                                ChapterTimelineRow(
                                    chapter: "第 4 章",
                                    title: chapterStore.chapter.status == .completed ? "已完成" : "AI 创作中",
                                    subtitle: "当前位于 \(chapterStore.currentStep.title) 阶段。",
                                    wordCount: "\(chapterStore.draft?.wordCount ?? 0)",
                                    canon: "Canon v\(chapterStore.novel.currentCanonVersion ?? 12)",
                                    pill: chapterStore.chapter.status == .completed ? "completed" : "current",
                                    tone: chapterStore.chapter.status == .completed ? .green : .blue
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(AppTheme.pagePadding)
        }
        .background(AppBackgroundView())
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
