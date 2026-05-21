import NovelOSMacCore
import SwiftUI

struct StepPromptInputView: View {
    @Environment(ChapterWorkflowStore.self) private var store

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                PromptInputCard(store: store)
                    .frame(minWidth: 560, maxWidth: .infinity, alignment: .topLeading)
                promptSideNotes
                    .frame(width: 300)
            }

            VStack(alignment: .leading, spacing: 14) {
                PromptInputCard(store: store)
                promptSideNotes
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var promptSideNotes: some View {
        VStack(alignment: .leading, spacing: 12) {
            SideNoteView(
                title: "你只需要写方向",
                text: "系统会自动读取 Memory、World Bible、人物卡和 Knowledge Matrix，把方向扩展成可审核的结构化 Prompt。"
            )
            SideNoteView(
                title: "为什么不是聊天",
                text: "Prompt 是章节指令，不是对话。用表单和版本记录承载，便于修改和回滚。"
            )
            SideNoteView(
                title: "下一步",
                text: "生成结构化 Prompt 后，你只审核可见文本，不单独审核 Context Pack。"
            )
            SideNoteView(
                title: "快捷键",
                text: "Command-Return 进入下一步；Command-S 手动保存。",
                tone: .blue
            )
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
                        minHeight: 190,
                        idealHeight: 250,
                        maxHeight: 340
                    )
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10, alignment: .top)], alignment: .leading, spacing: 10) {
                    MiniPromptNote(title: "本章出场", value: activeCastText, tone: .green)
                    MiniPromptNote(title: "弱提及额度", value: "\(store.safetySummary.mentionBudgetTotal)", tone: .orange)
                    MiniPromptNote(title: "新角色策略", value: store.safetySummary.newNamedCharacterPolicy, tone: .red)
                }
            }
            CardFooter {
                Text("自动保存草稿")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                Button("保存草稿") {
                    store.savePromptDraft()
                }
                .buttonStyle(GhostButtonStyle())
                Button {
                    Task {
                        await store.generateStructuredPrompt()
                    }
                } label: {
                    if store.isLoading {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("生成中")
                        }
                    } else {
                        Text("生成结构化 Prompt")
                    }
                }
                .buttonStyle(BlueButtonStyle())
                .disabled(!store.canGenerateStructuredPrompt || store.isLoading)
            }
        }
    }

    private var activeCastText: String {
        let activeCast = store.safetySummary.activeCast
        return activeCast.isEmpty ? "待生成" : activeCast.joined(separator: "、")
    }
}

private struct MiniPromptNote: View {
    let title: String
    let value: String
    let tone: PillTone

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.muted)
            Text(value)
                .font(.callout.weight(.semibold))
                .foregroundStyle(tone.palette.foreground)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 74, alignment: .topLeading)
        .background(tone.palette.background, in: RoundedRectangle(cornerRadius: AppTheme.radiusMD, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMD, style: .continuous)
                .stroke(tone.palette.border, lineWidth: 1)
        )
    }
}
