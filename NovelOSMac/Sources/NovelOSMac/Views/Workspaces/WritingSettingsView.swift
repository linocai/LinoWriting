import NovelOSMacCore
import SwiftUI

struct WritingSettingsView: View {
    @Environment(ApplicationSettingsStore.self) private var settings
    @State private var targetWords = "3000 ± 400 字"
    @State private var scenePolicy = "最多 2 个自然场景"
    @State private var newCharacterPolicy = "默认禁止，除非结构化 Prompt 批准"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                TopBarView(kicker: "写作设置", title: "连接后端与模型") {
                    Button {
                        Task { await settings.loadLLMProviders() }
                    } label: {
                        Label("刷新配置", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(BlueButtonStyle())
                    .disabled(settings.isLoading)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 16) {
                            connectionCard
                            writingPolicyCard
                        }
                        .frame(minWidth: 340, idealWidth: 420, maxWidth: 460)

                        llmCard
                            .frame(maxWidth: .infinity)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        connectionCard
                        llmCard
                        writingPolicyCard
                    }
                }

                if let message = settings.statusMessage {
                    SideNoteView(title: "状态", text: message, tone: settings.error == nil ? .blue : .red)
                }
            }
            .padding(AppTheme.pagePadding)
        }
        .background(AppBackgroundView())
        .task {
            if settings.providers.isEmpty {
                await settings.loadLLMProviders()
            }
        }
    }

    private var connectionCard: some View {
        CardView {
            CardHeader(title: "后端连接", subtitle: "本地服务不需要管理口令；只有公网部署时才需要。")
            CardBody {
                LabeledField("后端地址") {
                    SoftTextField("http://127.0.0.1:7773", text: binding(\.backendURLString))
                }
                LabeledField("管理口令", hint: settings.ownerTokenConfigured ? "已保存；留空不会覆盖" : "首次连接需要填写") {
                    SecureSoftField("管理口令", text: binding(\.ownerTokenInput))
                }
                Button {
                    _ = settings.saveConnectionSettings()
                } label: {
                    Label("保存连接", systemImage: "checkmark.circle")
                }
                .buttonStyle(GhostButtonStyle())
            }
        }
    }

    private var llmCard: some View {
        CardView {
            CardHeader(title: "LLM Provider", subtitle: "支持多个 OpenAI-compatible endpoint，保存后可切换当前模型。") {
                Button {
                    settings.startNewProvider()
                } label: {
                    Label("新增", systemImage: "plus")
                }
                .buttonStyle(GhostButtonStyle())
            }
            CardBody {
                providerList

                LabeledField("Provider ID") {
                    SoftTextField("例如 deepseek", text: binding(\.selectedProviderID))
                }
                LabeledField("显示名称") {
                    SoftTextField("例如 DeepSeek", text: binding(\.providerName))
                }
                LabeledField("Base URL") {
                    SoftTextField("https://api.openai.com/v1", text: binding(\.providerBaseURL))
                }
                LabeledField("Model") {
                    SoftTextField("gpt-4.1-mini", text: binding(\.providerModel))
                }
                HStack(alignment: .top, spacing: 12) {
                    LabeledField("Timeout") {
                        SoftTextField("60", text: binding(\.providerTimeout))
                    }
                    LabeledField("API Key", hint: "留空保留已保存 key") {
                        SecureSoftField("API Key", text: binding(\.providerAPIKey))
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        Button {
                            Task { await settings.saveProvider() }
                        } label: {
                            Label("保存 Provider", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(BlueButtonStyle())

                        Button {
                            Task { await settings.setActiveProvider() }
                        } label: {
                            Label("设为当前", systemImage: "checkmark.seal")
                        }
                        .buttonStyle(GhostButtonStyle())

                        Button {
                            Task { await settings.testProvider() }
                        } label: {
                            Label("测试连接", systemImage: "bolt.circle")
                        }
                        .buttonStyle(GhostButtonStyle())
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Button("保存 Provider") {
                            Task { await settings.saveProvider() }
                        }
                        .buttonStyle(BlueButtonStyle())
                        Button("设为当前") {
                            Task { await settings.setActiveProvider() }
                        }
                        .buttonStyle(GhostButtonStyle())
                        Button("测试连接") {
                            Task { await settings.testProvider() }
                        }
                        .buttonStyle(GhostButtonStyle())
                    }
                }
                .disabled(settings.isLoading)
            }
        }
    }

    private var providerList: some View {
        VStack(alignment: .leading, spacing: 8) {
            if settings.providers.isEmpty {
                EmptyStateView(text: "还没有加载 LLM 配置。")
            } else {
                ForEach(settings.providers) { provider in
                    Button {
                        settings.selectProvider(provider)
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(provider.name)
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(AppTheme.text)
                                Text("\(provider.model) · \(provider.baseUrl)")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.muted)
                                    .lineLimit(1)
                            }
                            Spacer()
                            PillView(text: provider.isActive ? "当前" : (provider.hasApiKey ? "已保存 key" : "缺少 key"), tone: provider.isActive ? .green : (provider.hasApiKey ? .blue : .orange))
                        }
                        .padding(12)
                        .background(Color.white.opacity(provider.id == settings.selectedProviderID ? 0.78 : 0.54), in: RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous)
                                .stroke(provider.id == settings.selectedProviderID ? AppTheme.blue.opacity(0.45) : Color.white.opacity(0.82), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var writingPolicyCard: some View {
        CardView {
            CardHeader(title: "写作默认值", subtitle: "这些设置保留在本机，后续会接入章节生成参数。")
            CardBody {
                LabeledField("目标字数") {
                    SoftTextField("目标字数", text: $targetWords)
                }
                LabeledField("每章最多自然场景") {
                    SoftTextField("每章最多自然场景", text: $scenePolicy)
                }
                LabeledField("新命名角色策略") {
                    SoftPicker("新命名角色策略", selection: $newCharacterPolicy) {
                        Text("默认禁止，除非结构化 Prompt 批准").tag("默认禁止，除非结构化 Prompt 批准")
                        Text("允许但需要基础文件确认").tag("允许但需要基础文件确认")
                    }
                }
            }
        }
    }

    private func binding(_ keyPath: ReferenceWritableKeyPath<ApplicationSettingsStore, String>) -> Binding<String> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { settings[keyPath: keyPath] = $0 }
        )
    }
}

private struct SecureSoftField: View {
    let title: String
    @Binding var text: String

    init(_ title: String, text: Binding<String>) {
        self.title = title
        self._text = text
    }

    var body: some View {
        SecureField(title, text: $text)
            .textFieldStyle(.plain)
            .font(.callout)
            .foregroundStyle(AppTheme.text)
            .padding(10)
            .background(AppTheme.editor, in: RoundedRectangle(cornerRadius: AppTheme.radiusMD, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMD, style: .continuous)
                    .stroke(AppTheme.lineStrong, lineWidth: 1)
            )
    }
}
