import NovelOSMacCore
import SwiftUI

struct VersionsDebugView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                TopBarView(kicker: "版本与调试 · 高级区", title: "所有后台细节都留痕，但不进入主流程") {
                    HStack(spacing: 10) {
                        PillView(text: "Debug Only", tone: .orange)
                        Button {
                        } label: {
                            Label("导出日志", systemImage: "square.and.arrow.up")
                        }
                    }
                }

                HStack(alignment: .top, spacing: 16) {
                    CardView {
                        CardHeader(
                            title: "Context Pack 快照",
                            subtitle: "给开发和排错用，不需要用户在主流程审核。"
                        )
                        CardBody {
                            ScrollView {
                                Text(MockData.contextPackJSON)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }
                            .frame(minHeight: 360)
                        }
                    }

                    CardView {
                        CardHeader(
                            title: "Agent Run 历史",
                            subtitle: "只在排查为什么写歪了时查看。"
                        )
                        CardBody {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(MockData.agentRuns) { run in
                                    HStack(alignment: .top, spacing: 12) {
                                        Text(run.timestampLabel)
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(AppTheme.muted)
                                            .frame(width: 42, alignment: .leading)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(run.agentName)
                                                .font(.headline)
                                            Text(run.summary)
                                                .font(.callout)
                                                .foregroundStyle(AppTheme.muted)
                                        }
                                        Spacer()
                                        PillView(text: run.status, tone: run.status == "pass" ? .green : .orange)
                                    }
                                    .padding(10)
                                    .background(AppTheme.surfaceAlt.opacity(0.45), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                            }
                        }
                    }
                }
            }
            .padding(22)
        }
        .background(AppTheme.background)
    }
}
