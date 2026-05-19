import Foundation

public protocol AdminSettingsAPI: Sendable {
    func getLLMProviders() async throws -> LLMProvidersResponse
    func upsertLLMProvider(providerID: String, request: LLMProviderUpsert) async throws -> LLMProvidersResponse
    func deleteLLMProvider(providerID: String) async throws -> LLMProvidersResponse
    func setActiveLLMProvider(providerID: String) async throws -> LLMProvidersResponse
    func testLLMProvider(providerID: String?, prompt: String) async throws -> LLMTestResponse
}
