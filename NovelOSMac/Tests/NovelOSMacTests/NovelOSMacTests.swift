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

@MainActor
@Test func chapterStoreLoadsReadableImportedChapters() async throws {
    let store = ChapterWorkflowStore(api: MockChapterWorkflowAPI())

    await store.loadReadableChapters()

    #expect(store.chapters.map(\.chapterNo) == [1, 2, 3, 4])
    #expect(store.chapterDrafts["chapter_001"]?.text.contains("没有署名的邮件") == true)
    #expect(store.selectedReadableChapterID == "chapter_001")
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

    let chapters = try await api.listChapters(novelID: "novel_001")
    #expect(chapters.map(\.chapterNo) == [1, 2, 3, 4])
    let importedDraft = try await api.getLatestDraft(chapterID: "chapter_001")
    #expect(importedDraft.text.contains("没有署名的邮件"))

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

    let listRequest = Endpoint.listChapters(novelID: "novel_001")
    #expect(listRequest.method == .get)
    #expect(listRequest.path == "/api/novels/novel_001/chapters")

    let providerEndpoint = try Endpoint.upsertLLMProvider(
        providerID: "deepseek",
        request: LLMProviderUpsert(
            name: "DeepSeek",
            baseUrl: "https://api.deepseek.com/v1",
            model: "deepseek-chat",
            apiKey: "secret",
            timeoutSeconds: 45
        )
    )
    #expect(providerEndpoint.method == .put)
    #expect(providerEndpoint.path == "/api/admin/llm/providers/deepseek")
    let providerJSON = String(data: try #require(providerEndpoint.body), encoding: .utf8) ?? ""
    #expect(providerJSON.contains("base_url"))
    #expect(providerJSON.contains("api_key"))
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

@MainActor
@Test func baseDocumentsStoreLoadsCreatesSavesAndDeletesBackendAlignedResources() async throws {
    let api = MockBaseDocumentsAPI()
    let store = BaseDocumentsStore(api: api)

    await store.loadDocuments(force: true)
    #expect(store.worldBibleSections.count == MockData.worldBibleSections.count)
    #expect(store.characterCards.count == MockData.characterCards.count)
    #expect(store.memoryFacts.count == MockData.memoryFacts.count)

    await store.addWorldBibleSection()
    await store.addCharacter()
    await store.addMemoryFact()
    #expect(store.worldBibleSections.count == MockData.worldBibleSections.count + 1)
    #expect(store.characterCards.count == MockData.characterCards.count + 1)
    #expect(store.memoryFacts.count == MockData.memoryFacts.count + 1)

    let sectionID = try #require(store.worldBibleSections.last?.id)
    store.worldBibleSections[store.worldBibleSections.count - 1].title = "测试 Section"
    let characterID = try #require(store.characterCards.last?.id)
    store.characterCards[store.characterCards.count - 1].name = "测试人物"
    store.addRelationship(to: characterID)
    store.characterCards[store.characterCards.count - 1].currentState = "测试人物状态"
    let factID = try #require(store.memoryFacts.last?.id)
    store.memoryFacts[store.memoryFacts.count - 1].summary = "测试事实"
    await store.saveChanges()
    #expect(store.statusMessage == "基础文件已保存，检索索引已更新。")
    #expect(store.characterCards.last?.relationships.count == 1)

    await store.deleteWorldBibleSection(id: sectionID)
    await store.deleteMemoryFact(id: factID)
    #expect(!store.worldBibleSections.contains(where: { $0.id == sectionID }))
    #expect(store.characterCards.contains(where: { $0.id == characterID }))
    #expect(!store.memoryFacts.contains(where: { $0.id == factID }))
}

@Test func mockBaseDocumentsAPIRoundTripsResources() async throws {
    let api = MockBaseDocumentsAPI(worldBibleSections: [], characterCards: [], memoryFacts: [])
    let novelID = MockData.novel.id

    let section = try await api.createWorldBibleSection(MockData.worldBibleSections[0], novelID: novelID)
    var sections = try await api.getWorldBibleSections(novelID: novelID)
    #expect(sections.map(\.id) == [section.id])
    var updatedSection = section
    updatedSection.title = "更新后的 Section"
    _ = try await api.updateWorldBibleSection(updatedSection, novelID: novelID)
    sections = try await api.getWorldBibleSections(novelID: novelID)
    #expect(sections[0].title == "更新后的 Section")
    try await api.deleteWorldBibleSection(sectionID: section.id, novelID: novelID)
    #expect(try await api.getWorldBibleSections(novelID: novelID) == [])

    let character = try await api.createCharacterCard(MockData.characterCards[0], novelID: novelID)
    var updatedCharacter = character
    updatedCharacter.currentState = "已更新"
    _ = try await api.updateCharacterCard(updatedCharacter, novelID: novelID)
    #expect(try await api.getCharacterCards(novelID: novelID).first?.currentState == "已更新")

    let fact = try await api.createMemoryFact(MockData.memoryFacts[0], novelID: novelID)
    var updatedFact = fact
    updatedFact.summary = "已更新事实"
    _ = try await api.updateMemoryFact(updatedFact, novelID: novelID)
    #expect(try await api.getMemoryFacts(novelID: novelID).first?.summary == "已更新事实")
    try await api.deleteMemoryFact(factID: fact.id, novelID: novelID)
    #expect(try await api.getMemoryFacts(novelID: novelID).isEmpty)
}

@Test func baseDocumentEndpointsConstructExpectedRequests() throws {
    let novelID = "novel_001"

    let worldGet = Endpoint.getWorldBibleSections(novelID: novelID)
    #expect(worldGet.method == .get)
    #expect(worldGet.path == "/api/novels/novel_001/world-bible")

    let worldPatch = try Endpoint.updateWorldBibleSection(novelID: novelID, section: MockData.worldBibleSections[0])
    #expect(worldPatch.method == .patch)
    #expect(worldPatch.path == "/api/novels/novel_001/world-bible/sections/wb_style")
    let worldPatchJSON = String(data: try #require(worldPatch.body), encoding: .utf8) ?? ""
    #expect(worldPatchJSON.contains("activation_policy"))

    let characterPost = try Endpoint.createCharacterCard(novelID: novelID, card: MockData.characterCards[0])
    #expect(characterPost.method == .post)
    #expect(characterPost.path == "/api/novels/novel_001/characters")
    let characterJSON = String(data: try #require(characterPost.body), encoding: .utf8) ?? ""
    #expect(characterJSON.contains("stable_traits"))
    #expect(characterJSON.contains("target_character_name"))

    let characterPatch = try Endpoint.updateCharacterCard(novelID: novelID, card: MockData.characterCards[0])
    #expect(characterPatch.method == .patch)
    #expect(characterPatch.path == "/api/novels/novel_001/characters/char_A")

    let memoryDelete = Endpoint.deleteMemoryFact(novelID: novelID, factID: "mem_001")
    #expect(memoryDelete.method == .delete)
    #expect(memoryDelete.path == "/api/novels/novel_001/memory/mem_001")
}

@Test func debugExportPayloadEncodesExpectedResources() throws {
    let payload = MockData.debugExportPayload()
    let json = try payload.prettyPrintedJSON()
    let decoded = try APIJSONCoding.makeDecoder().decode(DebugExportPayload.self, from: Data(json.utf8))

    #expect(decoded.contextPackJSON.contains("allowed_named_entities"))
    #expect(decoded.agentRuns.map(\.agentName).contains("上下文整理"))
    #expect(decoded.chapterVersions.contains(where: { $0.kind == "final" }))
    #expect(json.contains("chapter_versions"))
    #expect(json.contains("context_pack_json"))
    #expect(json.contains("agent_runs"))
}

@Test func characterAPIAlignmentHasNoUndocumentedDeleteEndpoint() throws {
    let novelID = "novel_001"
    let get = Endpoint.getCharacterCards(novelID: novelID)
    let create = try Endpoint.createCharacterCard(novelID: novelID, card: MockData.characterCards[0])
    let update = try Endpoint.updateCharacterCard(novelID: novelID, card: MockData.characterCards[0])

    #expect(get.method == .get)
    #expect(get.path == "/api/novels/novel_001/characters")
    #expect(create.method == .post)
    #expect(create.path == "/api/novels/novel_001/characters")
    #expect(update.method == .patch)
    #expect(update.path == "/api/novels/novel_001/characters/char_A")
}

@Test func liveBaseDocumentsSnakeCaseFixturesDecode() throws {
    let sections = try decodeLiveFixture("LiveWorldBibleSectionsSnake", as: [WorldBibleSection].self)
    let characters = try decodeLiveFixture("LiveCharacterCardsSnake", as: [CharacterCard].self)
    let memory = try decodeLiveFixture("LiveMemoryFactsSnake", as: [MemoryFact].self)

    #expect(sections[0].activationPolicy == .alwaysInContextBrief)
    #expect(characters[0].relationships[0].targetCharacterName == "B")
    #expect(characters[0].forbiddenBehavior.contains("不能突然全知旧案真相"))
    #expect(memory[0].chapterNo == 3)
    #expect(memory[0].canonStatus == "confirmed")
}

@MainActor
@Test func knowledgeMatrixStoreLoadsFiltersSavesAndDeletes() async throws {
    let api = MockKnowledgeMatrixAPI()
    let store = KnowledgeMatrixStore(api: api)

    await store.loadEntries()
    #expect(store.entries.count == MockData.knowledgeEntries.count)
    #expect(store.characterFilterOptions.contains("A"))

    store.filterText = "旧案"
    #expect(!store.filteredEntries.isEmpty)
    store.selectedCharacterName = "A"
    store.selectedState = .suspects
    #expect(store.filteredEntries.contains(where: { $0.id == "km_001" }))

    await store.addEntry()
    let createdID = try #require(store.selectedEntryID)
    store.updateCharacterState(entryID: createdID, characterName: "A", state: .known)
    store.entries[store.entries.count - 1].allowedNarration = "测试允许叙述"
    await store.saveMatrix()
    #expect(store.statusMessage == "Knowledge Matrix 已保存。")

    await store.deleteEntry(id: createdID)
    #expect(!store.entries.contains(where: { $0.id == createdID }))
}

@Test func mockKnowledgeMatrixAPIRoundTripsEntries() async throws {
    let api = MockKnowledgeMatrixAPI(entries: [])
    let novelID = MockData.novel.id

    let created = try await api.createKnowledgeMatrixEntry(MockData.knowledgeEntries[0], novelID: novelID)
    var entries = try await api.getKnowledgeMatrixEntries(novelID: novelID)
    #expect(entries.map(\.id) == [created.id])

    var updated = created
    updated.allowedNarration = "只能写怀疑，不能确认。"
    _ = try await api.updateKnowledgeMatrixEntry(updated, novelID: novelID)
    entries = try await api.getKnowledgeMatrixEntries(novelID: novelID)
    #expect(entries[0].allowedNarration == "只能写怀疑，不能确认。")

    try await api.deleteKnowledgeMatrixEntry(entryID: created.id, novelID: novelID)
    #expect(try await api.getKnowledgeMatrixEntries(novelID: novelID).isEmpty)
}

@Test func knowledgeMatrixEndpointsConstructExpectedRequests() throws {
    let novelID = "novel_001"

    let get = Endpoint.getKnowledgeMatrixEntries(novelID: novelID)
    #expect(get.method == .get)
    #expect(get.path == "/api/novels/novel_001/knowledge-matrix")

    let post = try Endpoint.createKnowledgeMatrixEntry(novelID: novelID, entry: MockData.knowledgeEntries[0])
    #expect(post.method == .post)
    #expect(post.path == "/api/novels/novel_001/knowledge-matrix")
    let postJSON = String(data: try #require(post.body), encoding: .utf8) ?? ""
    #expect(postJSON.contains("fact_title"))
    #expect(postJSON.contains("character_knowledge"))
    #expect(postJSON.contains("allowed_narration"))

    let patch = try Endpoint.updateKnowledgeMatrixEntry(novelID: novelID, entry: MockData.knowledgeEntries[0])
    #expect(patch.method == .patch)
    #expect(patch.path == "/api/novels/novel_001/knowledge-matrix/km_001")

    let delete = Endpoint.deleteKnowledgeMatrixEntry(novelID: novelID, entryID: "km_001")
    #expect(delete.method == .delete)
    #expect(delete.path == "/api/novels/novel_001/knowledge-matrix/km_001")
}

@Test func liveKnowledgeMatrixSnakeCaseFixtureDecodes() throws {
    let entries = try decodeLiveFixture("LiveKnowledgeMatrixSnake", as: [KnowledgeMatrixEntry].self)

    #expect(entries[0].id == "km_001")
    #expect(entries[0].factTitle == "B 与旧案有关")
    #expect(entries[0].authorKnowledge == .known)
    #expect(entries[0].readerKnowledge == .hinted)
    #expect(entries[0].characterKnowledge.first(where: { $0.characterName == "A" })?.state == .suspects)
    #expect(entries[0].allowedNarration.contains("不能确认"))
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
