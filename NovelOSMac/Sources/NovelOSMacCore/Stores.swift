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
public final class NovelLibraryStore {
    @ObservationIgnored private let api: any NovelLibraryAPI
    @ObservationIgnored private var hasLoaded = false

    public var novels: [Novel] = [MockData.novel]
    public var selectedNovelID: String? = MockData.novel.id
    public var newNovelTitle: String = ""
    public var newNovelGenre: String = ""
    public var importChapter1Title: String = "第 1 章"
    public var importChapter2Title: String = "第 2 章"
    public var importChapter3Title: String = "第 3 章"
    public var importChapter1Text: String = ""
    public var importChapter2Text: String = ""
    public var importChapter3Text: String = ""
    public var isShowingNewNovelSheet: Bool = false
    public var isLoading: Bool = false
    public var statusMessage: String?
    public var error: APIError?

    public init(api: any NovelLibraryAPI = MockNovelLibraryAPI()) {
        self.api = api
    }

    public var sortedNovels: [Novel] {
        novels.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    public var selectedNovel: Novel? {
        guard let selectedNovelID else { return nil }
        return novels.first { $0.id == selectedNovelID }
    }

    public var canImportFirstThreeChapters: Bool {
        [importChapter1Text, importChapter2Text, importChapter3Text].allSatisfy {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).count >= 20
        }
    }

    public func loadIfNeeded(
        appStore: AppStore,
        chapterStore: ChapterWorkflowStore,
        baseDocumentsStore: BaseDocumentsStore,
        knowledgeStore: KnowledgeMatrixStore
    ) async {
        guard !hasLoaded else { return }
        await reloadAndSelectCurrent(
            appStore: appStore,
            chapterStore: chapterStore,
            baseDocumentsStore: baseDocumentsStore,
            knowledgeStore: knowledgeStore
        )
    }

