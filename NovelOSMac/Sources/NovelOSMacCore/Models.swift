import Foundation

public struct Novel: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public var title: String
    public var genre: String?
    public var currentChapterNo: Int?
    public var currentCanonVersion: Int?
    public var bootstrapStatus: BootstrapStatus
}

public enum BootstrapStatus: String, Codable, Equatable, Sendable {
    case notStarted
    case importing
    case analyzing
    case completed
    case failed
}

public struct Chapter: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let novelId: String
    public var chapterNo: Int
    public var title: String?
    public var status: ChapterStatus
    public var targetWordCount: Int
    public var approvedVersionId: String?
    public var currentVersionId: String?
    public var canonVersionUsed: Int?
}

public enum ChapterStatus: String, Codable, Equatable, Sendable {
    case imported
    case draftInput
    case structuredPromptReady
    case structuredPromptApproved
    case draftGenerated
    case revisionRequired
    case draftApproved
    case canonPatchPending
    case completed
}

public struct StructuredPrompt: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let chapterId: String
    public var chapterGoal: String
    public var mustHappen: [String]
    public var mustNotHappen: [String]
    public var allowedNamedEntities: [AllowedEntity]
    public var narrativeStyle: String
    public var activationSummary: ActivationSummary?
    public var version: Int
}

public struct AllowedEntity: Identifiable, Codable, Equatable, Sendable {
    public var id: String { name + activation.rawValue }
    public var name: String
    public var activation: ActivationState
    public var mentionBudget: Int?
}

public enum ActivationState: String, Codable, Equatable, Sendable {
    case active = "ACTIVE"
    case mentionAllowed = "MENTION_ALLOWED"
    case background = "BACKGROUND"
    case lockedOut = "LOCKED_OUT"
    case newAllowed = "NEW_ALLOWED"

    public var displayName: String {
        switch self {
        case .active: "本章出场"
        case .mentionAllowed: "弱提及"
        case .background: "背景可提"
        case .lockedOut: "不可使用"
        case .newAllowed: "新角色已批准"
        }
    }
}

public struct ActivationSummary: Codable, Equatable, Sendable {
    public var activeCast: [String]
    public var allowedNamesCount: Int
    public var mentionBudgetTotal: Int
    public var newNamedCharacterPolicy: String
}

public struct Draft: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let chapterId: String
    public var versionNo: Int
    public var text: String
    public var wordCount: Int
    public var auditSummary: AuditSummary?
    public var createdAt: Date
}

public struct AuditSummary: Codable, Equatable, Sendable {
    public var s0Count: Int
    public var s1Count: Int
    public var s2Count: Int
    public var illegalNamedEntityCount: Int
    public var inactiveCharacterAppearanceCount: Int
    public var knowledgeViolationCount: Int
    public var newNamedEntityCount: Int
    public var issues: [AuditIssue]
}

public struct AuditIssue: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public var severity: AuditSeverity
    public var type: String
    public var location: String?
    public var message: String
    public var suggestion: String?
}

public enum AuditSeverity: String, Codable, Equatable, Sendable {
    case s0 = "S0"
    case s1 = "S1"
    case s2 = "S2"
}

public struct CanonUpdatePatch: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let chapterId: String
    public var targetCanonVersion: Int
    public var items: [CanonPatchItem]
}

public struct CanonPatchItem: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public var target: CanonPatchTarget
    public var title: String
    public var summary: String
    public var proposedAction: PatchUserDecision
    public var editablePayload: String?
}

public enum CanonPatchTarget: String, Codable, Equatable, Sendable {
    case memory = "Memory"
    case character = "Character"
    case knowledge = "Knowledge"
    case worldBible = "WorldBible"
}

public enum PatchUserDecision: String, Codable, CaseIterable, Identifiable, Sendable {
    case accept
    case modify
    case reject

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .accept: "接受"
        case .modify: "修改"
        case .reject: "拒绝"
        }
    }
}

public struct WorldBibleSection: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public var title: String
    public var content: String
    public var tags: [String]
    public var importance: ImportanceLevel
    public var activationPolicy: ActivationPolicy
    public var canonVersion: Int
    public var updatedAt: Date
}

