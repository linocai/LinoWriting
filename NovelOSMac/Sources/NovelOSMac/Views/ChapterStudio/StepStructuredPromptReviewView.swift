import NovelOSMacCore
import SwiftUI

struct StepStructuredPromptReviewView: View {
    @Environment(ChapterWorkflowStore.self) private var store

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                reviewCard
                    .frame(minWidth: 620)
                helpBlocks
                    .frame(width: 300)
            }

            VStack(alignment: .leading, spacing: 12) {
                reviewCard
                helpBlocks
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var reviewCard: some View {
        CardView {
            CardHeader(
                title: "结构化 Prompt 审核",
                subtitle: "这是你需要审核的核心文本。系统已经筛过上下文，不会要求你单独审核附加材料。"
            ) {
                PillView(text: ChapterStep.structuredPromptReview.userActionIndex, tone: .blue)
            }
            CardBody {
                if store.structuredPrompt == nil {
                    EmptyStateView(text: "结构化 Prompt 尚未生成。请回到第一步输入 Prompt。")
                } else {
                    editableTextBlock(title: "本章目标", binding: textBinding(\.chapterGoal), minHeight: 86)
                    editableListBlock(
                        title: "必须发生",
                        binding: listArrayBinding(\.mustHappen),
                        symbolName: "checkmark",
                        tone: .green,
                        addTitle: "新增必须发生"
                    )
                    editableListBlock(
                        title: "禁止发生",
                        binding: listArrayBinding(\.mustNotHappen),
                        symbolName: "xmark",
                        tone: .red,
                        addTitle: "新增禁止发生"
                    )

                    PromptCard(title: "本章可用专名", badge: "chips", tone: .blue) {
                        EntityChipGrid(entities: store.structuredPrompt?.allowedNamedEntities ?? [])
                    }

                    editableTextBlock(title: "文风与叙事限制", binding: textBinding(\.narrativeStyle), minHeight: 108)
                }
            }
            CardFooter {
                Button("返回 Prompt") {
                    store.tryMove(to: .promptInput)
                }
                .buttonStyle(GhostButtonStyle())
                Button("批准并生成正文") {
                    Task {
                        await store.approveStructuredPromptAndGenerateDraft()
                    }
                }
                .buttonStyle(BlueButtonStyle())
                .disabled(store.structuredPrompt == nil)
            }
        }
    }

    private var helpBlocks: some View {
        VStack(alignment: .leading, spacing: 12) {
            SideNoteView(
                title: "你审核的是结构化 Prompt",
                text: "不是底层 Context Pack。这里只保留目标、必须发生、禁止发生、可用专名和文风限制。",
                tone: .orange
            )
            SideNoteView(
                title: "Context Compiler",
                text: "已隐藏本章不相关人物，只把写作需要的上下文整理进当前章节。"
            )
            SideNoteView(
                title: "批准后直接生成整章",
                text: "不进入 Scene Plan，也不增加额外用户确认步骤。",
                tone: .blue
            )
        }
    }

    private func editableTextBlock(title: String, binding: Binding<String>, minHeight: CGFloat) -> some View {
        PromptCard(title: title, badge: "可编辑", tone: .blue) {
            SoftTextEditor(text: binding, minHeight: minHeight)
        }
    }

    private func editableListBlock(
        title: String,
        binding: Binding<[String]>,
        symbolName: String,
        tone: PillTone,
        addTitle: String
    ) -> some View {
        PromptCard(title: title, badge: "可编辑", tone: tone) {
            VStack(alignment: .leading, spacing: 8) {
                if binding.wrappedValue.isEmpty {
                    Text("暂无条目")
                        .font(.callout)
                        .foregroundStyle(AppTheme.muted)
                } else {
                    ForEach(Array(binding.wrappedValue.indices), id: \.self) { index in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: symbolName)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(tone.palette.foreground)
                                .frame(width: 22, height: 22)
                                .background(tone.palette.background, in: Circle())
                            SoftTextField(title: "条目", text: listItemBinding(binding, index: index), axis: .vertical)
                            Button {
                                var values = binding.wrappedValue
                                guard values.indices.contains(index) else { return }
                                values.remove(at: index)
                                binding.wrappedValue = values
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(GhostButtonStyle())
                        }
                    }
                }

                Button {
                    var values = binding.wrappedValue
                    values.append("")
                    binding.wrappedValue = values
                } label: {
                    Label(addTitle, systemImage: "plus")
                }
                .buttonStyle(GhostButtonStyle())
            }
        }
    }

    private func textBinding(_ keyPath: WritableKeyPath<StructuredPrompt, String>) -> Binding<String> {
        Binding {
            store.structuredPrompt?[keyPath: keyPath] ?? ""
        } set: { value in
            store.structuredPrompt?[keyPath: keyPath] = value
        }
    }

    private func listArrayBinding(_ keyPath: WritableKeyPath<StructuredPrompt, [String]>) -> Binding<[String]> {
        Binding {
            store.structuredPrompt?[keyPath: keyPath] ?? []
        } set: { value in
            store.structuredPrompt?[keyPath: keyPath] = value
        }
    }

    private func listItemBinding(_ binding: Binding<[String]>, index: Int) -> Binding<String> {
        Binding {
            guard binding.wrappedValue.indices.contains(index) else { return "" }
            return binding.wrappedValue[index]
        } set: { value in
            var values = binding.wrappedValue
            guard values.indices.contains(index) else { return }
            values[index] = value
            binding.wrappedValue = values
        }
    }
}