    public func reloadAndSelectCurrent(
        appStore: AppStore,
        chapterStore: ChapterWorkflowStore,
        baseDocumentsStore: BaseDocumentsStore,
        knowledgeStore: KnowledgeMatrixStore
    ) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let loaded = try await api.listNovels()
            novels = loaded.isEmpty ? novels : loaded
            hasLoaded = true
            let preferredID = selectedNovelID ?? appStore.selectedNovelID ?? chapterStore.novel.id
            let target = novels.first { $0.id == preferredID } ?? sortedNovels.first
            if let target {
                try await applySelection(
                    target,
                    appStore: appStore,
                    chapterStore: chapterStore,
                    baseDocumentsStore: baseDocumentsStore,
                    knowledgeStore: knowledgeStore
                )
            }
            statusMessage = "书库已加载。"
        } catch {
            handle(error)
        }
    }

    public func selectNovel(
        _ novel: Novel,
        appStore: AppStore,
        chapterStore: ChapterWorkflowStore,
        baseDocumentsStore: BaseDocumentsStore,
        knowledgeStore: KnowledgeMatrixStore
    ) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            try await applySelection(
                novel,
                appStore: appStore,
                chapterStore: chapterStore,
                baseDocumentsStore: baseDocumentsStore,
                knowledgeStore: knowledgeStore
            )
            statusMessage = "已切换到《\(novel.title)》。"
        } catch {
            handle(error)
        }
    }

    public func createNovelAndSelect(
        appStore: AppStore,
        chapterStore: ChapterWorkflowStore,
        baseDocumentsStore: BaseDocumentsStore,
        knowledgeStore: KnowledgeMatrixStore
    ) async {
        let title = newNovelTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            statusMessage = "书名不能为空。"
            return
        }

        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let novel = try await api.createNovel(
                NovelCreateRequest(
                    title: title,
                    genre: newNovelGenre.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                )
            )
            if !novels.contains(where: { $0.id == novel.id }) {
                novels.append(novel)
            }
            try await applySelection(
                novel,
                appStore: appStore,
                chapterStore: chapterStore,
                baseDocumentsStore: baseDocumentsStore,
                knowledgeStore: knowledgeStore
            )
            newNovelTitle = ""
            newNovelGenre = ""
            isShowingNewNovelSheet = false
            statusMessage = "已创建《\(novel.title)》。"
        } catch {
            handle(error)
        }
    }

    public func importFirstThreeChaptersAndPrepareNext(
        appStore: AppStore,
        chapterStore: ChapterWorkflowStore,
        baseDocumentsStore: BaseDocumentsStore,
        knowledgeStore: KnowledgeMatrixStore
    ) async {
        guard let selectedNovel else {
            statusMessage = "请先选择一本书。"
            return
        }
        guard canImportFirstThreeChapters else {
            statusMessage = "请完整粘贴前三章正文，每章至少 20 个字。"
            return
        }

        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let request = BootstrapImportRequest(
                chapters: [
                    BootstrapChapterInput(chapterNo: 1, title: importChapter1Title.nilIfEmpty ?? "第 1 章", text: importChapter1Text),
                    BootstrapChapterInput(chapterNo: 2, title: importChapter2Title.nilIfEmpty ?? "第 2 章", text: importChapter2Text),
                    BootstrapChapterInput(chapterNo: 3, title: importChapter3Title.nilIfEmpty ?? "第 3 章", text: importChapter3Text)
                ]
            )
            _ = try await api.importFirstThreeChapters(novelID: selectedNovel.id, request: request)
            let analysis = try await api.analyzeBootstrap(novelID: selectedNovel.id)
            var chapters = try await api.listChapters(novelID: selectedNovel.id)
                .sorted { $0.chapterNo < $1.chapterNo }
            if !chapters.contains(where: { $0.chapterNo == 4 }) {
                let next = try await api.createChapter(
                    novelID: selectedNovel.id,
                    request: ChapterCreateRequest(chapterNo: 4, title: "第 4 章")
                )
                chapters.append(next)
                chapters.sort { $0.chapterNo < $1.chapterNo }
            }

            var updatedNovel = selectedNovel
            updatedNovel.bootstrapStatus = analysis.status
            updatedNovel.currentChapterNo = 4
            updatedNovel.currentCanonVersion = updatedNovel.currentCanonVersion ?? 1
            replaceNovel(updatedNovel)
            clearImportDrafts()

            try await applySelection(
                updatedNovel,
                appStore: appStore,
                chapterStore: chapterStore,
                baseDocumentsStore: baseDocumentsStore,
                knowledgeStore: knowledgeStore,
                preloadedChapters: chapters
            )
            appStore.selectedWorkspace = .chapterStudio
            statusMessage = "前三章已导入并分析，已准备第 4 章。"
        } catch {
            handle(error)
        }
    }

    private func applySelection(
        _ novel: Novel,
        appStore: AppStore,
        chapterStore: ChapterWorkflowStore,
        baseDocumentsStore: BaseDocumentsStore,
        knowledgeStore: KnowledgeMatrixStore,
        preloadedChapters: [Chapter]? = nil
    ) async throws {
        let chapters: [Chapter]
        if let preloadedChapters {
            chapters = preloadedChapters
        } else {
            chapters = try await chaptersReadyForNovel(novel)
        }
        var selectedNovel = novel
        selectedNovel.currentChapterNo = activeChapter(from: chapters, novel: novel)?.chapterNo
        replaceNovel(selectedNovel)

        selectedNovelID = selectedNovel.id
        appStore.selectedNovelID = selectedNovel.id
        appStore.selectedChapterID = activeChapter(from: chapters, novel: selectedNovel)?.id

        await chapterStore.switchToNovel(selectedNovel, chapters: chapters)
        baseDocumentsStore.switchNovel(
            novelID: selectedNovel.id,
            currentCanonVersion: selectedNovel.currentCanonVersion,
            currentChapterNo: selectedNovel.currentChapterNo
        )
        knowledgeStore.switchNovel(
            novelID: selectedNovel.id,
            currentCanonVersion: selectedNovel.currentCanonVersion
        )
        await baseDocumentsStore.loadDocuments(force: true)
        await knowledgeStore.loadEntries(force: true)
    }

    private func chaptersReadyForNovel(_ novel: Novel) async throws -> [Chapter] {
        try await api.listChapters(novelID: novel.id)
            .sorted { $0.chapterNo < $1.chapterNo }
    }

    private func activeChapter(from chapters: [Chapter], novel: Novel) -> Chapter? {
        if let current = novel.currentChapterNo,
           let matched = chapters.first(where: { $0.chapterNo == current }) {
            return matched
        }
        return chapters.first(where: { $0.status != .completed }) ?? chapters.last ?? chapters.first
    }

    private func replaceNovel(_ novel: Novel) {
        if let index = novels.firstIndex(where: { $0.id == novel.id }) {
            novels[index] = novel
        } else {
            novels.append(novel)
        }
    }

    private func clearImportDrafts() {
        importChapter1Title = "第 1 章"
        importChapter2Title = "第 2 章"
        importChapter3Title = "第 3 章"
        importChapter1Text = ""
        importChapter2Text = ""
        importChapter3Text = ""
    }

    private func handle(_ error: Error) {
        let apiError = error as? APIError ?? APIError.transport(String(describing: error))
        self.error = apiError
        statusMessage = apiError.userMessage
    }
}

