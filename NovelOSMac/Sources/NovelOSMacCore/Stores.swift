import Foundation
import Observation

@MainActor
@Observable
public final class AppStore {
    public var selectedWorkspace: Workspace = .chapterStudio
    public var selectedNovelID: String? = MockData.novel.id
    public var selectedChapterID: String? = MockData.chapter.id
    public var isInspectorVisible: Bool = true
    public var toast: ToastState?
    public var globalLoading: Bool = false

    public init() {}
}

@MainActor
@Observable
public final class ChapterWorkflowStore {
    @ObservationIgnored private let api: any ChapterWorkflowAPI

    public var novel: Novel
    public var chapter: Chapter
    public var currentStep: ChapterStep = .promptInput
    public var highestUnlockedStep: ChapterStep = .promptInput
    public var promptDraft: String
    public var structuredPrompt: StructuredPrompt?
    public var draft: Draft?
    public var reviewFeedback: String
    public var auditSummary: AuditSummary?
    public var canonPatch: CanonUpdatePatch?
    public var isLoading: Bool = false
    public var statusMessage: String?
    public var error: APIError?

    public init(api: any ChapterWorkflowAPI = MockChapterWorkflowAPI()) {
        self.api = api
        novel = MockData.novel
        chapter = MockData.chapter
        promptDraft = MockData.promptDraft
        reviewFeedback = "B 可以更克制一点，不要让读者太早判断他一定有问题。结尾 C 的线索要短促，别展开 C 的背景。"
    }

    public var canGenerateStructuredPrompt: Bool {
        promptDraft.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10
    }

    public var finalApprovalBlockedReason: String? {
        guard let summary = auditSummary, summary.s0Count > 0 else { return nil }
        return "存在 S0 硬错误，系统需要先修复。"
    }

    public var safetySummary: ActivationSummary {
        structuredPrompt?.activationSummary
            ?? MockData.structuredPrompt.activationSummary
            ?? ActivationSummary(
                activeCast: ["A", "B", "C"],
                allowedNamesCount: 6,
                mentionBudgetTotal: 1,
                newNamedCharacterPolicy: "禁止"
            )
    }

    public func canMove(to step: ChapterStep) -> Bool {
        step.rawValue <= highestUnlockedStep.rawValue
    }

    public func tryMove(to step: ChapterStep) {
        guard canMove(to: step) else {
            statusMessage = "当前步骤尚未就绪。"
            return
        }
        currentStep = step
    }

    public func savePromptDraft() {
        statusMessage = "Prompt 草稿已保存。"
    }

