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
                        .frame(minHeight: 180, idealHeight: 240, maxHeight: 320)
                        .padding(8)
                        .background(AppTheme.surfaceAlt.opacity(0.5), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border))
                }
            }
            CardFooter {
                Button("保存草稿") {
                    store.savePromptDraft()
                }
                Button("生成结构化 Prompt") {
                    Task {
                        await store.generateStructuredPrompt()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!store.canGenerateStructuredPrompt || store.isLoading)
            }
        }
    }
}
