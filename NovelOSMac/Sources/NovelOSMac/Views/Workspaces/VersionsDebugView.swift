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
                TopBarView(kicker: "版本记录 · 高级区", title: "生成记录会留痕，但不打扰写作流程") {
                    HStack(spacing: 10) {
                        PillView(text: "高级记录", tone: .orange)
                        Button {
                            exportRunLog()
                        } label: {
                            Label("导出记录", systemImage: "square.and.arrow.up")
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

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 360), spacing: 16, alignment: .top)], alignment: .leading, spacing: 16) {
                    CardView {
                        CardHeader(
                            title: "上下文快照",
                            subtitle: "用于回看本章生成时引用过的材料，不需要在主流程单独审核。"
                        )
                        CardBody {
                            ContentBlock("本章可见范围") {
                                MetricRowView(title: "本章出场", value: chapterStore.safetySummary.activeCast.joined(separator: ", "), tone: .green)
                                MetricRowView(title: "可用专名数", value: "\(chapterStore.safetySummary.allowedNamesCount)", tone: .blue)
                                MetricRowView(title: "弱提及额度", value: "\(chapterStore.safetySummary.mentionBudgetTotal)", tone: .orange)
                            }

                            ContentBlock("可提及对象") {
                                FlowLayout {
                                    EntityChip(text: "A", tone: .green)
                                    EntityChip(text: "B", tone: .green)
                                    EntityChip(text: "C", tone: .green)
                                    EntityChip(text: "旧码头", tone: .blue)
                                    EntityChip(text: "旧案", tone: .blue)
                                    EntityChip(text: "A 的母亲 · 1 次", tone: .orange)
                                }
                            }

                            ContentBlock("叙事限制") {
                                Text("A 不能直接知道旧案完整真相；叙述不能确认 B 的全部参与。")
                                    .font(.callout)
                                    .foregroundStyle(AppTheme.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                    CardView {
                        CardHeader(
                            title: "生成运行记录",
                            subtitle: "只在需要追溯某次生成结果时查看。"
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
                    .frame(maxWidth: .infinity, alignment: .topLeading)
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
    private func exportRunLog() {
        let panel = NSSavePanel()
        panel.title = "导出 NovelOSMac 记录"
        panel.nameFieldStringValue = "NovelOSMac-RunLog.json"
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
            exportStatus = "记录已导出：\(url.lastPathComponent)"
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