    public func generateStructuredPrompt() async {
        guard canGenerateStructuredPrompt else {
            statusMessage = "Prompt 至少需要 10 个字。"
            return
        }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            try await api.submitUserPrompt(chapterID: chapter.id, prompt: promptDraft)
            structuredPrompt = try await api.getStructuredPrompt(chapterID: chapter.id)
            chapter.status = .structuredPromptReady
            unlock(.structuredPromptReview)
            currentStep = .structuredPromptReview
            statusMessage = "结构化 Prompt 已生成。"
        } catch {
            handle(error)
        }
    }

    public func approveStructuredPromptAndGenerateDraft() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let prompt = try await currentOrRemoteStructuredPrompt()
            structuredPrompt = try await api.updateStructuredPrompt(prompt, chapterID: chapter.id)
            try await api.approveStructuredPrompt(chapterID: chapter.id)
            try await api.generateDraft(chapterID: chapter.id)
            let latestDraft = try await api.getLatestDraft(chapterID: chapter.id)
            draft = latestDraft
            auditSummary = latestDraft.auditSummary
            chapter.status = .draftGenerated
            chapter.currentVersionId = latestDraft.id
            unlock(.draftReview)
            currentStep = .draftReview
            statusMessage = "正文已生成。"
        } catch {
            handle(error)
        }
    }

    public func requestRevision() async {
        guard !reviewFeedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            statusMessage = "请先填写修改意见。"
            return
        }

        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let request = DraftReviewRequest(decision: .revise, feedback: reviewFeedback)
            try await api.reviewDraft(chapterID: chapter.id, request: request)
            let latestDraft = try await api.getLatestDraft(chapterID: chapter.id)
            draft = latestDraft
            auditSummary = latestDraft.auditSummary
            chapter.status = .draftGenerated
            chapter.currentVersionId = latestDraft.id
            currentStep = .draftReview
            unlock(.draftReview)
            statusMessage = "已根据你的意见生成新版本。"
        } catch {
            handle(error)
        }
    }

    @discardableResult
    public func approveDraftForFinalReview() async -> Bool {
        if let finalApprovalBlockedReason {
            statusMessage = finalApprovalBlockedReason
            return false
        }

        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            try await api.reviewDraft(chapterID: chapter.id, request: DraftReviewRequest(decision: .approve))
            chapter.status = .draftApproved
            unlock(.finalApproval)
            currentStep = .finalApproval
            statusMessage = "正文已进入最终批准。"
            return true
        } catch {
            handle(error)
            return false
        }
    }

    public func approveFinalTextAndPreparePatch() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            try await api.approveFinalText(chapterID: chapter.id)
            canonPatch = try await api.getCanonUpdatePatch(chapterID: chapter.id)
            chapter.status = .canonPatchPending
            chapter.approvedVersionId = draft?.id
            unlock(.canonPatchReview)
            currentStep = .canonPatchReview
            statusMessage = "基础文档更新已准备好。"
        } catch {
            handle(error)
        }
    }

    public func updatePatchDecision(itemID: String, decision: PatchUserDecision) {
        guard let index = canonPatch?.items.firstIndex(where: { $0.id == itemID }) else { return }
        canonPatch?.items[index].proposedAction = decision
        if decision == .modify, canonPatch?.items[index].editablePayload == nil {
            canonPatch?.items[index].editablePayload = canonPatch?.items[index].summary
        }
    }

    public func updatePatchPayload(itemID: String, payload: String) {
        guard let index = canonPatch?.items.firstIndex(where: { $0.id == itemID }) else { return }
        canonPatch?.items[index].editablePayload = payload
    }

    public func savePatchForLater() async {
        guard let canonPatch else {
            statusMessage = "基础文档更新尚未准备。"
            return
        }

        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            self.canonPatch = try await api.updateCanonUpdatePatch(canonPatch, chapterID: chapter.id)
            statusMessage = "基础文档更新已保存，可稍后确认。"
        } catch {
            handle(error)
        }
    }

    public func confirmCanonPatch() async {
        guard let canonPatch else {
            statusMessage = "基础文档更新尚未准备。"
            return
        }

        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            self.canonPatch = try await api.updateCanonUpdatePatch(canonPatch, chapterID: chapter.id)
            try await api.confirmCanonUpdatePatch(chapterID: chapter.id)
            chapter.status = .completed
            novel.currentCanonVersion = canonPatch.targetCanonVersion
            statusMessage = "本章已完成，Canon 已更新。"
        } catch {
            handle(error)
        }
    }

    public func saveCurrentDraftVersion() {
        statusMessage = "当前正文版本已保存。"
    }

    public func injectS0ForTesting() {
        let issue = AuditIssue(
            id: "audit_s0_test",
            severity: .s0,
            type: "非法专名",
            location: "测试段落",
            message: "出现未授权专名。",
            suggestion: "删除未授权专名。"
        )
        var summary = auditSummary ?? MockData.auditSummary
        summary.s0Count = 1
        summary.illegalNamedEntityCount = 1
        summary.issues.insert(issue, at: 0)
        auditSummary = summary
        draft?.auditSummary = summary
    }

    private func unlock(_ step: ChapterStep) {
        if step.rawValue > highestUnlockedStep.rawValue {
            highestUnlockedStep = step
        }
    }

    private func currentOrRemoteStructuredPrompt() async throws -> StructuredPrompt {
        if let structuredPrompt {
            return structuredPrompt
        }
        return try await api.getStructuredPrompt(chapterID: chapter.id)
    }

    private func handle(_ error: Error) {
        let apiError = error as? APIError ?? APIError.transport(String(describing: error))
        self.error = apiError
        statusMessage = apiError.userMessage
    }
}

