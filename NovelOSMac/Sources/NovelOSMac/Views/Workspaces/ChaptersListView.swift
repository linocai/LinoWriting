import NovelOSMacCore
import SwiftUI

struct ChaptersListView: View {
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
                    .buttonStyle(.borderedProminent)
                }

                CardView {
                    CardBody {
                        ChapterTimelineRow(chapter: "第 1 章", title: "导入原文", subtitle: "作为前三章导入基础，用于初始 Canon。", pill: "locked", tone: .green)
                        ChapterTimelineRow(chapter: "第 2 章", title: "导入原文", subtitle: "已提取人物、Memory、World Bible 片段。", pill: "locked", tone: .green)
                        ChapterTimelineRow(chapter: "第 3 章", title: "导入原文", subtitle: "初始基础文件完成。", pill: "locked", tone: .green)
                        ChapterTimelineRow(chapter: "第 4 章", title: chapterStore.chapter.status == .completed ? "已完成" : "AI 创作中", subtitle: "当前位于 \(chapterStore.currentStep.title) 阶段。", pill: chapterStore.chapter.status == .completed ? "completed" : "current", tone: chapterStore.chapter.status == .completed ? .green : .blue)
                    }
                }
            }
            .padding(22)
        }
        .background(AppTheme.background)
    }
}

private struct ChapterTimelineRow: View {
    let chapter: String
    let title: String
    let subtitle: String
    let pill: String
    let tone: PillTone

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(chapter)
                .font(.headline)
                .foregroundStyle(AppTheme.muted)
                .frame(width: 80, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(AppTheme.muted)
            }
            Spacer()
            PillView(text: pill, tone: tone)
        }
        .padding(.vertical, 8)
    }
}
