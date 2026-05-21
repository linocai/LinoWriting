import AppKit
import NovelOSMacCore
import SwiftUI
import UniformTypeIdentifiers

struct VersionsDebugView: View {
    @Environment(ChapterWorkflowStore.self) private var chapterStore
    @State private var exportStatus: String?
    @State private var exportIsError = false
    @State private var selectedRunID: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                TopBarView(kicker: "本章流程日志", title: "后台记录留痕，但不打扰写作流程") {
                    HStack(spacing: 10) {
                        PillView(text: "真实数据", tone: .green)
                        Button {
                            Task { await chapterStore.loadAgentRuns() }
                        } label: {
                            Label("刷新", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(GhostButtonStyle())
                        Button {
                            exportRunLog()
                        } label: {
                            Label("导出记录", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(GhostButtonStyle())
                    }
                }

                if let exportStatus {
                    StatusBanner(message: exportStatus, tone: exportIsError ? .red : .green)
                }

                summaryStrip

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 360), spacing: 16, alignment: .top)], alignment: .leading, spacing: 16) {
                    contextCard
                    timelineCard
                    ioCard
                }

                versionCard
                rawJSONCard
            }
            .padding(22)
        }
        .scrollIndicators(.visible)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppBackgroundView())
        .task {
            await chapterStore.loadAgentRuns()
            if selectedRunID == nil {
                selectedRunID = chapterStore.agentRuns.last?.id
            }
        }
        .onChange(of: chapterStore.agentRuns) { _, runs in
            if selectedRunID == nil || !runs.contains(where: { $0.id == selectedRunID }) {
                selectedRunID = runs.last?.id
            }
        }
    }

    private var summaryStrip: some View {
        HStack(spacing: 12) {
            SummaryMetricCard(title: "Agent Runs", value: "\(chapterStore.agentRuns.count)", tone: .blue)
            SummaryMetricCard(
                title: "Failed",
                value: "\(chapterStore.agentRuns.filter { $0.status == "failed" }.count)",
                tone: chapterStore.agentRuns.contains { $0.status == "failed" } ? .red : .green
            )
            SummaryMetricCard(
                title: "Current Draft",
                value: chapterStore.draft.map { "v\($0.versionNo)" } ?? (chapterStore.isDraftStreaming ? "Streaming" : "None"),
                tone: chapterStore.draft == nil ? .neutral : .green
            )
        }
    }

    private var contextCard: some View {
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
                        ForEach(chapterStore.safetySummary.activeCast, id: \.self) { name in
                            EntityChip(text: name, tone: .green)
                        }
                        EntityChip(text: "弱提及额度 \(chapterStore.safetySummary.mentionBudgetTotal)", tone: .orange)
                    }
                }

                ContentBlock("叙事限制") {
                    Text("Context Compiler、Knowledge Guard、Named Entity Linter 的实际输入输出记录在 Agent IO 中。")
                        .font(.callout)
                        .foregroundStyle(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var timelineCard: some View {
        CardView {
            CardHeader(
                title: "Agent Timeline",
                subtitle: "按后端真实 agent_runs 排序。"
            )
            CardBody {
                if chapterStore.agentRuns.isEmpty {
                    EmptyStateView(text: "当前章节还没有真实 Agent 运行记录。生成结构化 Prompt 或正文后会出现在这里。")
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(chapterStore.agentRuns) { run in
                            Button {
                                selectedRunID = run.id
                            } label: {
                                TimelineItemView(
                                    badge: run.timestampLabel,
                                    title: run.agentName,
                                    subtitle: run.summary,
                                    tone: tone(for: run)
                                ) {
                                    HStack(spacing: 8) {
                                        if let model = run.model {
                                            PillView(text: model, tone: .blue)
                                        }
                                        if let latency = run.latencyMs {
                                            PillView(text: "\(Int(latency))ms", tone: .neutral)
                                        }
                                    }
                                } trailing: {
                                    PillView(text: run.status, tone: tone(for: run))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var ioCard: some View {
        CardView {
            CardHeader(
                title: "Agent IO Sheet",
                subtitle: "每次调用的输入、输出、token 与错误信息。"
            )
            CardBody {
                if let run = selectedRun {
                    agentIODetails(run)
                } else {
                    EmptyStateView(text: "选择某条 Agent 记录后查看 IO。")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var versionCard: some View {
        CardView {
            CardHeader(
                title: "章节版本",
                subtitle: "展示当前章节本地已加载的草稿版本。"
            )
            CardBody {
                if let draft = chapterStore.draft ?? chapterStore.chapterDrafts[chapterStore.chapter.id] {
                    TimelineItemView(
                        badge: "v\(draft.versionNo)",
                        title: "当前正文版本",
                        subtitle: "chapter_version_id: \(draft.id)",
                        tone: .blue
                    ) {
                        HStack(spacing: 12) {
                            MetricInline(title: "字数", value: "\(draft.wordCount)")
                            MetricInline(title: "S0", value: "\(draft.auditSummary?.s0Count ?? 0)")
                            MetricInline(title: "S1", value: "\(draft.auditSummary?.s1Count ?? 0)")
                            MetricInline(title: "S2", value: "\(draft.auditSummary?.s2Count ?? 0)")
                        }
                    }
                } else if chapterStore.isDraftStreaming {
                    StatusBanner(message: "正文正在流式生成，当前约 \(chapterStore.streamedWordCount) 字。", tone: .blue)
                } else {
                    EmptyStateView(text: "当前章节还没有草稿版本。")
                }
            }
        }
    }

    private var rawJSONCard: some View {
        CardView {
            CardHeader(
                title: "原始 JSON",
                subtitle: "用于排查后端记录，不作为日常审核入口。"
            )
            CardBody {
                DisclosureGroup("Agent Runs JSON") {
                    jsonText(chapterStore.agentRuns)
                }
            }
        }
    }

    private var selectedRun: AgentRun? {
        guard let selectedRunID else { return chapterStore.agentRuns.last }
        return chapterStore.agentRuns.first(where: { $0.id == selectedRunID })
    }

    @ViewBuilder
    private func agentIODetails(_ run: AgentRun) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                PillView(text: run.runType, tone: .blue)
                PillView(text: run.status, tone: tone(for: run))
                if let model = run.model {
                    PillView(text: model, tone: .purple)
                }
            }

            if let error = run.errorMessage, !error.isEmpty {
                StatusBanner(message: error, tone: .red)
            }

            ContentBlock("Token Usage", tone: .blue) {
                HStack(spacing: 12) {
                    MetricInline(title: "prompt", value: tokenValue("prompt_tokens", in: run))
                    MetricInline(title: "completion", value: tokenValue("completion_tokens", in: run))
                    MetricInline(title: "total", value: tokenValue("total_tokens", in: run))
                }
            }

            DisclosureGroup("Input JSON") {
                jsonText(run.inputPayload.isEmpty ? run.inputJson : run.inputPayload)
            }

            DisclosureGroup("Output JSON") {
                jsonText(run.outputPayload.isEmpty ? run.outputJson : run.outputPayload)
            }
        }
    }

    private func jsonText<T: Encodable>(_ value: T) -> some View {
        ScrollView(.horizontal) {
            Text(prettyJSON(value))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(AppTheme.text)
                .textSelection(.enabled)
                .padding(10)
                .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: AppTheme.radiusSM, style: .continuous))
        }
    }

    private func tone(for run: AgentRun) -> PillTone {
        if run.status == "failed" { return .red }
        if run.status.contains("running") { return .blue }
        if run.status.contains("generated") || run.status.contains("approved") || run.status == "pass" { return .green }
        return .orange
    }

    private func tokenValue(_ key: String, in run: AgentRun) -> String {
        run.tokenUsage[key]?.displayString ?? "0"
    }

    private func prettyJSON<T: Encodable>(_ value: T) -> String {
        let encoder = APIJSONCoding.makeEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    @MainActor
    private func exportRunLog() {
        let panel = NSSavePanel()
        panel.title = "导出 LinoI 记录"
        panel.nameFieldStringValue = "LinoI-RunLog.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let json = prettyJSON(chapterStore.agentRuns)
            try json.write(to: url, atomically: true, encoding: .utf8)
            exportIsError = false
            exportStatus = "记录已导出：\(url.lastPathComponent)"
        } catch {
            exportIsError = true
            exportStatus = "导出失败：\(error.localizedDescription)"
        }
    }
}

private struct SummaryMetricCard: View {
    let title: String
    let value: String
    let tone: PillTone

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.muted)
            HStack {
                Text(value)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                Spacer()
                Circle()
                    .fill(tone.color)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.76), in: RoundedRectangle(cornerRadius: AppTheme.radiusSM, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusSM, style: .continuous)
                .stroke(AppTheme.line)
        )
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
