import NovelOSMacCore
import SwiftUI

struct StepPromptInputView: View {
    @Environment(ChapterWorkflowStore.self) private var store

    var body: some View {
        PromptInputCard(store: store)
            .frame(maxWidth: .infinity, alignment: .topLeading)
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
