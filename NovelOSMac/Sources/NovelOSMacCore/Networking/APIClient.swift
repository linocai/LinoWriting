import Foundation

public actor APIClient: ChapterWorkflowAPI, BaseDocumentsAPI, KnowledgeMatrixAPI, AdminSettingsAPI, NovelLibraryAPI {
    private let baseURLProvider: @Sendable () -> URL
    private let ownerTokenProvider: @Sendable () -> String?
    private let session: URLSession

    public init(baseURL: URL, ownerToken: String? = nil, session: URLSession = .shared) {
        self.baseURLProvider = { baseURL }
        self.ownerTokenProvider = { ownerToken }
        self.session = session
    }

    public init(
        baseURLProvider: @escaping @Sendable () -> URL,
        ownerTokenProvider: @escaping @Sendable () -> String? = { nil },
        session: URLSession = .shared
    ) {
        self.baseURLProvider = baseURLProvider
        self.ownerTokenProvider = ownerTokenProvider
        self.session = session
    }

    public func getLLMProviders() async throws -> LLMProvidersResponse {
        try await perform(Endpoint.getLLMProviders())
    }

    public func upsertLLMProvider(providerID: String, request: LLMProviderUpsert) async throws -> LLMProvidersResponse {
        try await perform(try Endpoint.upsertLLMProvider(providerID: providerID, request: request))
    }

    public func deleteLLMProvider(providerID: String) async throws -> LLMProvidersResponse {
        try await perform(Endpoint.deleteLLMProvider(providerID: providerID))
    }

    public func setActiveLLMProvider(providerID: String) async throws -> LLMProvidersResponse {
        try await perform(try Endpoint.setActiveLLMProvider(providerID: providerID))
    }

    public func testLLMProvider(providerID: String?, prompt: String = "ping") async throws -> LLMTestResponse {
        try await perform(try Endpoint.testLLMProvider(providerID: providerID, prompt: prompt))
    }

    public func listNovels() async throws -> [Novel] {
        try await perform(Endpoint.listNovels())
    }

    public func createNovel(_ request: NovelCreateRequest) async throws -> Novel {
        try await perform(try Endpoint.createNovel(request))
    }

    public func createChapter(novelID: String, request: ChapterCreateRequest) async throws -> Chapter {
        try await perform(try Endpoint.createChapter(novelID: novelID, request: request))
    }

    public func importFirstThreeChapters(novelID: String, request: BootstrapImportRequest) async throws -> NovelBootstrapStatus {
        try await perform(try Endpoint.importFirstThreeChapters(novelID: novelID, request: request))
    }

    public func getBootstrapStatus(novelID: String) async throws -> NovelBootstrapStatus {
        try await perform(Endpoint.getBootstrapStatus(novelID: novelID))
    }

    public func analyzeBootstrap(novelID: String) async throws -> BootstrapAnalyzeResult {
        try await perform(Endpoint.analyzeBootstrap(novelID: novelID))
    }

    public func listChapters(novelID: String) async throws -> [Chapter] {
        try await perform(Endpoint.listChapters(novelID: novelID))
    }

    public func submitUserPrompt(chapterID: String, prompt: String) async throws {
        try await perform(try Endpoint.submitUserPrompt(chapterID: chapterID, prompt: prompt))
    }

    public func getStructuredPrompt(chapterID: String) async throws -> StructuredPrompt {
        try await perform(Endpoint.getStructuredPrompt(chapterID: chapterID))
    }

    public func updateStructuredPrompt(_ prompt: StructuredPrompt, chapterID: String) async throws -> StructuredPrompt {
        try await perform(try Endpoint.updateStructuredPrompt(chapterID: chapterID, prompt: prompt))
    }

    public func approveStructuredPrompt(chapterID: String) async throws {
        try await perform(Endpoint.approveStructuredPrompt(chapterID: chapterID))
    }

    public func generateDraft(chapterID: String) async throws {
        try await perform(Endpoint.generateDraft(chapterID: chapterID))
    }

    public func generateDraftStream(chapterID: String, onEvent: @MainActor @Sendable @escaping (DraftStreamEvent) async -> Void) async throws {
        var request = try Endpoint.generateDraftStream(chapterID: chapterID).urlRequest(baseURL: baseURLProvider())
        if let ownerToken = ownerTokenProvider()?.trimmingCharacters(in: .whitespacesAndNewlines), !ownerToken.isEmpty {
            request.setValue(ownerToken, forHTTPHeaderField: "X-NovelOS-Owner-Token")
        }

        do {
            let (bytes, response) = try await session.bytes(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            guard 200..<300 ~= httpResponse.statusCode else {
                throw APIError.httpStatus(httpResponse.statusCode, "")
            }
            var dataLines: [String] = []
            for try await line in bytes.lines {
                if line.isEmpty {
                    try await emitStreamEvent(from: dataLines, onEvent: onEvent)
                    dataLines.removeAll()
                } else if line.hasPrefix("data:") {
                    dataLines.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
                }
            }
            try await emitStreamEvent(from: dataLines, onEvent: onEvent)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport(String(describing: error))
        }
    }

    public func getLatestDraft(chapterID: String) async throws -> Draft {
        try await perform(Endpoint.getLatestDraft(chapterID: chapterID))
    }

    public func getAgentRuns(chapterID: String) async throws -> [AgentRun] {
        try await perform(Endpoint.getAgentRuns(chapterID: chapterID))
    }

    public func reviewDraft(chapterID: String, request: DraftReviewRequest) async throws {
        try await perform(try Endpoint.reviewDraft(chapterID: chapterID, request: request))
    }

    public func approveFinalText(chapterID: String) async throws {
        try await perform(Endpoint.approveFinalText(chapterID: chapterID))
    }

    public func getCanonUpdatePatch(chapterID: String) async throws -> CanonUpdatePatch {
        try await perform(Endpoint.getCanonUpdatePatch(chapterID: chapterID))
    }

    public func updateCanonUpdatePatch(_ patch: CanonUpdatePatch, chapterID: String) async throws -> CanonUpdatePatch {
        try await perform(try Endpoint.updateCanonUpdatePatch(chapterID: chapterID, patch: patch))
    }

    public func confirmCanonUpdatePatch(chapterID: String) async throws {
        try await perform(Endpoint.confirmCanonUpdatePatch(chapterID: chapterID))
    }

    public func getWorldBibleSections(novelID: String) async throws -> [WorldBibleSection] {
        try await perform(Endpoint.getWorldBibleSections(novelID: novelID))
    }

    public func createWorldBibleSection(_ section: WorldBibleSection, novelID: String) async throws -> WorldBibleSection {
        try await perform(try Endpoint.createWorldBibleSection(novelID: novelID, section: section))
    }

    public func updateWorldBibleSection(_ section: WorldBibleSection, novelID: String) async throws -> WorldBibleSection {
        try await perform(try Endpoint.updateWorldBibleSection(novelID: novelID, section: section))
    }

    public func deleteWorldBibleSection(sectionID: String, novelID: String) async throws {
        try await perform(Endpoint.deleteWorldBibleSection(novelID: novelID, sectionID: sectionID))
    }

    public func getCharacterCards(novelID: String) async throws -> [CharacterCard] {
        try await perform(Endpoint.getCharacterCards(novelID: novelID))
    }

    public func createCharacterCard(_ card: CharacterCard, novelID: String) async throws -> CharacterCard {
        try await perform(try Endpoint.createCharacterCard(novelID: novelID, card: card))
    }

    public func updateCharacterCard(_ card: CharacterCard, novelID: String) async throws -> CharacterCard {
        try await perform(try Endpoint.updateCharacterCard(novelID: novelID, card: card))
    }

    public func getMemoryFacts(novelID: String) async throws -> [MemoryFact] {
        try await perform(Endpoint.getMemoryFacts(novelID: novelID))
    }

    public func createMemoryFact(_ fact: MemoryFact, novelID: String) async throws -> MemoryFact {
        try await perform(try Endpoint.createMemoryFact(novelID: novelID, fact: fact))
    }

    public func updateMemoryFact(_ fact: MemoryFact, novelID: String) async throws -> MemoryFact {
        try await perform(try Endpoint.updateMemoryFact(novelID: novelID, fact: fact))
    }

    public func deleteMemoryFact(factID: String, novelID: String) async throws {
        try await perform(Endpoint.deleteMemoryFact(novelID: novelID, factID: factID))
    }

    public func getKnowledgeMatrixEntries(novelID: String) async throws -> [KnowledgeMatrixEntry] {
        try await perform(Endpoint.getKnowledgeMatrixEntries(novelID: novelID))
    }

    public func createKnowledgeMatrixEntry(_ entry: KnowledgeMatrixEntry, novelID: String) async throws -> KnowledgeMatrixEntry {
        try await perform(try Endpoint.createKnowledgeMatrixEntry(novelID: novelID, entry: entry))
    }

    public func updateKnowledgeMatrixEntry(_ entry: KnowledgeMatrixEntry, novelID: String) async throws -> KnowledgeMatrixEntry {
        try await perform(try Endpoint.updateKnowledgeMatrixEntry(novelID: novelID, entry: entry))
    }

    public func deleteKnowledgeMatrixEntry(entryID: String, novelID: String) async throws {
        try await perform(Endpoint.deleteKnowledgeMatrixEntry(novelID: novelID, entryID: entryID))
    }

    private func perform(_ endpoint: Endpoint) async throws {
        _ = try await data(for: endpoint)
    }

    private func perform<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let data = try await data(for: endpoint)
        do {
            return try APIJSONCoding.makeDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingFailed(String(describing: error))
        }
    }

    private func data(for endpoint: Endpoint) async throws -> Data {
        var request = try endpoint.urlRequest(baseURL: baseURLProvider())
        if let ownerToken = ownerTokenProvider()?.trimmingCharacters(in: .whitespacesAndNewlines), !ownerToken.isEmpty {
            request.setValue(ownerToken, forHTTPHeaderField: "X-NovelOS-Owner-Token")
        }
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            guard 200..<300 ~= httpResponse.statusCode else {
                let body = String(data: data, encoding: .utf8) ?? ""
                throw APIError.httpStatus(httpResponse.statusCode, body)
            }
            return data
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport(String(describing: error))
        }
    }

    private func emitStreamEvent(
        from dataLines: [String],
        onEvent: @MainActor @Sendable @escaping (DraftStreamEvent) async -> Void
    ) async throws {
        guard !dataLines.isEmpty else { return }
        let payload = dataLines.joined(separator: "\n")
        guard let data = payload.data(using: .utf8) else {
            throw APIError.decodingFailed("SSE payload is not UTF-8.")
        }
        do {
            let event = try APIJSONCoding.makeDecoder().decode(DraftStreamEvent.self, from: data)
            await onEvent(event)
        } catch {
            throw APIError.decodingFailed(String(describing: error))
        }
    }
}
