import NovelOSMacCore
import SwiftUI

struct StepFinalApprovalView: View {
    @Environment(ChapterWorkflowStore.self) private var store

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                approvalCard
                    .frame(minWidth: 620)
                helpBlocks
                    .frame(width: 280)
            }

            VStack(alignment: .leading, spacing: 12) {
                approvalCard
                helpBlocks
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var approvalCard: some View {
        CardView {
            CardHeader(
                title: "批准正文",
                subtitle: "批准后，本章正文锁定为最终版本，并自动准备基础文档更新候选。"
            ) {
                PillView(text: ChapterStep.finalApproval.userActionIndex, tone: .blue)
            }
            CardBody {
                ContentBlock("最终版本摘要") {
                    MetricRowView(title: "版本号", value: "v\(store.draft?.versionNo ?? 0)", tone: .blue)
                    MetricRowView(title: "字数", value: "\(store.draft?.wordCount ?? 0)", tone: .neutral)
                    MetricRowView(title: "审计状态", value: (store.auditSummary?.s0Count ?? 0) == 0 ? "通过" : "有硬错误", tone: (store.auditSummary?.s0Count ?? 0) == 0 ? .green : .red)
                    MetricRowView(title: "Canon 版本", value: "v\(store.novel.currentCanonVersion ?? 12) -> 待生成 v\((store.novel.currentCanonVersion ?? 12) + 1)", tone: .purple)
                }

                EmptyStateView(text: "批准正文后，系统会根据本章内容准备基础文档更新候选。")
            }
            CardFooter {
                Button("返回正文审核") {
                    store.tryMove(to: .draftReview)
                }
                Button("批准正文并提取更新") {
                    Task {
                        await store.approveFinalTextAndPreparePatch()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var helpBlocks: some View {
        VStack(alignment: .leading, spacing: 12) {
            ContentBlock("批准意味着什么") {
                Text("批准的是可进入 Canon 提取的正文版本，不意味着所有基础文件自动改写。基础文件更新还需要你在下一步确认。")
                    .font(.callout)
                    .foregroundStyle(AppTheme.muted)
            }
            ContentBlock("版本控制") {
                Text("批准时会保存最终候选版本；历史草稿、修改版和审计结果仍可在版本记录中查看。")
                    .font(.callout)
                    .foregroundStyle(AppTheme.muted)
            }
        }
    }
}
