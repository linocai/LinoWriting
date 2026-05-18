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
                    PillView(text: "约 \(store.draft?.wordCount ?? 0) 字", tone: .blue)
                }
            }
            CardBody {
                if store.draft == nil {
                    EmptyStateView(text: "正文尚未生成。请先批准结构化 Prompt。")
                } else {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 14) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("第 \(store.chapter.chapterNo) 章正文")
                                        .font(.headline)
                                    Spacer()
                                    Text("可直接编辑正文，也可在下方写修改意见")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.muted)
                                }
                                TextEditor(text: draftTextBinding)
                                    .font(.body)
                                    .frame(minHeight: 420)
                                    .padding(8)
                                    .background(AppTheme.surfaceAlt.opacity(0.4), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border))
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("我的修改意见")
                                        .font(.headline)
                                    Spacer()
                                    Text("属于“审核正文”动作，不新增流程")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.muted)
                                }
                                TextEditor(text: $store.reviewFeedback)
                                    .frame(minHeight: 92)
                                    .padding(8)
                                    .background(AppTheme.surfaceAlt.opacity(0.4), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border))
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            ContentBlock("自动审计摘要") {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(store.auditSummary?.issues ?? []) { issue in
                                        AuditIssueView(issue: issue)
                                    }
                                }
                            }

                            ContentBlock("越界检查") {
                                MetricRowView(title: "非法专名", value: "\(store.auditSummary?.illegalNamedEntityCount ?? 0)", tone: (store.auditSummary?.illegalNamedEntityCount ?? 0) > 0 ? .red : .green)
                                MetricRowView(title: "未激活角色出场", value: "\(store.auditSummary?.inactiveCharacterAppearanceCount ?? 0)", tone: .green)
                                MetricRowView(title: "Knowledge 越界", value: "\(store.auditSummary?.knowledgeViolationCount ?? 0)", tone: .green)
                                MetricRowView(title: "新增命名角色", value: "\(store.auditSummary?.newNamedEntityCount ?? 0)", tone: .green)
                            }

                            if let reason = store.finalApprovalBlockedReason {
                                Text(reason)
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(AppTheme.red)
                                    .padding(10)
                                    .background(AppTheme.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                        .frame(width: 300)
                    }
                }
            }
            CardFooter {
                Button("按我的意见修改") {
                    store.requestRevision()
                }
                .disabled(store.reviewFeedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.draft == nil)

                Button("保存当前版本") {
                    store.saveCurrentDraftVersion()
                }
                .disabled(store.draft == nil)

                Button("我满意，进入批准") {
                    _ = store.approveDraftForFinalReview()
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.draft == nil || store.finalApprovalBlockedReason != nil)
            }
        }
    }

    private var draftTextBinding: Binding<String> {
        Binding {
            store.draft?.text ?? ""
        } set: { value in
            store.draft?.text = value
            store.draft?.wordCount = max(0, value.count / 2)
        }
    }
}
