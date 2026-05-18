import NovelOSMacCore
import SwiftUI

struct StepPromptInputView: View {
    @Environment(ChapterWorkflowStore.self) private var store

    var body: some View {
        @Bindable var store = store

        HStack(alignment: .top, spacing: 16) {
            CardView {
                CardHeader(
                    title: "本章原始 Prompt",
                    subtitle: "只需要写你脑中的章节方向。系统会在后台读取 Canon，扩展成结构化 Prompt。"
                ) {
                    PillView(text: ChapterStep.promptInput.userActionIndex, tone: .blue)
                }
                CardBody {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("第 \(store.chapter.chapterNo) 章想写什么？")
                                .font(.headline)
                            Spacer()
                            Text("建议 50-500 字")
                                .font(.caption)
                                .foregroundStyle(AppTheme.muted)
                        }
                        TextEditor(text: $store.promptDraft)
                            .font(.body)
                            .frame(minHeight: 180)
                            .padding(8)
                            .background(AppTheme.surfaceAlt.opacity(0.5), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border))
                    }

                    HStack(alignment: .top, spacing: 12) {
                        ContentBlock("可选辅助：本章出场") {
                            FlowLayout {
                                EntityChip(text: "A", tone: .green)
                                EntityChip(text: "B", tone: .green)
                                EntityChip(text: "C", tone: .green)
                            }
                        }
                        ContentBlock("可选辅助：不要展开") {
                            FlowLayout {
                                EntityChip(text: "A 的母亲 · 最多 1 次", tone: .orange)
                            }
                        }
                        ContentBlock("新内容策略") {
                            Text("允许无名路人和环境细节；不允许新增命名角色，除非结构化 Prompt 明确批准。")
                                .font(.callout)
                                .foregroundStyle(AppTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                CardFooter {
                    Button("保存草稿") {
                        store.savePromptDraft()
                    }
                    Button("生成结构化 Prompt") {
                        store.generateStructuredPrompt()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!store.canGenerateStructuredPrompt || store.isLoading)
                }
            }
            .frame(minWidth: 620)

            VStack(alignment: .leading, spacing: 12) {
                ContentBlock("前端施工意见") {
                    Text("这个页面不暴露调用了哪些 Agent。用户只看到一个输入框和一个生成按钮。")
                        .font(.callout)
                        .foregroundStyle(AppTheme.muted)
                }
                ContentBlock("不要做成聊天框") {
                    Text("Prompt 是章节指令，不是对话。用表单和版本记录承载，而不是无限聊天气泡。")
                        .font(.callout)
                        .foregroundStyle(AppTheme.muted)
                }
                ContentBlock("自动保存策略") {
                    Text("每次 Prompt 改动都保存为未提交草稿；点击生成后才创建本章 workflow run。")
                        .font(.callout)
                        .foregroundStyle(AppTheme.muted)
                }
            }
            .frame(width: 280)
        }
    }
}
