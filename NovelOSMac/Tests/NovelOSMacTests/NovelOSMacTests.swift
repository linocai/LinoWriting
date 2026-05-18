import Testing
import Foundation
@testable import NovelOSMacCore

@MainActor
@Test func chapterWorkflowProgressesThroughFiveUserActions() async throws {
    let store = ChapterWorkflowStore(api: MockChapterWorkflowAPI())

    #expect(store.currentStep == .promptInput)
    #expect(store.highestUnlockedStep == .promptInput)

    await store.generateStructuredPrompt()
    #expect(store.currentStep == .structuredPromptReview)
    #expect(store.structuredPrompt?.id == "sp_004")

    await store.approveStructuredPromptAndGenerateDraft()
    #expect(store.currentStep == .draftReview)
    #expect(store.draft?.versionNo == 3)

    let approvedForFinal = await store.approveDraftForFinalReview()
    #expect(approvedForFinal)
    #expect(store.currentStep == .finalApproval)

    await store.approveFinalTextAndPreparePatch()
    #expect(store.currentStep == .canonPatchReview)
    #expect(store.canonPatch?.targetCanonVersion == 13)

    await store.confirmCanonPatch()
    #expect(store.chapter.status == .completed)
    #expect(store.novel.currentCanonVersion == 13)
    #expect(store.error == nil)
}

@MainActor
@Test func s0AuditBlocksFinalApproval() async throws {
    let store = ChapterWorkflowStore(api: MockChapterWorkflowAPI())
    await store.generateStructuredPrompt()
    await store.approveStructuredPromptAndGenerateDraft()
    store.injectS0ForTesting()

    let approvedForFinal = await store.approveDraftForFinalReview()

    #expect(!approvedForFinal)
    #expect(store.currentStep == .draftReview)
    #expect(store.finalApprovalBlockedReason != nil)
}

@MainActor
@Test func revisionKeepsUserOnDraftReviewStep() async throws {
    let store = ChapterWorkflowStore(api: MockChapterWorkflowAPI())
    await store.generateStructuredPrompt()
    await store.approveStructuredPromptAndGenerateDraft()

    let previousVersion = try #require(store.draft?.versionNo)
    store.reviewFeedback = "B 再克制一点，旧码头背景再压缩。"
    await store.requestRevision()

    #expect(store.currentStep == .draftReview)
    #expect(store.draft?.versionNo == previousVersion + 1)
    #expect(store.auditSummary?.s0Count == 0)
}

@Test func codableFixturesDecode() throws {
    let novel = try decodeFixture("MockNovel", as: Novel.self)
    let prompt = try decodeFixture("MockStructuredPrompt", as: StructuredPrompt.self)
    let draft = try decodeFixture("MockDraft", as: Draft.self)
    let patch = try decodeFixture("MockCanonPatch", as: CanonUpdatePatch.self)

    #expect(novel.title == "雨夜旧码头")
    #expect(prompt.allowedNamedEntities.count == 6)
    #expect(draft.auditSummary?.s1Count == 2)
    #expect(patch.items.map(\.target).contains(.knowledge))
}

