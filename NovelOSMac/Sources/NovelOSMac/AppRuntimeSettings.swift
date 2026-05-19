import Foundation
import NovelOSMacCore
import Observation
import Security

enum AppRuntimeSettings {
    static let defaultBackendURLString = "http://127.0.0.1:7773"
    private static let backendURLKey = "NovelOSBackendURL"

    static var backendURLString: String {
        get {
            let saved = UserDefaults.standard.string(forKey: backendURLKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return saved?.isEmpty == false ? saved! : defaultBackendURLString
        }
        set {
            UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: backendURLKey)
        }
    }

    static var backendURL: URL {
        URL(string: backendURLString) ?? URL(string: defaultBackendURLString)!
    }

    static var useMockAPI: Bool {
        ProcessInfo.processInfo.environment["NOVEL_OS_USE_MOCK_API"] == "true"
    }
}

enum AppCredentials {
    private static let service = "top.neluvee.write.novelos"
    private static let ownerAccount = "owner-token"

    static func ownerToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: ownerAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func saveOwnerToken(_ token: String) throws {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: ownerAccount
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: ownerAccount,
            kSecValueData as String: Data(trimmed.utf8)
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError(status: status)
        }
    }
}

struct KeychainError: LocalizedError {
    let status: OSStatus

    var errorDescription: String? {
        "Keychain 保存失败：\(status)"
    }
}

@MainActor
@Observable
final class ApplicationSettingsStore {
    @ObservationIgnored private let api: any AdminSettingsAPI

    var backendURLString: String = AppRuntimeSettings.backendURLString
    var ownerTokenInput: String = ""
    var ownerTokenConfigured: Bool = AppCredentials.ownerToken() != nil
    var providers: [LLMProvider] = []
    var activeProviderID: String?
    var selectedProviderID: String = ""
    var providerName: String = ""
    var providerBaseURL: String = "https://api.openai.com/v1"
    var providerModel: String = "gpt-4.1-mini"
    var providerTimeout: String = "60"
    var providerAPIKey: String = ""
    var isLoading: Bool = false
    var statusMessage: String?
    var error: APIError?

    init(api: any AdminSettingsAPI = MockAdminSettingsAPI()) {
        self.api = api
    }

    func saveConnectionSettings() -> Bool {
        let trimmedURL = backendURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedURL), url.scheme != nil, url.host != nil else {
            statusMessage = "后端地址无效。"
            return false
        }

        AppRuntimeSettings.backendURLString = trimmedURL
        do {
            try AppCredentials.saveOwnerToken(ownerTokenInput)
            if !ownerTokenInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ownerTokenConfigured = true
                ownerTokenInput = ""
            }
            statusMessage = "连接设置已保存。"
            return true
        } catch {
            statusMessage = error.localizedDescription
            return false
        }
    }

    func loadLLMProviders() async {
        guard saveConnectionSettings() else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            apply(try await api.getLLMProviders())
            statusMessage = "LLM 配置已加载。"
        } catch {
            handle(error)
        }
    }

    func selectProvider(_ provider: LLMProvider) {
        selectedProviderID = provider.id
        providerName = provider.name
        providerBaseURL = provider.baseUrl
        providerModel = provider.model
        providerTimeout = String(format: "%.0f", provider.timeoutSeconds)
        providerAPIKey = ""
    }

    func startNewProvider() {
        selectedProviderID = ""
        providerName = ""
        providerBaseURL = "https://api.openai.com/v1"
        providerModel = ""
        providerTimeout = "60"
        providerAPIKey = ""
    }

    func saveProvider() async {
        guard saveConnectionSettings() else { return }
        let providerID = selectedProviderID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !providerID.isEmpty else {
            statusMessage = "请填写 Provider ID。"
            return
        }
        let timeout = Double(providerTimeout.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 60
        let key = providerAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let response = try await api.upsertLLMProvider(
                providerID: providerID,
                request: LLMProviderUpsert(
                    name: providerName,
                    baseUrl: providerBaseURL,
                    model: providerModel,
                    apiKey: key.isEmpty ? nil : key,
                    timeoutSeconds: timeout
                )
            )
            apply(response)
            providerAPIKey = ""
            statusMessage = "LLM Provider 已保存。"
        } catch {
            handle(error)
        }
    }

    func setActiveProvider() async {
        guard saveConnectionSettings() else { return }
        let providerID = selectedProviderID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !providerID.isEmpty else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            apply(try await api.setActiveLLMProvider(providerID: providerID))
            statusMessage = "当前模型已切换。"
        } catch {
            handle(error)
        }
    }

    func testProvider() async {
        guard saveConnectionSettings() else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let response = try await api.testLLMProvider(
                providerID: selectedProviderID.isEmpty ? nil : selectedProviderID,
                prompt: "请回复 OK"
            )
            statusMessage = response.ok ? "连接成功：\(response.model)" : "连接失败：\(response.message)"
        } catch {
            handle(error)
        }
    }

    private func apply(_ response: LLMProvidersResponse) {
        providers = response.providers
        activeProviderID = response.activeProviderId
        if let selected = providers.first(where: { $0.id == selectedProviderID }) {
            selectProvider(selected)
        } else if let active = providers.first(where: { $0.id == response.activeProviderId }) ?? providers.first {
            selectProvider(active)
        }
    }

    private func handle(_ error: Error) {
        let apiError = error as? APIError ?? APIError.transport(String(describing: error))
        self.error = apiError
        statusMessage = apiError.userMessage
    }
}
