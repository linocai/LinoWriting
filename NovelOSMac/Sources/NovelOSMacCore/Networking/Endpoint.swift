import Foundation

public enum HTTPMethod: String, Codable, Equatable, Sendable {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
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

    static func getLatestDraft(chapterID: String) -> Endpoint {
        Endpoint(method: .get, path: "/api/chapters/\(chapterID)/draft/latest")
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
