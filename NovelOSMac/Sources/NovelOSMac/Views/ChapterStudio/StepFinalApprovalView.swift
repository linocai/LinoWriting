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
                    .frame(width: 300)
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
                ContentBlock("最终版本摘要", tone: .blue) {
                    MetricRowView(title: "版本号", value: "v\(store.draft?.versionNo ?? 0)", tone: .blue)
                    MetricRowView(title: "字数", value: "\(store.draft?.wordCount ?? 0)", tone: .neutral)
                    MetricRowView(title: "审计状态", value: (store.auditSummary?.s0Count ?? 0) == 0 ? "通过" : "有硬错误", tone: (store.auditSummary?.s0Count ?? 0) == 0 ? .green : .red)
                    MetricRowView(title: "Canon 版本", value: "v\(store.novel.currentCanonVersion ?? 12) -> 待生成 v\((store.novel.currentCanonVersion ?? 12) + 1)", tone: .purple)
                    MetricRowView(title: "Allowed Names", value: "通过", tone: .green)
                    MetricRowView(title: "Knowledge Guard", value: "通过", tone: .green)
                }

                ContentBlock("最终正文预览", tone: .neutral) {
                    Text(finalPreview)
                        .font(.system(size: 15, weight: .regular, design: .default))
                        .foregroundStyle(AppTheme.text)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            CardFooter {
                Button("返回正文审核") {
                    store.tryMove(to: .draftReview)
                }
                .buttonStyle(GhostButtonStyle())
                Button("批准正文并提取更新") {
                    Task {
                        await store.approveFinalTextAndPreparePatch()
                    }
                }
                .buttonStyle(BlueButtonStyle())
            }
        }
    }

    private var finalPreview: String {
        guard let text = store.draft?.text, !text.isEmpty else {
            return "还没有可预览的最终正文。请先回到正文审核页生成或确认正文。"
        }
        let prefix = String(text.prefix(400))
        return text.count > 400 ? "\(prefix)..." : prefix
    }

    private var helpBlocks: some View {
        VStack(alignment: .leading, spacing: 12) {
            SideNoteView(
                title: "批准意味着什么",
                text: "批准的是可进入 Canon 提取的正文版本，不意味着所有基础文件自动改写。基础文件更新还需要你在下一步确认。",
                tone: .blue
            )
            SideNoteView(
                title: "版本控制",
                text: "批准时会保存最终候选版本；历史草稿、修改版和审计结果仍可在版本与调试中查看。"
            )
        }
    }
}
