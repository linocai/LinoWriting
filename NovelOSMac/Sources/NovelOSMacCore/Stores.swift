import Foundation
import Observation

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

@Observable
public final class ChapterWorkflowStore {
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

    public init() {
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

    public func generateStructuredPrompt() {
        guard canGenerateStructuredPrompt else {
            statusMessage = "Prompt 至少需要 10 个字。"
            return
        }
        isLoading = true
        structuredPrompt = MockData.structuredPrompt
        chapter.status = .structuredPromptReady
        unlock(.structuredPromptReview)
        currentStep = .structuredPromptReview
        isLoading = false
        statusMessage = "结构化 Prompt 已生成。"
    }

    public func approveStructuredPromptAndGenerateDraft() {
        if structuredPrompt == nil {
            structuredPrompt = MockData.structuredPrompt
        }
        isLoading = true
        draft = MockData.draft
        auditSummary = MockData.auditSummary
        chapter.status = .draftGenerated
        chapter.currentVersionId = MockData.draft.id
        unlock(.draftReview)
        currentStep = .draftReview
        isLoading = false
        statusMessage = "正文已生成。"
    }

    public func requestRevision() {
        guard !reviewFeedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            statusMessage = "请先填写修改意见。"
            return
        }

        let revisedSummary = AuditSummary(
            s0Count: 0,
            s1Count: 1,
            s2Count: 1,
            illegalNamedEntityCount: 0,
            inactiveCharacterAppearanceCount: 0,
            knowledgeViolationCount: 0,
            newNamedEntityCount: 0,
            issues: [
                AuditIssue(
                    id: "audit_s1_revised",
                    severity: .s1,
                    type: "语气仍可更克制",
                    location: "对话中段",
                    message: "B 的回应已经收敛，仍可进一步减少解释性台词。",
                    suggestion: "保留停顿与动作，不增加背景说明。"
                ),
                AuditIssue(
                    id: "audit_s2_revised",
                    severity: .s2,
                    type: "节奏建议",
                    location: "结尾",
                    message: "C 的线索足够短促，可保持当前处理。",
                    suggestion: nil
                )
            ]
        )

        let nextVersion = (draft?.versionNo ?? MockData.draft.versionNo) + 1
        draft = Draft(
            id: "draft_004_v\(nextVersion)",
            chapterId: MockData.chapter.id,
            versionNo: nextVersion,
            text: MockData.revisedDraftText,
            wordCount: 3028,
            auditSummary: revisedSummary,
            createdAt: MockData.now
        )
        auditSummary = revisedSummary
        chapter.status = .draftGenerated
        currentStep = .draftReview
        unlock(.draftReview)
        statusMessage = "已根据你的意见生成新版本。"
    }

    @discardableResult
    public func approveDraftForFinalReview() -> Bool {
        if let finalApprovalBlockedReason {
            statusMessage = finalApprovalBlockedReason
            return false
        }

        chapter.status = .draftApproved
        unlock(.finalApproval)
        currentStep = .finalApproval
        statusMessage = "正文已进入最终批准。"
        return true
    }

    public func approveFinalTextAndPreparePatch() {
        canonPatch = MockData.canonPatch
        chapter.status = .canonPatchPending
        chapter.approvedVersionId = draft?.id
        unlock(.canonPatchReview)
        currentStep = .canonPatchReview
        statusMessage = "基础文档更新已准备好。"
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

    public func savePatchForLater() {
        statusMessage = "基础文档更新已保存，可稍后确认。"
    }

    public func confirmCanonPatch() {
        chapter.status = .completed
        novel.currentCanonVersion = canonPatch?.targetCanonVersion ?? novel.currentCanonVersion
        statusMessage = "本章已完成，Canon 已更新。"
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
}

@Observable
public final class BaseDocumentsStore {
    public var worldBibleSections: [WorldBibleSection]
    public var characterCards: [CharacterCard]
    public var memoryFacts: [MemoryFact]
    public var selectedBaseDocument: BaseDocumentKind = .worldBible
    public var isSaving: Bool = false
    public var isIndexing: Bool = false
    public var statusMessage: String?

    public init() {
        worldBibleSections = MockData.worldBibleSections
        characterCards = MockData.characterCards
        memoryFacts = MockData.memoryFacts
    }

    public func addWorldBibleSection() {
        worldBibleSections.append(
            WorldBibleSection(
                id: "wb_\(UUID().uuidString)",
                title: "新 Section",
                content: "",
                tags: [],
                importance: .medium,
                activationPolicy: .manualOnly,
                canonVersion: MockData.novel.currentCanonVersion ?? 12,
                updatedAt: Date()
            )
        )
        selectedBaseDocument = .worldBible
    }

    public func addCharacter() {
        characterCards.append(
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
            )
        )
        selectedBaseDocument = .characterCards
    }

    public func addMemoryFact() {
        memoryFacts.append(
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
            )
        )
        selectedBaseDocument = .memory
    }

    public func saveChanges() {
        isSaving = true
        isIndexing = true
        statusMessage = "基础文件已保存，后台 reindex 已完成。"
        isSaving = false
        isIndexing = false
    }
}

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
