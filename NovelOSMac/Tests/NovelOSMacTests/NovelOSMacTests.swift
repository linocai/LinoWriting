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
@Test func streamingDraftGenerationUpdatesStoreAndAgentRuns() async throws {
    let store = ChapterWorkflowStore(api: MockChapterWorkflowAPI())

    await store.generateStructuredPrompt()
    await store.approveStructuredPromptAndGenerateDraft()

    #expect(store.currentStep == .draftReview)
    #expect(store.draft?.id == MockData.draft.id)
    #expect(store.streamedWordCount > 0)
    #expect(store.agentRuns.contains(where: { $0.agentName == "正文检查" || $0.agentName == "Writing Agent" }))
}

@MainActor
@Test func streamingDraftGenerationFallsBackToSync() async throws {
    let api = StreamFailingChapterWorkflowAPI()
    let store = ChapterWorkflowStore(api: api)

    await store.generateStructuredPrompt()
    await store.approveStructuredPromptAndGenerateDraft()

    #expect(await api.syncGenerateCalls() == 1)
    #expect(store.draft?.id == MockData.draft.id)
    #expect(store.error == nil)
}

@MainActor
@Test func chapterStepGuardRejectsLockedStep() async throws {
    let store = ChapterWorkflowStore(api: MockChapterWorkflowAPI())

    #expect(store.currentStep == .promptInput)
    store.tryMove(to: .draftReview)
    #expect(store.currentStep == .promptInput)
    #expect(store.statusMessage == "当前步骤尚未就绪。")

    await store.generateStructuredPrompt()
    #expect(store.currentStep == .structuredPromptReview)
    store.tryMove(to: .draftReview)
    #expect(store.currentStep == .structuredPromptReview)

    store.tryMove(to: .promptInput)
    #expect(store.currentStep == .promptInput)
}

@MainActor
@Test func revisionRunningStateTracksDelayedRevision() async throws {
    let api = DelayedReviewChapterWorkflowAPI(delayNanoseconds: 120_000_000)
    let store = ChapterWorkflowStore(api: api)

    await store.generateStructuredPrompt()
    await store.approveStructuredPromptAndGenerateDraft()
    store.reviewFeedback = "请让 B 更克制，压缩解释。"

    let task = Task { @MainActor in
        await store.requestRevision()
    }
    try await Task.sleep(nanoseconds: 30_000_000)

    #expect(store.isRevisionRunning)
    #expect(store.isLoading)

    await task.value
    #expect(!store.isRevisionRunning)
    #expect(!store.isLoading)
    #expect(store.currentStep == .draftReview)
    #expect(store.draft?.versionNo == MockData.draft.versionNo + 1)
}

@MainActor
@Test func chapterStoreLoadsReadableImportedChapters() async throws {
    let store = ChapterWorkflowStore(api: MockChapterWorkflowAPI())

    await store.loadReadableChapters()

    #expect(store.chapters.map(\.chapterNo) == [1, 2, 3, 4])
    #expect(store.chapterDrafts["chapter_001"]?.text.contains("没有署名的邮件") == true)
    #expect(store.selectedReadableChapterID == "chapter_001")
}