@MainActor
@Observable
public final class BaseDocumentsStore {
    @ObservationIgnored private let api: any BaseDocumentsAPI

    public let novelID: String
    public var worldBibleSections: [WorldBibleSection]
    public var characterCards: [CharacterCard]
    public var memoryFacts: [MemoryFact]
    public var selectedBaseDocument: BaseDocumentKind = .worldBible
    public var isSaving: Bool = false
    public var isIndexing: Bool = false
    public var isLoading: Bool = false
    public var statusMessage: String?
    public var error: APIError?
    public var memoryChapterFilter: String = ""

    public init(api: any BaseDocumentsAPI = MockBaseDocumentsAPI(), novelID: String = MockData.novel.id) {
        self.api = api
        self.novelID = novelID
        worldBibleSections = MockData.worldBibleSections
        characterCards = MockData.characterCards
        memoryFacts = MockData.memoryFacts
    }

    public var filteredMemoryFacts: [MemoryFact] {
        let trimmed = memoryChapterFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let chapterNo = Int(trimmed) else {
            return memoryFacts
        }
        return memoryFacts.filter { $0.chapterNo == chapterNo }
    }

    public func loadDocuments(force: Bool = false) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            async let worldBible = api.getWorldBibleSections(novelID: novelID)
            async let characters = api.getCharacterCards(novelID: novelID)
            async let memory = api.getMemoryFacts(novelID: novelID)
            worldBibleSections = try await worldBible
            characterCards = try await characters
            memoryFacts = try await memory
            statusMessage = "基础文件已加载。"
        } catch {
            handle(error)
        }
    }

    public func addWorldBibleSection() async {
        isSaving = true
        error = nil
        defer { isSaving = false }

        do {
            let created = try await api.createWorldBibleSection(
                WorldBibleSection(
                    id: "wb_\(UUID().uuidString)",
                    title: "新 Section",
                    content: "",
                    tags: [],
                    importance: .medium,
                    activationPolicy: .manualOnly,
                    canonVersion: MockData.novel.currentCanonVersion ?? 12,
                    updatedAt: Date()
                ),
                novelID: novelID
            )
            worldBibleSections.append(created)
            selectedBaseDocument = .worldBible
            statusMessage = "World Bible Section 已新增。"
        } catch {
            handle(error)
        }
    }

    public func addCharacter() async {
        isSaving = true
        error = nil
        defer { isSaving = false }

        do {
            let created = try await api.createCharacterCard(
                CharacterCard(
                    id: "char_\(UUID().uuidString)",
                    name: "新人物",
                    aliases: [],
                    role: "待定",
                    stableTraits: [],
                    currentState: "",
                    dialogueStyle: "",
                    relationships: [],
                    forbiddenBehavior: [],
                    lastActiveChapterNo: nil,
                    canonVersion: MockData.novel.currentCanonVersion ?? 12
                ),
                novelID: novelID
            )
            characterCards.append(created)
            selectedBaseDocument = .characterCards
            statusMessage = "人物卡已新增。"
        } catch {
            handle(error)
        }
    }

    public func addMemoryFact() async {
        isSaving = true
        error = nil
        defer { isSaving = false }

        do {
            let created = try await api.createMemoryFact(
                MemoryFact(
                    id: "mem_\(UUID().uuidString)",
                    chapterNo: MockData.chapter.chapterNo,
                    factType: "event",
                    summary: "",
                    participants: [],
                    location: nil,
                    evidence: "手动添加",
                    canonStatus: "confirmed",
                    canonVersion: MockData.novel.currentCanonVersion ?? 12
                ),
                novelID: novelID
            )
            memoryFacts.append(created)
            selectedBaseDocument = .memory
            statusMessage = "Memory fact 已新增。"
        } catch {
            handle(error)
        }
    }

    public func addRelationship(to characterID: String) {
        guard let index = characterCards.firstIndex(where: { $0.id == characterID }) else { return }
        characterCards[index].relationships.append(
            CharacterRelationship(
                id: "rel_\(UUID().uuidString)",
                targetCharacterName: "关联人物",
                relationshipSummary: "",
                currentTension: nil,
                lastChangedChapterNo: MockData.chapter.chapterNo
            )
        )
    }

    public func deleteWorldBibleSection(id: String) async {
        isSaving = true
        error = nil
        defer { isSaving = false }

        do {
            try await api.deleteWorldBibleSection(sectionID: id, novelID: novelID)
            worldBibleSections.removeAll { $0.id == id }
            statusMessage = "World Bible Section 已删除。"
        } catch {
            handle(error)
        }
    }

    public func deleteCharacter(id: String) async {
        isSaving = true
        error = nil
        defer { isSaving = false }

        do {
            try await api.deleteCharacterCard(characterID: id, novelID: novelID)
            characterCards.removeAll { $0.id == id }
            statusMessage = "人物卡已删除。"
        } catch {
            handle(error)
        }
    }

    public func deleteMemoryFact(id: String) async {
        isSaving = true
        error = nil
        defer { isSaving = false }

        do {
            try await api.deleteMemoryFact(factID: id, novelID: novelID)
            memoryFacts.removeAll { $0.id == id }
            statusMessage = "Memory fact 已删除。"
        } catch {
            handle(error)
        }
    }

    public func saveChanges() async {
        isSaving = true
        isIndexing = true
        error = nil
        defer {
            isSaving = false
            isIndexing = false
        }

        do {
            var savedSections: [WorldBibleSection] = []
            for section in worldBibleSections {
                savedSections.append(try await api.updateWorldBibleSection(section, novelID: novelID))
            }

            var savedCharacters: [CharacterCard] = []
            for card in characterCards {
                savedCharacters.append(try await api.updateCharacterCard(card, novelID: novelID))
            }

            var savedMemory: [MemoryFact] = []
            for fact in memoryFacts {
                savedMemory.append(try await api.updateMemoryFact(fact, novelID: novelID))
            }

            worldBibleSections = savedSections
            characterCards = savedCharacters
            memoryFacts = savedMemory
            statusMessage = "基础文件已保存，后台 reindex 已完成。"
        } catch {
            handle(error)
        }
    }

    private func handle(_ error: Error) {
        let apiError = error as? APIError ?? APIError.transport(String(describing: error))
        self.error = apiError
        statusMessage = apiError.userMessage
    }
}

