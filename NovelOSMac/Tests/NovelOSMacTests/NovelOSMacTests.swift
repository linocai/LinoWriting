import Testing
import Foundation
@testable import NovelOSMacCore

@MainActor
@Test func chapterWorkflowProgressesThroughFiveUserActions() async throws {
    let store = ChapterWorkflowStore()

    #expect(store.currentStep == .promptInput)
    #expect(store.highestUnlockedStep == .promptInput)

    store.generateStructuredPrompt()
    #expect(store.currentStep == .structuredPromptReview)
    #expect(store.structuredPrompt?.id == "sp_004")

    store.approveStructuredPromptAndGenerateDraft()
    #expect(store.currentStep == .draftReview)
    #expect(store.draft?.versionNo == 3)

    let approvedForFinal = store.approveDraftForFinalReview()
    #expect(approvedForFinal)
    #expect(store.currentStep == .finalApproval)

    store.approveFinalTextAndPreparePatch()
    #expect(store.currentStep == .canonPatchReview)
    #expect(store.canonPatch?.targetCanonVersion == 13)

    store.confirmCanonPatch()
    #expect(store.chapter.status == .completed)
    #expect(store.novel.currentCanonVersion == 13)
}

@MainActor
@Test func s0AuditBlocksFinalApproval() async throws {
    let store = ChapterWorkflowStore()
    store.generateStructuredPrompt()
    store.approveStructuredPromptAndGenerateDraft()
    store.injectS0ForTesting()

    let approvedForFinal = store.approveDraftForFinalReview()

    #expect(!approvedForFinal)
    #expect(store.currentStep == .draftReview)
    #expect(store.finalApprovalBlockedReason != nil)
}

@MainActor
@Test func revisionKeepsUserOnDraftReviewStep() async throws {
    let store = ChapterWorkflowStore()
    store.generateStructuredPrompt()
    store.approveStructuredPromptAndGenerateDraft()

    let previousVersion = try #require(store.draft?.versionNo)
    store.reviewFeedback = "B 再克制一点，旧码头背景再压缩。"
    store.requestRevision()

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

private func decodeFixture<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(T.self, from: data)
}
