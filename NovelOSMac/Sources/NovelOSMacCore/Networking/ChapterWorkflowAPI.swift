import Foundation

public protocol ChapterWorkflowAPI: Sendable {
    func listChapters(novelID: String) async throws -> [Chapter]
    func submitUserPrompt(chapterID: String, prompt: String) async throws
    func getStructuredPrompt(chapterID: String) async throws -> StructuredPrompt
    func updateStructuredPrompt(_ prompt: StructuredPrompt, chapterID: String) async throws -> StructuredPrompt
    func approveStructuredPrompt(chapterID: String) async throws
    func generateDraft(chapterID: String) async throws
    func generateDraftStream(chapterID: String, onEvent: @MainActor @Sendable @escaping (DraftStreamEvent) async -> Void) async throws
    func getLatestDraft(chapterID: String) async throws -> Draft
    func getAgentRuns(chapterID: String) async throws -> [AgentRun]
    func reviewDraft(chapterID: String, request: DraftReviewRequest) async throws
    func approveFinalText(chapterID: String) async throws
    func getCanonUpdatePatch(chapterID: String) async throws -> CanonUpdatePatch
    func updateCanonUpdatePatch(_ patch: CanonUpdatePatch, chapterID: String) async throws -> CanonUpdatePatch
    func confirmCanonUpdatePatch(chapterID: String) async throws
}