@MainActor
@Test func completedChapterReloadsCanonPatchAndPromptArtifacts() async throws {
    let store = ChapterWorkflowStore(api: MockChapterWorkflowAPI())
    var completed = MockData.chapter
    completed.status = .completed
    completed.currentVersionId = MockData.draft.id

    await store.switchToNovel(MockData.novel, chapters: MockData.importedChapters + [completed])

    #expect(store.currentStep == .canonPatchReview)
    #expect(store.highestUnlockedStep == .canonPatchReview)
    #expect(store.structuredPrompt?.id == MockData.structuredPrompt.id)
    #expect(store.canonPatch?.id == MockData.canonPatch.id)
    #expect(store.agentRuns.isEmpty == false)
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

@Test func workspaceTitlesUseWeekTwoNaming() throws {
    #expect(Workspace.knowledgeMatrix.title == "Knowledge Matrix")
    #expect(Workspace.versionsDebug.title == "本章流程日志")
}

@Test func apiErrorTranslatesBackendDetails() throws {
    let llmError = APIError.httpStatus(
        502,
        #"{"detail":"大模型调用失败：请求超时","code":"llm_gateway_error","retryable":true}"#
    )
    #expect(llmError.userMessage == "大模型调用失败：请求超时 可稍后重试。")

    let conflict = APIError.httpStatus(409, #"{"detail":"Draft has S0 audit issues"}"#)
    #expect(conflict.userMessage == "当前状态不能继续：Draft has S0 audit issues")

    let envelope = APIError.httpStatus(
        409,
        #"{"error":{"kind":"workflow","message":"不能从 draftInput 跳到 completed","retryable":false}}"#
    )
    #expect(envelope.userMessage == "当前状态不能继续：不能从 draftInput 跳到 completed")
}

@Test func novelLibraryEndpointsConstructExpectedRequests() throws {
    let list = Endpoint.listNovels()
    #expect(list.method == .get)
    #expect(list.path == "/api/novels")

    let create = try Endpoint.createNovel(NovelCreateRequest(title: "长夜回声", genre: "悬疑"))
    #expect(create.method == .post)
    #expect(create.path == "/api/novels")
    let createBody = try decodeBody(create, as: NovelCreateRequest.self)
    #expect(createBody.title == "长夜回声")

    let chapter = try Endpoint.createChapter(
        novelID: "novel_new",
        request: ChapterCreateRequest(chapterNo: 1, title: "第 1 章")
    )
    #expect(chapter.method == .post)
    #expect(chapter.path == "/api/novels/novel_new/chapters")
    let chapterBody = try decodeBody(chapter, as: ChapterCreateRequest.self)
    #expect(chapterBody.chapterNo == 1)

    let importRequest = BootstrapImportRequest(chapters: [
        BootstrapChapterInput(chapterNo: 1, title: "一", text: "第一章正文"),
        BootstrapChapterInput(chapterNo: 2, title: "二", text: "第二章正文"),
        BootstrapChapterInput(chapterNo: 3, title: "三", text: "第三章正文")
    ])
    let importEndpoint = try Endpoint.importFirstThreeChapters(novelID: "novel_new", request: importRequest)
    #expect(importEndpoint.method == .post)
    #expect(importEndpoint.path == "/api/novels/novel_new/bootstrap/import-first-three-chapters")

    let statusEndpoint = Endpoint.getBootstrapStatus(novelID: "novel_new")
    #expect(statusEndpoint.method == .get)
    #expect(statusEndpoint.path == "/api/novels/novel_new/bootstrap/status")

    let analyzeEndpoint = Endpoint.analyzeBootstrap(novelID: "novel_new")
    #expect(analyzeEndpoint.method == .post)
    #expect(analyzeEndpoint.path == "/api/novels/novel_new/bootstrap/analyze")
}

@Test func mockNovelLibraryCreatesNovelAndChapter() async throws {
    let api = MockNovelLibraryAPI()
    let novel = try await api.createNovel(NovelCreateRequest(title: "长夜回声", genre: "悬疑"))
    #expect(novel.title == "长夜回声")
    #expect(novel.bootstrapStatus == .notStarted)

    let chapter = try await api.createChapter(
        novelID: novel.id,
        request: ChapterCreateRequest(chapterNo: 1, title: "第 1 章")
    )
    #expect(chapter.novelId == novel.id)
    #expect(chapter.status == .draftInput)

    let novels = try await api.listNovels()
    let chapters = try await api.listChapters(novelID: novel.id)
    #expect(novels.contains(where: { $0.id == novel.id }))
    #expect(chapters.map(\.chapterNo) == [1])
}

@Test func mockNovelLibraryImportsAndAnalyzesFirstThreeChapters() async throws {
    let api = MockNovelLibraryAPI()
    let novel = try await api.createNovel(NovelCreateRequest(title: "长夜回声", genre: "悬疑"))
    let request = BootstrapImportRequest(chapters: [
        BootstrapChapterInput(chapterNo: 1, title: "一", text: "第一章正文第一章正文第一章正文"),
        BootstrapChapterInput(chapterNo: 2, title: "二", text: "第二章正文第二章正文第二章正文"),
        BootstrapChapterInput(chapterNo: 3, title: "三", text: "第三章正文第三章正文第三章正文")
    ])

    let imported = try await api.importFirstThreeChapters(novelID: novel.id, request: request)
    #expect(imported.status == .imported)
    #expect(imported.importedChapterCount == 3)

    let analyzed = try await api.analyzeBootstrap(novelID: novel.id)
    #expect(analyzed.status == .analyzed)
    let status = try await api.getBootstrapStatus(novelID: novel.id)
    #expect(status.analysisReady)

    let chapters = try await api.listChapters(novelID: novel.id)
    #expect(chapters.map(\.chapterNo) == [1, 2, 3])
    #expect(chapters.allSatisfy { $0.status == .completed })
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
    store.characterCards[store.characterCards.count - 1].currentState.summary = "测试人物状态"
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
    updatedCharacter.currentState.summary = "已更新"
    _ = try await api.updateCharacterCard(updatedCharacter, novelID: novelID)
    #expect(try await api.getCharacterCards(novelID: novelID).first?.currentState.summary == "已更新")

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

    let stream = Endpoint.generateDraftStream(chapterID: "chapter_004")
    #expect(stream.method == .post)
    #expect(stream.path == "/api/chapters/chapter_004/draft/generate/stream")
    #expect(stream.headers["Accept"] == "text/event-stream")

    let runs = Endpoint.getAgentRuns(chapterID: "chapter_004")
    #expect(runs.path == "/api/chapters/chapter_004/agent-runs")
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

@Test func expandedAgentRunDecodesBackendDebugFields() throws {
    let json = """
    {
      "id": "run_1",
      "novel_id": "novel_001",
      "chapter_id": "chapter_004",
      "agent_name": "Writing Agent",
      "run_type": "draft",
      "model": "mock",
      "summary": "done",
      "status": "draft_generated",
      "payload": {"draft_id": "draft_004_v3"},
      "input_payload": {"stream": true},
      "output_payload": {"word_count": 3000},
      "input_json": {},
      "output_json": {},
      "token_usage": {"prompt_tokens": 1, "completion_tokens": 2, "total_tokens": 3, "model": "mock"},
      "started_at": 800000000.0,
      "completed_at": "2026-05-21T06:00:00Z",
      "latency_ms": 123.4,
      "created_at": 800000000.0
    }
    """
    let run = try APIJSONCoding.makeDecoder().decode(AgentRun.self, from: Data(json.utf8))
    #expect(run.agentName == "Writing Agent")
    #expect(run.inputPayload["stream"]?.displayString == "true")
    #expect(run.tokenUsage["total_tokens"]?.displayString == "3")
    #expect(run.latencyMs == 123.4)
}

@Test func characterCurrentStateDecodesLegacyAndStructuredForms() throws {
    let legacy = """
    [{
      "id": "char_test",
      "name": "A",
      "aliases": [],
      "role": "主角",
      "stable_traits": [],
      "current_state": "正在调查旧案。",
      "dialogue_style": "短句。",
      "relationships": [],
      "forbidden_behavior": [],
      "canon_version": 1
    }]
    """
    let legacyCards = try APIJSONCoding.makeDecoder().decode([CharacterCard].self, from: Data(legacy.utf8))
    #expect(legacyCards[0].currentState.summary == "正在调查旧案。")

    let structured = """
    [{
      "id": "char_test",
      "name": "A",
      "aliases": [],
      "role": "主角",
      "stable_traits": [],
      "current_state": {"physical": "疲惫", "emotional": "警觉", "goal": "查明线索", "summary": "保持克制。"},
      "dialogue_style": "短句。",
      "relationships": [],
      "forbidden_behavior": [],
      "canon_version": 1
    }]
    """
    let structuredCards = try APIJSONCoding.makeDecoder().decode([CharacterCard].self, from: Data(structured.utf8))
    #expect(structuredCards[0].currentState.physical == "疲惫")
    #expect(structuredCards[0].currentState.goal == "查明线索")
}

@Test func worldBibleSectionKeyDecodesAndCommandKIsAbsent() throws {
    let sectionJSON = """
    [{"id":"wb_style","section_key":"tone_and_style","title":"基调","content":"冷感","tags":[],"importance":"high","activation_policy":"always_in_context_brief","canon_version":1,"updated_at":800000000}]
    """
    let sections = try APIJSONCoding.makeDecoder().decode([WorldBibleSection].self, from: Data(sectionJSON.utf8))
    #expect(sections[0].sectionKey == "tone_and_style")

    let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let rootShell = packageRoot.appendingPathComponent("Sources/NovelOSMac/Views/RootShellView.swift")
    let source = try String(contentsOf: rootShell, encoding: .utf8)
    #expect(!source.contains("⌘K"))
    #expect(!source.contains("命令面板"))
}

@Test func liveBaseDocumentsDecodeStructuredBackendFields() throws {
    let charactersJSON = """
    [
      {
        "id": "char_A",
        "name": "A",
        "aliases": [],
        "role": "主角",
        "stable_traits": ["克制"],
        "current_state": {"summary": "正在调查旧案。"},
        "dialogue_style": {"summary": "短句。"},
        "relationships": [],
        "forbidden_behavior": ["不能突然全知旧案真相"],
        "last_active_chapter_no": 3,
        "canon_version": 1
      }
    ]
    """
    let characters = try APIJSONCoding.makeDecoder().decode([CharacterCard].self, from: Data(charactersJSON.utf8))
    #expect(characters[0].currentState.summary == "正在调查旧案。")
    #expect(characters[0].dialogueStyle == "短句。")

    let matrixJSON = """
    [
      {
        "id": "km_001",
        "fact_title": "B 与旧案有关",
        "truth_status": "author_only",
        "author_knowledge": "known",
        "reader_knowledge": "hinted",
        "character_knowledge": [
          {"character_id": "char_A", "character_name": "A", "state": "suspects"}
        ],
        "allowed_narration": {"text": "只能写怀疑，不能确认。"},
        "canon_version": 1
      }
    ]
    """
    let entries = try APIJSONCoding.makeDecoder().decode([KnowledgeMatrixEntry].self, from: Data(matrixJSON.utf8))
    #expect(entries[0].allowedNarration == "只能写怀疑，不能确认。")
    #expect(entries[0].visibility["A"] == .suspects)
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
    #expect(store.entries.last?.visibility["A"] == .known)
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
    #expect(postJSON.contains("visibility"))
    #expect(!postJSON.contains("character_knowledge"))
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
    #expect(entries[0].visibility["A"] == .suspects)
    #expect(entries[0].allowedNarration.contains("不能确认"))
}

@Test func knowledgeMatrixVisibilityDictEncodesAndDecodes() throws {
    let json = """
    [
      {
        "id": "km_001",
        "fact_title": "B 与旧案有关",
        "truth_status": "confirmed_author_only",
        "author_knowledge": "known",
        "reader_knowledge": "hinted",
        "visibility": {"A": "suspects", "B": "known"},
        "allowed_narration": "只能写怀疑。",
        "canon_version": 12
      }
    ]
    """
    let entries = try APIJSONCoding.makeDecoder().decode([KnowledgeMatrixEntry].self, from: Data(json.utf8))
    #expect(entries[0].visibility["A"] == .suspects)

    let encoded = String(data: try APIJSONCoding.makeEncoder().encode(entries[0]), encoding: .utf8) ?? ""
    #expect(encoded.contains("visibility"))
    #expect(!encoded.contains("character_knowledge"))
}

@MainActor
@Test func knowledgeMatrixLoadIfNeededCoalescesAndInvalidates() async throws {
    let api = CountingKnowledgeMatrixAPI(entries: MockData.knowledgeEntries)
    let store = KnowledgeMatrixStore(api: api)

    async let one: Void = store.loadIfNeeded()
    async let two: Void = store.loadIfNeeded()
    async let three: Void = store.loadIfNeeded()
    async let four: Void = store.loadIfNeeded()
    async let five: Void = store.loadIfNeeded()
    _ = await (one, two, three, four, five)

    #expect(await api.requestCount() == 1)

    await store.loadIfNeeded()
    #expect(await api.requestCount() == 1)

    store.invalidate()
    await store.loadIfNeeded()
    #expect(await api.requestCount() == 2)
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

private actor CountingKnowledgeMatrixAPI: KnowledgeMatrixAPI {
    private var entries: [KnowledgeMatrixEntry]
    private var count = 0

    init(entries: [KnowledgeMatrixEntry]) {
        self.entries = entries
    }

    func requestCount() -> Int {
        count
    }

    func getKnowledgeMatrixEntries(novelID: String) async throws -> [KnowledgeMatrixEntry] {
        count += 1
        try await Task.sleep(nanoseconds: 20_000_000)
        return entries
    }

    func createKnowledgeMatrixEntry(_ entry: KnowledgeMatrixEntry, novelID: String) async throws -> KnowledgeMatrixEntry {
        entries.append(entry)
        return entry
    }

    func updateKnowledgeMatrixEntry(_ entry: KnowledgeMatrixEntry, novelID: String) async throws -> KnowledgeMatrixEntry {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else {
            throw APIError.missingResource("knowledge matrix entry \(entry.id)")
        }
        entries[index] = entry
        return entry
    }

    func deleteKnowledgeMatrixEntry(entryID: String, novelID: String) async throws {
        entries.removeAll { $0.id == entryID }
    }
}

private actor DelayedReviewChapterWorkflowAPI: ChapterWorkflowAPI {
    private let base = MockChapterWorkflowAPI()
    private let delayNanoseconds: UInt64

    init(delayNanoseconds: UInt64) {
        self.delayNanoseconds = delayNanoseconds
    }

    func listChapters(novelID: String) async throws -> [Chapter] {
        try await base.listChapters(novelID: novelID)
    }

    func submitUserPrompt(chapterID: String, prompt: String) async throws {
        try await base.submitUserPrompt(chapterID: chapterID, prompt: prompt)
    }

    func getStructuredPrompt(chapterID: String) async throws -> StructuredPrompt {
        try await base.getStructuredPrompt(chapterID: chapterID)
    }

    func updateStructuredPrompt(_ prompt: StructuredPrompt, chapterID: String) async throws -> StructuredPrompt {
        try await base.updateStructuredPrompt(prompt, chapterID: chapterID)
    }

    func approveStructuredPrompt(chapterID: String) async throws {
        try await base.approveStructuredPrompt(chapterID: chapterID)
    }

    func generateDraft(chapterID: String) async throws {
        try await base.generateDraft(chapterID: chapterID)
    }

    func generateDraftStream(chapterID: String, onEvent: @MainActor @Sendable @escaping (DraftStreamEvent) async -> Void) async throws {
        try await base.generateDraftStream(chapterID: chapterID, onEvent: onEvent)
    }

    func getLatestDraft(chapterID: String) async throws -> Draft {
        try await base.getLatestDraft(chapterID: chapterID)
    }

    func getAgentRuns(chapterID: String) async throws -> [AgentRun] {
        try await base.getAgentRuns(chapterID: chapterID)
    }

    func reviewDraft(chapterID: String, request: DraftReviewRequest) async throws {
        try await Task.sleep(nanoseconds: delayNanoseconds)
        try await base.reviewDraft(chapterID: chapterID, request: request)
    }

    func approveFinalText(chapterID: String) async throws {
        try await base.approveFinalText(chapterID: chapterID)
    }

    func getCanonUpdatePatch(chapterID: String) async throws -> CanonUpdatePatch {
        try await base.getCanonUpdatePatch(chapterID: chapterID)
    }

    func updateCanonUpdatePatch(_ patch: CanonUpdatePatch, chapterID: String) async throws -> CanonUpdatePatch {
        try await base.updateCanonUpdatePatch(patch, chapterID: chapterID)
    }

    func confirmCanonUpdatePatch(chapterID: String) async throws {
        try await base.confirmCanonUpdatePatch(chapterID: chapterID)
    }
}

private actor StreamFailingChapterWorkflowAPI: ChapterWorkflowAPI {
    private let base = MockChapterWorkflowAPI()
    private var syncCount = 0

    func syncGenerateCalls() -> Int {
        syncCount
    }

    func listChapters(novelID: String) async throws -> [Chapter] {
        try await base.listChapters(novelID: novelID)
    }

    func submitUserPrompt(chapterID: String, prompt: String) async throws {
        try await base.submitUserPrompt(chapterID: chapterID, prompt: prompt)
    }

    func getStructuredPrompt(chapterID: String) async throws -> StructuredPrompt {
        try await base.getStructuredPrompt(chapterID: chapterID)
    }

    func updateStructuredPrompt(_ prompt: StructuredPrompt, chapterID: String) async throws -> StructuredPrompt {
        try await base.updateStructuredPrompt(prompt, chapterID: chapterID)
    }

    func approveStructuredPrompt(chapterID: String) async throws {
        try await base.approveStructuredPrompt(chapterID: chapterID)
    }

    func generateDraft(chapterID: String) async throws {
        syncCount += 1
        try await base.generateDraft(chapterID: chapterID)
    }

    func generateDraftStream(chapterID: String, onEvent: @MainActor @Sendable @escaping (DraftStreamEvent) async -> Void) async throws {
        throw APIError.transport("stream unavailable")
    }

    func getLatestDraft(chapterID: String) async throws -> Draft {
        try await base.getLatestDraft(chapterID: chapterID)
    }

    func getAgentRuns(chapterID: String) async throws -> [AgentRun] {
        try await base.getAgentRuns(chapterID: chapterID)
    }

    func reviewDraft(chapterID: String, request: DraftReviewRequest) async throws {
        try await base.reviewDraft(chapterID: chapterID, request: request)
    }

    func approveFinalText(chapterID: String) async throws {
        try await base.approveFinalText(chapterID: chapterID)
    }

    func getCanonUpdatePatch(chapterID: String) async throws -> CanonUpdatePatch {
        try await base.getCanonUpdatePatch(chapterID: chapterID)
    }

    func updateCanonUpdatePatch(_ patch: CanonUpdatePatch, chapterID: String) async throws -> CanonUpdatePatch {
        try await base.updateCanonUpdatePatch(patch, chapterID: chapterID)
    }

    func confirmCanonUpdatePatch(chapterID: String) async throws {
        try await base.confirmCanonUpdatePatch(chapterID: chapterID)
    }
}
