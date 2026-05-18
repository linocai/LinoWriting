import AppKit
import NovelOSMacCore
import SwiftUI
import UniformTypeIdentifiers

struct VersionsDebugView: View {
    @Environment(ChapterWorkflowStore.self) private var chapterStore
    @State private var exportStatus: String?
    @State private var exportIsError = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                TopBarView(kicker: "版本与调试 · 高级区", title: "所有后台细节都留痕，但不进入主流程") {
                    HStack(spacing: 10) {
                        PillView(text: "Debug Only", tone: .orange)
                        Button {
                            exportDebugLog()
                        } label: {
                            Label("导出日志", systemImage: "square.and.arrow.up")
                        }
                    }
                }

                if let exportStatus {
                    Text(exportStatus)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(exportIsError ? AppTheme.red : AppTheme.green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background((exportIsError ? AppTheme.red : AppTheme.green).opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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

                CardView {
                    CardHeader(
                        title: "章节版本",
                        subtitle: "草稿、修改版和批准候选都在这里留痕，不变成主流程审核项。"
                    )
                    CardBody {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(MockData.chapterVersions) { version in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("v\(version.versionNo)")
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(AppTheme.blue)
                                        .frame(width: 42, alignment: .leading)

                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(spacing: 8) {
                                            PillView(text: version.kind, tone: version.kind == "final" ? .green : .blue)
                                            PillView(text: version.status, tone: version.status == "approved_final" ? .green : .orange)
                                            Text(version.createdAtLabel)
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(AppTheme.muted)
                                        }

                                        Text(version.note)
                                            .font(.callout)
                                            .foregroundStyle(AppTheme.text)

                                        HStack(spacing: 12) {
                                            MetricInline(title: "字数", value: "\(version.wordCount)")
                                            MetricInline(title: "S0", value: "\(version.auditSummary?.s0Count ?? 0)")
                                            MetricInline(title: "S1", value: "\(version.auditSummary?.s1Count ?? 0)")
                                            MetricInline(title: "S2", value: "\(version.auditSummary?.s2Count ?? 0)")
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(10)
                                .background(AppTheme.surfaceAlt.opacity(0.45), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                    }
                }
            }
            .padding(22)
        }
        .background(AppTheme.background)
    }

    @MainActor
    private func exportDebugLog() {
        let panel = NSSavePanel()
        panel.title = "导出 NovelOSMac Debug Log"
        panel.nameFieldStringValue = "NovelOSMac-DebugLog.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let payload = MockData.debugExportPayload(chapter: chapterStore.chapter, exportedAt: Date())
            let json = try payload.prettyPrintedJSON()
            try json.write(to: url, atomically: true, encoding: .utf8)
            exportIsError = false
            exportStatus = "日志已导出：\(url.lastPathComponent)"
        } catch {
            exportIsError = true
            exportStatus = "导出失败：\(error.localizedDescription)"
        }
    }
}

private struct MetricInline: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.muted)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.text)
        }
    }
}
