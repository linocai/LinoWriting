import Foundation

public struct UserPromptRequest: Codable, Equatable, Sendable {
    public var prompt: String

    public init(prompt: String) {
        self.prompt = prompt
    }
}

public enum DraftReviewDecision: String, Codable, Equatable, Sendable {
    case revise
    case approve
}

public struct DraftReviewRequest: Codable, Equatable, Sendable {
    public var decision: DraftReviewDecision
    public var feedback: String?

    public init(decision: DraftReviewDecision, feedback: String? = nil) {
        self.decision = decision
        self.feedback = feedback
    }
}