public enum ImportanceLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case low
    case medium
    case high
    case critical

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .low: "低"
        case .medium: "中"
        case .high: "高"
        case .critical: "关键"
        }
    }
}

public enum ActivationPolicy: String, Codable, CaseIterable, Identifiable, Sendable {
    case alwaysInContextBrief = "always_in_context_brief"
    case alwaysConsidered = "always_considered"
    case tagMatched = "tag_matched"
    case manualOnly = "manual_only"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .alwaysInContextBrief: "总是进入简报"
        case .alwaysConsidered: "总是参与筛选"
        case .tagMatched: "标签命中时进入"
        case .manualOnly: "仅手动调用"
        }
    }
}

public struct CharacterCard: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public var name: String
    public var aliases: [String]
    public var role: String
    public var stableTraits: [String]
    public var currentState: String
    public var dialogueStyle: String
    public var relationships: [CharacterRelationship]
    public var forbiddenBehavior: [String]
    public var lastActiveChapterNo: Int?
    public var canonVersion: Int
}

public struct CharacterRelationship: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public var targetCharacterName: String
    public var relationshipSummary: String
    public var currentTension: String?
    public var lastChangedChapterNo: Int?
}

public struct KnowledgeMatrixEntry: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public var factTitle: String
    public var truthStatus: String
    public var authorKnowledge: KnowledgeState
    public var readerKnowledge: KnowledgeState
    public var characterKnowledge: [CharacterKnowledge]
    public var allowedNarration: String
    public var canonVersion: Int
}

public struct CharacterKnowledge: Identifiable, Codable, Equatable, Sendable {
    public var id: String { characterId }
    public var characterId: String
    public var characterName: String
    public var state: KnowledgeState
}

public enum KnowledgeState: String, Codable, CaseIterable, Identifiable, Sendable {
    case known
    case unknown
    case suspects
    case hinted
    case partial
    case mayKnow = "may_know"
    case readerKnown = "reader_known"
    case readerUnknown = "reader_unknown"
    case authorOnly = "author_only"
    case stronglySuspects = "strongly_suspects"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .known: "已知"
        case .unknown: "未知"
        case .suspects: "怀疑"
        case .hinted: "被暗示"
        case .partial: "部分知道"
        case .mayKnow: "可能知道"
        case .readerKnown: "读者已知"
        case .readerUnknown: "读者未知"
        case .authorOnly: "作者限定"
        case .stronglySuspects: "强烈怀疑"
        }
    }
}

public struct MemoryFact: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public var chapterNo: Int
    public var factType: String
    public var summary: String
    public var participants: [String]
    public var location: String?
    public var evidence: String
    public var canonStatus: String
    public var canonVersion: Int
}

public struct AgentRun: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public var agentName: String
    public var summary: String
    public var status: String
    public var timestampLabel: String
}

public struct ChapterVersionSnapshot: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public var chapterId: String
    public var versionNo: Int
    public var kind: String
    public var status: String
    public var wordCount: Int
    public var auditSummary: AuditSummary?
    public var note: String
    public var createdAtLabel: String
}

public struct DebugExportPayload: Codable, Equatable, Sendable {
    public var exportedAt: Date
    public var novel: Novel
    public var chapter: Chapter
    public var contextPackJSON: String
    public var agentRuns: [AgentRun]
    public var chapterVersions: [ChapterVersionSnapshot]

    enum CodingKeys: String, CodingKey {
        case exportedAt
        case novel
        case chapter
        case contextPackJSON = "contextPackJson"
        case agentRuns
        case chapterVersions
    }
}

public extension DebugExportPayload {
    func prettyPrintedJSON() throws -> String {
        let encoder = APIJSONCoding.makeEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

public struct ToastState: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public var message: String
    public var kind: ToastKind

    public init(id: String, message: String, kind: ToastKind) {
        self.id = id
        self.message = message
        self.kind = kind
    }
}

public enum ToastKind: String, Codable, Equatable, Sendable {
    case success
    case warning
    case error
    case info
}