@Test func mockChapterWorkflowAPIRunsExpectedSequence() async throws {
    let api = MockChapterWorkflowAPI()

    try await api.submitUserPrompt(chapterID: "chapter_004", prompt: MockData.promptDraft)
    var prompt = try await api.getStructuredPrompt(chapterID: "chapter_004")
    #expect(prompt.id == "sp_004")

    prompt.chapterGoal += " 加强结尾悬念。"
    let savedPrompt = try await api.updateStructuredPrompt(prompt, chapterID: "chapter_004")
    #expect(savedPrompt.chapterGoal.hasSuffix("加强结尾悬念。"))

    try await api.approveStructuredPrompt(chapterID: "chapter_004")
    try await api.generateDraft(chapterID: "chapter_004")
    let draft = try await api.getLatestDraft(chapterID: "chapter_004")
    #expect(draft.versionNo == 3)

    try await api.reviewDraft(
        chapterID: "chapter_004",
        request: DraftReviewRequest(decision: .revise, feedback: "B 再克制一点")
    )
    let revisedDraft = try await api.getLatestDraft(chapterID: "chapter_004")
    #expect(revisedDraft.versionNo == draft.versionNo + 1)
    #expect(revisedDraft.auditSummary?.s0Count == 0)

    try await api.reviewDraft(chapterID: "chapter_004", request: DraftReviewRequest(decision: .approve))
    try await api.approveFinalText(chapterID: "chapter_004")
    var patch = try await api.getCanonUpdatePatch(chapterID: "chapter_004")
    patch.items[0].proposedAction = .modify
    let savedPatch = try await api.updateCanonUpdatePatch(patch, chapterID: "chapter_004")
    #expect(savedPatch.items[0].proposedAction == .modify)
    try await api.confirmCanonUpdatePatch(chapterID: "chapter_004")
}

@Test func endpointConstructsChapterWorkflowRequests() throws {
    let promptEndpoint = try Endpoint.submitUserPrompt(chapterID: "chapter_004", prompt: "下一章写旧码头。")
    #expect(promptEndpoint.method == .post)
    #expect(promptEndpoint.path == "/api/chapters/chapter_004/user-prompt")
    let promptBody = try decodeBody(promptEndpoint, as: UserPromptRequest.self)
    #expect(promptBody.prompt == "下一章写旧码头。")

    let reviewEndpoint = try Endpoint.reviewDraft(
        chapterID: "chapter_004",
        request: DraftReviewRequest(decision: .revise, feedback: "B 更克制。")
    )
    let reviewBody = try decodeBody(reviewEndpoint, as: DraftReviewRequest.self)
    #expect(reviewEndpoint.path == "/api/chapters/chapter_004/draft/review")
    #expect(reviewBody.decision == .revise)
    #expect(reviewBody.feedback == "B 更克制。")

    let updatePromptEndpoint = try Endpoint.updateStructuredPrompt(chapterID: "chapter_004", prompt: MockData.structuredPrompt)
    let updatePromptJSON = String(data: try #require(updatePromptEndpoint.body), encoding: .utf8) ?? ""
    #expect(updatePromptEndpoint.method == .patch)
    #expect(updatePromptJSON.contains("chapter_goal"))
    #expect(updatePromptJSON.contains("allowed_named_entities"))

    let request = try Endpoint.getLatestDraft(chapterID: "chapter_004")
        .urlRequest(baseURL: try #require(URL(string: "https://api.example.com/v1")))
    #expect(request.httpMethod == "GET")
    #expect(request.url?.absoluteString == "https://api.example.com/v1/api/chapters/chapter_004/draft/latest")
}

@Test func liveSnakeCaseFixturesDecode() throws {
    let prompt = try decodeLiveFixture("LiveStructuredPromptSnake", as: StructuredPrompt.self)
    let draft = try decodeLiveFixture("LiveDraftSnake", as: Draft.self)
    let patch = try decodeLiveFixture("LiveCanonPatchSnake", as: CanonUpdatePatch.self)

    #expect(prompt.chapterGoal.contains("怀疑"))
    #expect(prompt.allowedNamedEntities.last?.mentionBudget == 1)
    #expect(draft.auditSummary?.illegalNamedEntityCount == 0)
    #expect(patch.targetCanonVersion == 13)
    #expect(patch.items[0].proposedAction == .accept)
}

private func decodeFixture<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(T.self, from: data)
}

private func decodeLiveFixture<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
    let data = try Data(contentsOf: url)
    return try APIJSONCoding.makeDecoder().decode(T.self, from: data)
}

private func decodeBody<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) throws -> T {
    let body = try #require(endpoint.body)
    return try APIJSONCoding.makeDecoder().decode(T.self, from: body)
}
