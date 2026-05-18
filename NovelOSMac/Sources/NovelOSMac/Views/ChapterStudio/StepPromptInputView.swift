import NovelOSMacCore
import SwiftUI

struct StepPromptInputView: View {
    @Environment(ChapterWorkflowStore.self) private var store

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                PromptInputCard(store: store)
                    .frame(minWidth: 620)
                PromptHelpRail()
                    .frame(width: 300)
            }

            VStack(alignment: .leading, spacing: 12) {
                PromptInputCard(store: store)
                PromptHelpRail()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct PromptInputCard: View {
    @Bindable var store: ChapterWorkflowStore

    var body: some View {
        CardView {
            CardHeader(
                title: "本章原始 Prompt",
                subtitle: "只需要写你脑中的章节方向。系统会自动读取 Canon，扩展成结构化 Prompt。"
            ) {
                PillView(text: ChapterStep.promptInput.userActionIndex, tone: .blue)
            }
            CardBody {
                LabeledField("第 \(store.chapter.chapterNo) 章想写什么？", hint: "建议 50-500 字") {
                    SoftTextEditor(
                        text: $store.promptDraft,
                        placeholder: "写下本章方向、冲突、结尾钩子或不想展开的部分。",
                        minHeight: 170,
                        idealHeight: 240,
                        maxHeight: 320
                    )
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12, alignment: .top)], alignment: .leading, spacing: 12) {
                    PromptMiniNote(title: "本章出场", tone: .green) {
                        FlowLayout {
                            ForEach(store.safetySummary.activeCast, id: \.self) { name in
                                EntityChip(text: name, tone: .green)
                            }
                        }
                    }

                    PromptMiniNote(title: "弱提及", tone: .orange) {
                        EntityChip(text: "A 的母亲 · 最多 \(max(store.safetySummary.mentionBudgetTotal, 1)) 次", tone: .orange)
                    }

                    PromptMiniNote(title: "新角色策略", tone: .purple) {
                        Text("默认禁止新增命名角色")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(AppTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            CardFooter {
                Button("保存草稿") {
                    store.savePromptDraft()
                }
                .buttonStyle(GhostButtonStyle())
                Button("生成结构化 Prompt") {
                    Task {
                        await store.generateStructuredPrompt()
                    }
                }
                .buttonStyle(BlueButtonStyle())
                .disabled(!store.canGenerateStructuredPrompt || store.isLoading)
            }
        }
    }
}

private struct PromptMiniNote<Content: View>: View {
    let title: String
    var tone: PillTone
    let content: Content

    init(title: String, tone: PillTone, @ViewBuilder content: () -> Content) {
        self.title = title
        self.tone = tone
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
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .background(tone.palette.background, in: RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous)
                .stroke(tone.palette.border, lineWidth: 1)
        )
    }
}

private struct PromptHelpRail: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SideNoteView(
                title: "你只需要写方向",
                text: "系统会自动读取 Memory、World Bible、人物卡和 Knowledge Matrix。"
            )
            SideNoteView(
                title: "为什么不是聊天",
                text: "Prompt 是章节指令，不是对话。用表单和版本记录承载，而不是无限聊天气泡。"
            )
            SideNoteView(
                title: "下一步",
                text: "生成结构化 Prompt 后，你只审核可见文本，不单独审核 Context Pack。",
                tone: .blue
            )
        }
    }
}
