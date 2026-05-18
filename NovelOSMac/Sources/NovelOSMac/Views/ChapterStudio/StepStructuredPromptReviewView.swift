import NovelOSMacCore
import SwiftUI

struct StepStructuredPromptReviewView: View {
    @Environment(ChapterWorkflowStore.self) private var store

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            CardView {
                CardHeader(
                    title: "结构化 Prompt 审核",
                    subtitle: "这是你需要审核的核心文本。系统已经筛过上下文，但不会要求你单独审核 Context Pack。"
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
                        store.approveStructuredPromptAndGenerateDraft()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.structuredPrompt == nil)
                }
            }
            .frame(minWidth: 620)

            VStack(alignment: .leading, spacing: 12) {
                ContentBlock("设计重点") {
                    Text("这里是主流程唯一需要你编辑结构的地方。不要再额外弹出 Context Pack 审核、Agent 调用审核、Revision Plan 审核。")
                        .font(.callout)
                        .foregroundStyle(AppTheme.muted)
                }
                ContentBlock("后台已完成但不打扰你") {
                    Text("Context Compiler 已隐藏本章不相关人物；Knowledge Matrix 已限制 A 不能直接知道旧案真相；Allowed Named Entities 已准备给正文审计器。")
                        .font(.callout)
                        .foregroundStyle(AppTheme.muted)
                }
                ContentBlock("编辑方式") {
                    Text("结构化 Prompt 用卡片和可编辑文本，不让用户直接编辑 JSON。")
                        .font(.callout)
                        .foregroundStyle(AppTheme.muted)
                }
            }
            .frame(width: 280)
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
