import Foundation

public enum HTTPMethod: String, Codable, Equatable, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

public struct Endpoint: Equatable, Sendable {
    public var method: HTTPMethod
    public var path: String
    public var body: Data?
    public var headers: [String: String]

    public init(method: HTTPMethod, path: String, body: Data? = nil, headers: [String: String] = [:]) {
        self.method = method
        self.path = path
        self.body = body
        self.headers = headers
    }

    public func urlRequest(baseURL: URL) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidBaseURL(baseURL.absoluteString)
        }

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let endpointPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = "/" + [basePath, endpointPath].filter { !$0.isEmpty }.joined(separator: "/")

        guard let url = components.url else {
            throw APIError.invalidBaseURL(baseURL.absoluteString)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        return request
    }
}

public extension Endpoint {
    static func listNovels() -> Endpoint {
        Endpoint(method: .get, path: "/api/novels")
    }

    static func createNovel(_ request: NovelCreateRequest) throws -> Endpoint {
        try json(.post, "/api/novels", request)
    }

    static func createChapter(novelID: String, request: ChapterCreateRequest) throws -> Endpoint {
        try json(.post, "/api/novels/\(novelID)/chapters", request)
    }

    static func importFirstThreeChapters(novelID: String, request: BootstrapImportRequest) throws -> Endpoint {
        try json(.post, "/api/novels/\(novelID)/bootstrap/import-first-three-chapters", request)
    }

    static func getBootstrapStatus(novelID: String) -> Endpoint {
        Endpoint(method: .get, path: "/api/novels/\(novelID)/bootstrap/status")
    }

    static func analyzeBootstrap(novelID: String) -> Endpoint {
        Endpoint(method: .post, path: "/api/novels/\(novelID)/bootstrap/analyze")
    }

    static func getLLMProviders() -> Endpoint {
        Endpoint(method: .get, path: "/api/admin/llm/providers")
    }

    static func upsertLLMProvider(providerID: String, request: LLMProviderUpsert) throws -> Endpoint {
        try json(.put, "/api/admin/llm/providers/\(providerID)", request)
    }

    static func deleteLLMProvider(providerID: String) -> Endpoint {
        Endpoint(method: .delete, path: "/api/admin/llm/providers/\(providerID)")
    }

    static func setActiveLLMProvider(providerID: String) throws -> Endpoint {
        try json(.post, "/api/admin/llm/active-provider", ActiveLLMProviderRequest(providerId: providerID))
    }

    static func testLLMProvider(providerID: String?, prompt: String) throws -> Endpoint {
        try json(.post, "/api/admin/llm/test", LLMTestRequest(providerId: providerID, prompt: prompt))
    }

    static func listChapters(novelID: String) -> Endpoint {
        Endpoint(method: .get, path: "/api/novels/\(novelID)/chapters")
    }

    static func getWorldBibleSections(novelID: String) -> Endpoint {
        Endpoint(method: .get, path: "/api/novels/\(novelID)/world-bible")
    }

    static func createWorldBibleSection(novelID: String, section: WorldBibleSection) throws -> Endpoint {
        try json(.post, "/api/novels/\(novelID)/world-bible/sections", section)
    }

    static func updateWorldBibleSection(novelID: String, section: WorldBibleSection) throws -> Endpoint {
        try json(.patch, "/api/novels/\(novelID)/world-bible/sections/\(section.id)", section)
    }

    static func deleteWorldBibleSection(novelID: String, sectionID: String) -> Endpoint {
        Endpoint(method: .delete, path: "/api/novels/\(novelID)/world-bible/sections/\(sectionID)")
    }

    static func getCharacterCards(novelID: String) -> Endpoint {
        Endpoint(method: .get, path: "/api/novels/\(novelID)/characters")
    }

    static func createCharacterCard(novelID: String, card: CharacterCard) throws -> Endpoint {
        try json(.post, "/api/novels/\(novelID)/characters", card)
    }

    static func updateCharacterCard(novelID: String, card: CharacterCard) throws -> Endpoint {
        try json(.patch, "/api/novels/\(novelID)/characters/\(card.id)", card)
    }

    static func getMemoryFacts(novelID: String) -> Endpoint {
        Endpoint(method: .get, path: "/api/novels/\(novelID)/memory")
    }

