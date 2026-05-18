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
                    .frame(width: 280)
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
                    editableTextBlock(title: "本章目标", binding: textBinding(\.chapterGoal), minHeight: 82)
                    editableTextBlock(title: "必须发生", binding: listBinding(\.mustHappen), minHeight: 130)
                    editableTextBlock(title: "禁止发生", binding: listBinding(\.mustNotHappen), minHeight: 130)

                    ContentBlock("本章可用专名") {
                        FlowLayout {
                            ForEach(store.structuredPrompt?.allowedNamedEntities ?? []) { entity in
                                EntityChip(text: entityLabel(entity), tone: entityTone(entity))
                            }
                        }
                    }

                    editableTextBlock(title: "文风与叙事限制", binding: textBinding(\.narrativeStyle), minHeight: 104)
                }
            }
            CardFooter {
                Button("返回 Prompt") {
                    store.tryMove(to: .promptInput)
                }
                Button("批准并生成正文") {
                    Task {
                        await store.approveStructuredPromptAndGenerateDraft()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.structuredPrompt == nil)
            }
        }
    }

    private var helpBlocks: some View {
        VStack(alignment: .leading, spacing: 12) {
            ContentBlock("审核范围") {
                Text("只需要确认本章目标、必须发生、禁止发生、可用专名和文风限制。")
                    .font(.callout)
                    .foregroundStyle(AppTheme.muted)
            }
            ContentBlock("本章限制") {
                Text("系统已按基础文档筛掉无关信息，并限制角色不能越权知道尚未揭露的真相。")
                    .font(.callout)
                    .foregroundStyle(AppTheme.muted)
            }
            ContentBlock("编辑方式") {
                Text("直接改上方文字即可；批准后会生成正文草稿。")
                    .font(.callout)
                    .foregroundStyle(AppTheme.muted)
            }
        }
    }

    private func editableTextBlock(title: String, binding: Binding<String>, minHeight: CGFloat) -> some View {
        ContentBlock(title) {
            TextEditor(text: binding)
                .font(.body)
                .frame(minHeight: minHeight)
                .padding(8)
                .background(AppTheme.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border))
        }
    }

    private func textBinding(_ keyPath: WritableKeyPath<StructuredPrompt, String>) -> Binding<String> {
        Binding {
            store.structuredPrompt?[keyPath: keyPath] ?? ""
        } set: { value in
            store.structuredPrompt?[keyPath: keyPath] = value
        }
    }

    private func listBinding(_ keyPath: WritableKeyPath<StructuredPrompt, [String]>) -> Binding<String> {
        Binding {
            store.structuredPrompt?[keyPath: keyPath].joined(separator: "\n") ?? ""
        } set: { value in
            store.structuredPrompt?[keyPath: keyPath] = value.linesFromEditor
        }
    }

    private func entityLabel(_ entity: AllowedEntity) -> String {
        if let budget = entity.mentionBudget {
            return "\(entity.name) · \(entity.activation.rawValue) \(budget)"
        }
        return "\(entity.name) · \(entity.activation.rawValue)"
    }

    private func entityTone(_ entity: AllowedEntity) -> PillTone {
        switch entity.activation {
        case .active: .green
        case .mentionAllowed: .orange
        case .background: .blue
        case .lockedOut: .red
        case .newAllowed: .purple
        }
    }
}