@MainActor
@Observable
public final class KnowledgeMatrixStore {
    public var entries: [KnowledgeMatrixEntry]
    public var visibleCharacters: [String]
    public var filterText: String = ""
    public var selectedState: KnowledgeState?
    public var selectedEntryID: String?
    public var isSaving: Bool = false
    public var statusMessage: String?

    public init() {
        entries = MockData.knowledgeEntries
        visibleCharacters = ["A", "B", "C"]
    }

    public var filteredEntries: [KnowledgeMatrixEntry] {
        entries.filter { entry in
            let textMatches = filterText.isEmpty
                || entry.factTitle.localizedCaseInsensitiveContains(filterText)
                || entry.allowedNarration.localizedCaseInsensitiveContains(filterText)
                || entry.truthStatus.localizedCaseInsensitiveContains(filterText)

            let stateMatches = selectedState == nil
                || entry.authorKnowledge == selectedState
                || entry.readerKnowledge == selectedState
                || entry.characterKnowledge.contains(where: { $0.state == selectedState })

            return textMatches && stateMatches
        }
    }

    public func addEntry() {
        entries.append(
            KnowledgeMatrixEntry(
                id: "km_\(UUID().uuidString)",
                factTitle: "新知识条目",
                truthStatus: "author_only",
                authorKnowledge: .authorOnly,
                readerKnowledge: .readerUnknown,
                characterKnowledge: visibleCharacters.map {
                    CharacterKnowledge(characterId: "char_\($0)", characterName: $0, state: .unknown)
                },
                allowedNarration: "",
                canonVersion: MockData.novel.currentCanonVersion ?? 12
            )
        )
    }

    public func saveMatrix() {
        isSaving = true
        statusMessage = "Knowledge Matrix 已保存。"
        isSaving = false
    }
}