    static func createMemoryFact(novelID: String, fact: MemoryFact) throws -> Endpoint {
        try json(.post, "/api/novels/\(novelID)/memory", fact)
    }

    static func updateMemoryFact(novelID: String, fact: MemoryFact) throws -> Endpoint {
        try json(.patch, "/api/novels/\(novelID)/memory/\(fact.id)", fact)
    }

    static func deleteMemoryFact(novelID: String, factID: String) -> Endpoint {
        Endpoint(method: .delete, path: "/api/novels/\(novelID)/memory/\(factID)")
    }

    static func getKnowledgeMatrixEntries(novelID: String) -> Endpoint {
        Endpoint(method: .get, path: "/api/novels/\(novelID)/knowledge-matrix")
    }

    static func createKnowledgeMatrixEntry(novelID: String, entry: KnowledgeMatrixEntry) throws -> Endpoint {
        try json(.post, "/api/novels/\(novelID)/knowledge-matrix", entry)
    }

    static func updateKnowledgeMatrixEntry(novelID: String, entry: KnowledgeMatrixEntry) throws -> Endpoint {
        try json(.patch, "/api/novels/\(novelID)/knowledge-matrix/\(entry.id)", entry)
    }

    static func deleteKnowledgeMatrixEntry(novelID: String, entryID: String) -> Endpoint {
        Endpoint(method: .delete, path: "/api/novels/\(novelID)/knowledge-matrix/\(entryID)")
    }

    static func submitUserPrompt(chapterID: String, prompt: String) throws -> Endpoint {
        try json(.post, "/api/chapters/\(chapterID)/user-prompt", UserPromptRequest(prompt: prompt))
    }

    static func getStructuredPrompt(chapterID: String) -> Endpoint {
        Endpoint(method: .get, path: "/api/chapters/\(chapterID)/structured-prompt")
    }

    static func updateStructuredPrompt(chapterID: String, prompt: StructuredPrompt) throws -> Endpoint {
        try json(.patch, "/api/chapters/\(chapterID)/structured-prompt", prompt)
    }

    static func approveStructuredPrompt(chapterID: String) -> Endpoint {
        Endpoint(method: .post, path: "/api/chapters/\(chapterID)/structured-prompt/approve")
    }

    static func generateDraft(chapterID: String) -> Endpoint {
        Endpoint(method: .post, path: "/api/chapters/\(chapterID)/draft/generate")
    }

    static func generateDraftStream(chapterID: String) -> Endpoint {
        Endpoint(method: .post, path: "/api/chapters/\(chapterID)/draft/generate/stream", headers: ["Accept": "text/event-stream"])
    }

    static func getLatestDraft(chapterID: String) -> Endpoint {
        Endpoint(method: .get, path: "/api/chapters/\(chapterID)/draft/latest")
    }

    static func getAgentRuns(chapterID: String) -> Endpoint {
        Endpoint(method: .get, path: "/api/chapters/\(chapterID)/agent-runs")
    }

    static func reviewDraft(chapterID: String, request: DraftReviewRequest) throws -> Endpoint {
        try json(.post, "/api/chapters/\(chapterID)/draft/review", request)
    }

    static func approveFinalText(chapterID: String) -> Endpoint {
        Endpoint(method: .post, path: "/api/chapters/\(chapterID)/approve-final-text")
    }

    static func getCanonUpdatePatch(chapterID: String) -> Endpoint {
        Endpoint(method: .get, path: "/api/chapters/\(chapterID)/canon-update-patch")
    }

    static func updateCanonUpdatePatch(chapterID: String, patch: CanonUpdatePatch) throws -> Endpoint {
        try json(.patch, "/api/chapters/\(chapterID)/canon-update-patch", patch)
    }

    static func confirmCanonUpdatePatch(chapterID: String) -> Endpoint {
        Endpoint(method: .post, path: "/api/chapters/\(chapterID)/canon-update-patch/confirm")
    }

    private static func json<T: Encodable>(_ method: HTTPMethod, _ path: String, _ body: T) throws -> Endpoint {
        do {
            let data = try APIJSONCoding.makeEncoder().encode(body)
            return Endpoint(method: method, path: path, body: data)
        } catch {
            throw APIError.requestEncodingFailed(String(describing: error))
        }
    }
}