@MainActor
@Observable
public final class ChapterWorkflowStore {
    @ObservationIgnored private let api: any ChapterWorkflowAPI

    public var novel: Novel
    public var chapter: Chapter
    public var chapters: [Chapter]
    public var chapterDrafts: [String: Draft]
    public var selectedReadableChapterID: String?
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
        chapters = MockData.chapters
        chapterDrafts = Dictionary(uniqueKeysWithValues: (MockData.importedChapterDrafts + [MockData.draft]).map { ($0.chapterId, $0) })
        selectedReadableChapterID = MockData.importedChapters.first?.id
        promptDraft = MockData.promptDraft
        reviewFeedback = "B 可以更克制一点，不要让读者太早判断他一定有问题。结尾 C 的线索要短促，别展开 C 的背景。"
    }

    public var canGenerateStructuredPrompt: Bool {
        isBootstrapReady && promptDraft.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10
    }

    public var isBootstrapReady: Bool {
        switch novel.bootstrapStatus {
        case .imported, .analyzed, .completed:
            return true
        case .notStarted, .importing, .analyzing, .failed:
            return false
        }
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

    public func switchToNovel(_ selectedNovel: Novel, chapters loadedChapters: [Chapter]) async {
        novel = selectedNovel
        chapters = loadedChapters.sorted { $0.chapterNo < $1.chapterNo }
        if let active = activeChapter(from: chapters, novel: selectedNovel) {
            chapter = active
        } else {
            chapter = placeholderChapter(for: selectedNovel)
        }

        currentStep = step(for: chapter.status)
        highestUnlockedStep = currentStep
        promptDraft = ""
        structuredPrompt = nil
        draft = nil
        reviewFeedback = ""
        auditSummary = nil
        canonPatch = nil
        selectedReadableChapterID = chapters.first?.id

        var loadedDrafts: [String: Draft] = [:]
        for loadedChapter in chapters {
            if let latestDraft = try? await api.getLatestDraft(chapterID: loadedChapter.id) {
                loadedDrafts[loadedChapter.id] = latestDraft
            }
        }
        chapterDrafts = loadedDrafts
        if let currentDraft = loadedDrafts[chapter.id] {
            draft = currentDraft
            auditSummary = currentDraft.auditSummary
        }
        statusMessage = "已加载《\(selectedNovel.title)》。"
    }

    public func loadReadableChapters() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let loadedChapters = try await api.listChapters(novelID: novel.id)
                .sorted { $0.chapterNo < $1.chapterNo }
            var loadedDrafts: [String: Draft] = [:]

            if loadedChapters.isEmpty {
                chapters = []
                chapterDrafts = [:]
                selectedReadableChapterID = nil
                draft = nil
                auditSummary = nil
                statusMessage = "当前书籍还没有章节。"
                return
            }

            for loadedChapter in loadedChapters {
                if let latestDraft = try? await api.getLatestDraft(chapterID: loadedChapter.id) {
                    loadedDrafts[loadedChapter.id] = latestDraft
                }
            }

            chapters = loadedChapters
            chapterDrafts = loadedDrafts
            if let selectedID = selectedReadableChapterID,
               loadedChapters.contains(where: { $0.id == selectedID }) {
                selectedReadableChapterID = selectedID
            } else {
                selectedReadableChapterID = loadedChapters.first?.id
            }
            if let currentChapter = loadedChapters.first(where: { $0.id == chapter.id }) {
                chapter = currentChapter
            }
            if let currentDraft = loadedDrafts[chapter.id] {
                draft = currentDraft
                auditSummary = currentDraft.auditSummary
            }
        } catch {
            handle(error)
        }
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

    private func activeChapter(from chapters: [Chapter], novel: Novel) -> Chapter? {
        if let current = novel.currentChapterNo,
           let matched = chapters.first(where: { $0.chapterNo == current }) {
            return matched
        }
        return chapters.first(where: { $0.status != .completed }) ?? chapters.last ?? chapters.first
    }

    private func step(for status: ChapterStatus) -> ChapterStep {
        switch status {
        case .draftInput, .imported:
            .promptInput
        case .structuredPromptReady:
            .structuredPromptReview
        case .structuredPromptApproved, .draftGenerated, .revisionRequired:
            .draftReview
        case .draftApproved:
            .finalApproval
        case .canonPatchPending, .completed:
            .canonPatchReview
        }
    }

    private func placeholderChapter(for novel: Novel) -> Chapter {
        Chapter(
            id: "\(novel.id)_chapter_001",
            novelId: novel.id,
            chapterNo: 1,
            title: "第 1 章",
            status: .draftInput,
            targetWordCount: 3000,
            approvedVersionId: nil,
            currentVersionId: nil,
            canonVersionUsed: novel.currentCanonVersion
        )
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

    public var novelID: String
    public var currentCanonVersion: Int?
    public var currentChapterNo: Int?
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
        currentCanonVersion = MockData.novel.currentCanonVersion
        currentChapterNo = MockData.chapter.chapterNo
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

    public func switchNovel(novelID: String, currentCanonVersion: Int?, currentChapterNo: Int?) {
        self.novelID = novelID
        self.currentCanonVersion = currentCanonVersion
        self.currentChapterNo = currentChapterNo
        worldBibleSections = []
        characterCards = []
        memoryFacts = []
        memoryChapterFilter = ""
        selectedBaseDocument = .worldBible
        statusMessage = nil
        error = nil
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
                    canonVersion: currentCanonVersion ?? 1,
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
                    canonVersion: currentCanonVersion ?? 1
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
                    chapterNo: currentChapterNo ?? 1,
                    factType: "event",
                    summary: "",
                    participants: [],
                    location: nil,
                    evidence: "手动添加",
                    canonStatus: "confirmed",
                    canonVersion: currentCanonVersion ?? 1
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
                lastChangedChapterNo: currentChapterNo
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
            statusMessage = "基础文件已保存，检索索引已更新。"
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
    @ObservationIgnored private let api: any KnowledgeMatrixAPI

    public var novelID: String
    public var currentCanonVersion: Int?
    public var entries: [KnowledgeMatrixEntry]
    public var visibleCharacters: [String]
    public var filterText: String = ""
    public var selectedState: KnowledgeState?
    public var selectedCharacterName: String?
    public var selectedEntryID: String?
    public var isLoading: Bool = false
    public var isSaving: Bool = false
    public var statusMessage: String?
    public var error: APIError?

    public init(api: any KnowledgeMatrixAPI = MockKnowledgeMatrixAPI(), novelID: String = MockData.novel.id) {
        self.api = api
        self.novelID = novelID
        currentCanonVersion = MockData.novel.currentCanonVersion
        entries = MockData.knowledgeEntries
        visibleCharacters = ["A", "B", "C"]
    }

    public var characterFilterOptions: [String] {
        Array(Set(entries.flatMap { $0.characterKnowledge.map(\.characterName) } + visibleCharacters)).sorted()
    }

    public var filteredEntries: [KnowledgeMatrixEntry] {
        entries.filter { entry in
            let textMatches = filterText.isEmpty
                || entry.factTitle.localizedCaseInsensitiveContains(filterText)
                || entry.allowedNarration.localizedCaseInsensitiveContains(filterText)
                || entry.truthStatus.localizedCaseInsensitiveContains(filterText)

            let characterMatches = selectedCharacterName == nil
                || entry.characterKnowledge.contains(where: { $0.characterName == selectedCharacterName })

            let stateMatches = selectedState == nil
                || entry.authorKnowledge == selectedState
                || entry.readerKnowledge == selectedState
                || entry.characterKnowledge.contains(where: { $0.state == selectedState })

            return textMatches && characterMatches && stateMatches
        }
    }

    public func switchNovel(novelID: String, currentCanonVersion: Int?) {
        self.novelID = novelID
        self.currentCanonVersion = currentCanonVersion
        entries = []
        visibleCharacters = []
        filterText = ""
        selectedState = nil
        selectedCharacterName = nil
        selectedEntryID = nil
        statusMessage = nil
        error = nil
    }

    public func loadEntries(force: Bool = false) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            entries = try await api.getKnowledgeMatrixEntries(novelID: novelID)
            refreshVisibleCharacters()
            statusMessage = "Knowledge Matrix 已加载。"
        } catch {
            handle(error)
        }
    }

    public func addEntry() async {
        isSaving = true
        error = nil
        defer { isSaving = false }

        do {
            let created = try await api.createKnowledgeMatrixEntry(
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
                    canonVersion: currentCanonVersion ?? 1
                ),
                novelID: novelID
            )
            entries.append(created)
            selectedEntryID = created.id
            refreshVisibleCharacters()
            statusMessage = "知识条目已新增。"
        } catch {
            handle(error)
        }
    }

    public func deleteEntry(id: String) async {
        isSaving = true
        error = nil
        defer { isSaving = false }

        do {
            try await api.deleteKnowledgeMatrixEntry(entryID: id, novelID: novelID)
            entries.removeAll { $0.id == id }
            if selectedEntryID == id {
                selectedEntryID = nil
            }
            refreshVisibleCharacters()
            statusMessage = "知识条目已删除。"
        } catch {
            handle(error)
        }
    }

    public func saveMatrix() async {
        isSaving = true
        error = nil
        defer { isSaving = false }

        do {
            var savedEntries: [KnowledgeMatrixEntry] = []
            for entry in entries {
                savedEntries.append(try await api.updateKnowledgeMatrixEntry(entry, novelID: novelID))
            }
            entries = savedEntries
            refreshVisibleCharacters()
            statusMessage = "Knowledge Matrix 已保存。"
        } catch {
            handle(error)
        }
    }

    public func updateCharacterState(entryID: String, characterName: String, state: KnowledgeState) {
        guard
            let entryIndex = entries.firstIndex(where: { $0.id == entryID }),
            let characterIndex = entries[entryIndex].characterKnowledge.firstIndex(where: { $0.characterName == characterName })
        else {
            return
        }
        entries[entryIndex].characterKnowledge[characterIndex].state = state
    }

    private func refreshVisibleCharacters() {
        visibleCharacters = characterFilterOptions
    }

    private func handle(_ error: Error) {
        let apiError = error as? APIError ?? APIError.transport(String(describing: error))
        self.error = apiError
        statusMessage = apiError.userMessage
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
