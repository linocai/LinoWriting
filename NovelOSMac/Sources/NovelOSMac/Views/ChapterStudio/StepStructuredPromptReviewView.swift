import NovelOSMacCore
import SwiftUI

struct StepStructuredPromptReviewView: View {
    @Environment(ChapterWorkflowStore.self) private var store

    var body: some View {
        reviewCard
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var reviewCard: some View {
        CardView {
            CardHeader(
                title: "结构化 Prompt · 可读且可改",
                subtitle: "这是你这章的蓝图。每张 Prompt Card 可直接修改，删除或新增条目就是修改 prompt。"
            ) {
                PillView(text: ChapterStep.structuredPromptReview.userActionIndex, tone: .blue)
            }
            CardBody {
                if store.structuredPrompt == nil {
                    EmptyStateView(text: "结构化 Prompt 尚未生成。请回到第一步输入 Prompt。")
                } else {
                    TemplateCard(title: "本章目标", badge: "必填", tone: .blue) {
                        SoftTextEditor(text: textBinding(\.chapterGoal), minHeight: 74, idealHeight: 96)
                    }

                    editableListCard(
                        title: "必须发生",
                        binding: listArrayBinding(\.mustHappen),
                        symbolName: "checkmark",
                        tone: .green,
                        addTitle: "新增一条"
                    )

                    editableListCard(
                        title: "禁止发生",
                        binding: listArrayBinding(\.mustNotHappen),
                        symbolName: "xmark",
                        tone: .red,
                        addTitle: "新增一条"
                    )

                    TemplateCard(title: "本章可用专名（白名单）", badge: whitelistBadge, tone: .dark) {
                        VStack(alignment: .leading, spacing: 10) {
                            EntityChipGrid(entities: store.structuredPrompt?.allowedNamedEntities ?? [])
                            Text("写作 Agent 只看见白名单。其他人物本章会自动被 LOCKED_OUT。")
                                .font(.caption)
                                .foregroundStyle(AppTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    TemplateCard(title: "文风与叙事") {
                        SoftTextEditor(text: textBinding(\.narrativeStyle), minHeight: 96, idealHeight: 120)
                    }
                }
            }
            CardFooter {
                Button("返回 Prompt") {
                    store.tryMove(to: .promptInput)
                }
                .buttonStyle(GhostButtonStyle())
                .disabled(store.isLoading)

                Button {
                    Task {
                        await store.approveStructuredPromptAndGenerateDraft()
                    }
                } label: {
                    if store.isLoading {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("生成正文中")
                        }
                    } else {
                        Text("批准并生成正文")
                    }
                }
                .buttonStyle(BlueButtonStyle())
                .disabled(store.structuredPrompt == nil || store.isLoading)
            }
        }
    }

    private var whitelistBadge: String {
        let count = store.structuredPrompt?.allowedNamedEntities.count ?? 0
        return "\(count) 个实体"
    }

    private func editableListCard(
        title: String,
        binding: Binding<[String]>,
        symbolName: String,
        tone: PillTone,
        addTitle: String
    ) -> some View {
        TemplateCard(title: title, tone: tone) {
            Button {
                var values = binding.wrappedValue
                values.append("")
                binding.wrappedValue = values
            } label: {
                Label(addTitle, systemImage: "plus")
            }
            .buttonStyle(GhostButtonStyle())
        } content: {
            VStack(alignment: .leading, spacing: 8) {
                if binding.wrappedValue.isEmpty {
                    Text("暂无条目")
                        .font(.callout)
                        .foregroundStyle(AppTheme.muted)
                } else {
                    ForEach(Array(binding.wrappedValue.indices), id: \.self) { index in
                        StructuredPromptListRow(
                            text: listItemBinding(binding, index: index),
                            symbolName: symbolName,
                            tone: tone
                        ) {
                            var values = binding.wrappedValue
                            guard values.indices.contains(index) else { return }
                            values.remove(at: index)
                            binding.wrappedValue = values
                        }
                    }
                }
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

private struct StructuredPromptListRow: View {
    @Binding var text: String
    let symbolName: String
    let tone: PillTone
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbolName)
                .font(.caption.weight(.bold))
                .foregroundStyle(tone.palette.foreground)
                .frame(width: 24, height: 24)
                .background(tone.palette.background, in: Circle())
            SoftTextField(title: "条目", text: $text, axis: .vertical)
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(GhostButtonStyle())
            .help("删除这一条")
        }
        .padding(8)
        .background(Color.white.opacity(0.46), in: RoundedRectangle(cornerRadius: AppTheme.radiusMD, style: .continuous))
    }
}
