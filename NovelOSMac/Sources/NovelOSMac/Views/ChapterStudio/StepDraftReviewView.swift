import NovelOSMacCore
import SwiftUI

struct StepDraftReviewView: View {
    @Environment(ChapterWorkflowStore.self) private var store

    var body: some View {
        @Bindable var store = store

        CardView {
            CardHeader(
                title: "正文审核",
                subtitle: "正文以整章生成。审计结果在旁边提示，但你只需要读正文并决定是否修改。"
            ) {
                HStack(spacing: 8) {
                    PillView(text: "S0 硬错误：\(store.auditSummary?.s0Count ?? 0)", tone: (store.auditSummary?.s0Count ?? 0) > 0 ? .red : .green)
                    PillView(text: "S1 建议：\(store.auditSummary?.s1Count ?? 0)", tone: .orange)
                    PillView(text: "约 \(store.visibleDraftWordCount) 字", tone: .blue)
                }
            }
            CardBody {
                if store.draft == nil && !store.isDraftStreaming {
                    EmptyStateView(text: "正文尚未生成。请先批准结构化 Prompt。")
                } else {
                    if store.isDraftStreaming {
                        StatusBanner(message: "Writing Agent 正在流式生成正文，当前约 \(store.streamedWordCount) 字。", tone: .blue)
                    }

                    if store.isRevisionRunning {
                        StatusBanner(message: "Revision Agent 正在根据你的意见重写，本页会留在正文审核步骤。", tone: .blue)
                    }

                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 16) {
                            draftEditorAndFeedback
                            auditPanel
                                .frame(width: 320)
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            draftEditorAndFeedback
                            auditPanel
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let reason = store.finalApprovalBlockedReason {
                        StatusBanner(message: reason, tone: .red)
                    }
                }
            }
            CardFooter {
                Button("按我的意见修改") {
                    Task {
                        await store.requestRevision()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(store.reviewFeedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.draft == nil || store.isRevisionRunning || store.isDraftStreaming)
                .overlay {
                    if store.isRevisionRunning {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("修改中")
                                .font(.callout.weight(.semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.dark, in: RoundedRectangle(cornerRadius: AppTheme.radiusSM, style: .continuous))
                        .foregroundStyle(Color.white)
                    }
                }

                Button("保存当前版本") {
                    store.saveCurrentDraftVersion()
                }
                .buttonStyle(GhostButtonStyle())
                .disabled(store.draft == nil || store.isRevisionRunning || store.isDraftStreaming)

                Button("我满意，进入批准") {
                    Task {
                        _ = await store.approveDraftForFinalReview()
                    }
                }
                .buttonStyle(BlueButtonStyle())
                .disabled(store.draft == nil || store.finalApprovalBlockedReason != nil || store.isRevisionRunning || store.isDraftStreaming)
            }
        }
    }

    private var draftTextBinding: Binding<String> {
        Binding {
            store.draft?.text ?? store.streamedDraftText
        } set: { value in
            if store.draft == nil {
                store.streamedDraftText = value
                store.streamedWordCount = value.count
            } else {
                store.draft?.text = value
                store.draft?.wordCount = max(0, value.count / 2)
            }
        }
    }

    private var draftEditorAndFeedback: some View {
        @Bindable var store = store

        return VStack(alignment: .leading, spacing: 14) {
            LabeledField("第 \(store.chapter.chapterNo) 章正文", hint: "可直接编辑正文，也可在下方写修改意见") {
                SoftTextEditor(
                    text: draftTextBinding,
                    minHeight: 520,
                    font: .system(size: 15, weight: .regular, design: .default),
                    lineSpacing: 12
                )
            }

            Text("直接给一句话就行，系统会自动改写。不需要逐段标注。")
                .font(.callout.weight(.semibold))
                .foregroundStyle(AppTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            LabeledField("我的修改意见", hint: "属于“审核正文”动作，不新增流程") {
                SoftTextEditor(
                    text: $store.reviewFeedback,
                    placeholder: "写下你希望系统重修的方向。",
                    minHeight: 92,
                    idealHeight: 120
                )
            }
        }
    }

    private var auditPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            ContentBlock("自动审计摘要", tone: .blue) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(store.auditSummary?.issues ?? []) { issue in
                        AuditIssueView(issue: issue)
                    }
                }
            }

            ContentBlock("越界检查", tone: .green) {
                MetricRowView(title: "非法专名", value: "\(store.auditSummary?.illegalNamedEntityCount ?? 0)", tone: (store.auditSummary?.illegalNamedEntityCount ?? 0) > 0 ? .red : .green)
                MetricRowView(title: "未激活角色出场", value: "\(store.auditSummary?.inactiveCharacterAppearanceCount ?? 0)", tone: .green)
                MetricRowView(title: "知识越界", value: "\(store.auditSummary?.knowledgeViolationCount ?? 0)", tone: .green)
                MetricRowView(title: "新增命名角色", value: "\(store.auditSummary?.newNamedEntityCount ?? 0)", tone: .green)
            }
        }
    }
}
