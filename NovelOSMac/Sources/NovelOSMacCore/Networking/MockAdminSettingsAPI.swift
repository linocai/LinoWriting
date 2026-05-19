import Foundation

public actor MockAdminSettingsAPI: AdminSettingsAPI {
    private var response = LLMProvidersResponse(
        activeProviderId: "mock",
        providers: [
            LLMProvider(
                id: "mock",
                name: "Mock Provider",
                baseUrl: "https://api.example.com/v1",
                model: "mock-model",
                timeoutSeconds: 60,
                hasApiKey: true,
                isActive: true
            )
        ]
    )

    public init() {}

    public func getLLMProviders() async throws -> LLMProvidersResponse {
        response
    }

    public func upsertLLMProvider(providerID: String, request: LLMProviderUpsert) async throws -> LLMProvidersResponse {
        let provider = LLMProvider(
            id: providerID,
            name: request.name,
            baseUrl: request.baseUrl,
            model: request.model,
            timeoutSeconds: request.timeoutSeconds,
            hasApiKey: request.apiKey?.isEmpty == false,
            isActive: providerID == response.activeProviderId
        )
        response.providers.removeAll { $0.id == providerID }
        response.providers.append(provider)
        response.providers.sort { $0.id < $1.id }
        if response.activeProviderId == nil {
            response.activeProviderId = providerID
        }
        refreshActiveFlags()
        return response
    }

    public func deleteLLMProvider(providerID: String) async throws -> LLMProvidersResponse {
        guard response.providers.count > 1 else {
            throw APIError.httpStatus(409, "At least one LLM provider is required.")
        }
        response.providers.removeAll { $0.id == providerID }
        if response.activeProviderId == providerID {
            response.activeProviderId = response.providers.first?.id
        }
        refreshActiveFlags()
        return response
    }

    public func setActiveLLMProvider(providerID: String) async throws -> LLMProvidersResponse {
        response.activeProviderId = providerID
        refreshActiveFlags()
        return response
    }

    public func testLLMProvider(providerID: String?, prompt: String) async throws -> LLMTestResponse {
        let id = providerID ?? response.activeProviderId ?? "mock"
        return LLMTestResponse(
            ok: true,
            providerId: id,
            model: response.providers.first(where: { $0.id == id })?.model ?? "mock-model",
            message: "ok",
            tokenUsage: ["total_tokens": 2]
        )
    }

    private func refreshActiveFlags() {
        response.providers = response.providers.map { provider in
            var updated = provider
            updated.isActive = provider.id == response.activeProviderId
            return updated
        }
    }
}
