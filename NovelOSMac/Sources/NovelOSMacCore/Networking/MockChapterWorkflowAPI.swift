import Foundation

public actor MockChapterWorkflowAPI: ChapterWorkflowAPI {
    private var prompt: String
    private var structuredPrompt: StructuredPrompt?
    private var draft: Draft?
    private var canonPatch: CanonUpdatePatch?

    public init(
        prompt: String = MockData.promptDraft,
        structuredPrompt: StructuredPrompt? = nil,
        draft: Draft? = nil,
        canonPatch: CanonUpdatePatch? = nil
    ) {
        self.prompt = prompt
        self.structuredPrompt = structuredPrompt
        self.draft = draft
        self.canonPatch = canonPatch
    }

    public func listChapters(novelID: String) async throws -> [Chapter] {
        guard novelID == MockData.novel.id else {
            throw APIError.missingResource("novel \(novelID)")
        }
        return MockData.chapters
    }

    public func submitUserPrompt(chapterID: String, prompt: String) async throws {
        guard chapterID == MockData.chapter.id else {
            throw APIError.missingResource("chapter \(chapterID)")
        }
        self.prompt = prompt
        structuredPrompt = MockData.structuredPrompt
    }

    public func getStructuredPrompt(chapterID: String) async throws -> StructuredPrompt {
        guard chapterID == MockData.chapter.id else {
            throw APIError.missingResource("chapter \(chapterID)")
        }
        if let structuredPrompt {
            return structuredPrompt
        }
        structuredPrompt = MockData.structuredPrompt
        return MockData.structuredPrompt
    }

    public func updateStructuredPrompt(_ prompt: StructuredPrompt, chapterID: String) async throws -> StructuredPrompt {
        guard chapterID == MockData.chapter.id else {
            throw APIError.missingResource("chapter \(chapterID)")
        }
        structuredPrompt = prompt
        return prompt
    }

    public func approveStructuredPrompt(chapterID: String) async throws {
        guard chapterID == MockData.chapter.id else {
            throw APIError.missingResource("chapter \(chapterID)")
        }
        if structuredPrompt == nil {
            structuredPrompt = MockData.structuredPrompt
        }
    }

    public func generateDraft(chapterID: String) async throws {
        guard chapterID == MockData.chapter.id else {
            throw APIError.missingResource("chapter \(chapterID)")
        }
        draft = MockData.draft
    }

    public func getLatestDraft(chapterID: String) async throws -> Draft {
        if let importedDraft = MockData.importedChapterDrafts.first(where: { $0.chapterId == chapterID }) {
            return importedDraft
        }
        guard chapterID == MockData.chapter.id else {
            throw APIError.missingResource("chapter \(chapterID)")
        }
        if let draft {
            return draft
        }
        draft = MockData.draft
        return MockData.draft
    }

    public func reviewDraft(chapterID: String, request: DraftReviewRequest) async throws {
        guard chapterID == MockData.chapter.id else {
            throw APIError.missingResource("chapter \(chapterID)")
        }

        switch request.decision {
        case .approve:
            if draft == nil {
                draft = MockData.draft
            }
        case .revise:
            let currentVersion = draft?.versionNo ?? MockData.draft.versionNo
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
            draft = Draft(
                id: "draft_004_v\(currentVersion + 1)",
                chapterId: MockData.chapter.id,
                versionNo: currentVersion + 1,
                text: MockData.revisedDraftText,
                wordCount: 3028,
                auditSummary: revisedSummary,
                createdAt: MockData.now
            )
        }
    }

    public func approveFinalText(chapterID: String) async throws {
        guard chapterID == MockData.chapter.id else {
            throw APIError.missingResource("chapter \(chapterID)")
        }
        canonPatch = MockData.canonPatch
    }

    public func getCanonUpdatePatch(chapterID: String) async throws -> CanonUpdatePatch {
        guard chapterID == MockData.chapter.id else {
            throw APIError.missingResource("chapter \(chapterID)")
        }
        if let canonPatch {
            return canonPatch
        }
        canonPatch = MockData.canonPatch
        return MockData.canonPatch
    }

    public func updateCanonUpdatePatch(_ patch: CanonUpdatePatch, chapterID: String) async throws -> CanonUpdatePatch {
        guard chapterID == MockData.chapter.id else {
            throw APIError.missingResource("chapter \(chapterID)")
        }
        canonPatch = patch
        return patch
    }

    public func confirmCanonUpdatePatch(chapterID: String) async throws {
        guard chapterID == MockData.chapter.id else {
            throw APIError.missingResource("chapter \(chapterID)")
        }
        if canonPatch == nil {
            canonPatch = MockData.canonPatch
        }
    }
}
