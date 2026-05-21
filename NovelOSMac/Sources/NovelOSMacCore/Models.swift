import Foundation

public enum AnyCodable: Codable, Equatable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: AnyCodable])
    case array([AnyCodable])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: AnyCodable].self) {
            self = .object(value)
        } else if let value = try? container.decode([AnyCodable].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value.")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

public extension AnyCodable {
    var displayString: String? {
        switch self {
        case .string(let value):
            value
        case .int(let value):
            String(value)
        case .double(let value):
            String(value)
        case .bool(let value):
            value ? "true" : "false"
        case .object(let value):
            value["summary"]?.displayString
                ?? value["text"]?.displayString
                ?? value["content"]?.displayString
                ?? value["value"]?.displayString
        case .array, .null:
            nil
        }
    }
}

private extension KeyedDecodingContainer {
    func decodeStringOrSummary(forKey key: Key, default defaultValue: String = "") throws -> String {
        if let value = try? decode(String.self, forKey: key) {
            return value
        }
        if let value = try? decode(AnyCodable.self, forKey: key) {
            return value.displayString ?? defaultValue
        }
        return defaultValue
    }
}

public struct Novel: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public var title: String
    public var genre: String?
    public var status: String
    public var language: String
    public var currentChapterNo: Int?
    public var currentCanonVersion: Int?
    public var bootstrapStatus: BootstrapStatus

    public init(
        id: String,
        title: String,
        genre: String?,
        status: String = "active",
        language: String = "zh-Hans",
        currentChapterNo: Int?,
        currentCanonVersion: Int?,
        bootstrapStatus: BootstrapStatus
    ) {
        self.id = id
        self.title = title
        self.genre = genre
        self.status = status
        self.language = language
        self.currentChapterNo = currentChapterNo
        self.currentCanonVersion = currentCanonVersion
        self.bootstrapStatus = bootstrapStatus
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case genre
        case status
        case language
        case currentChapterNo
        case currentCanonVersion
        case bootstrapStatus
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        genre = try container.decodeIfPresent(String.self, forKey: .genre)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "active"
        language = try container.decodeIfPresent(String.self, forKey: .language) ?? "zh-Hans"
        currentChapterNo = try container.decodeIfPresent(Int.self, forKey: .currentChapterNo)
        currentCanonVersion = try container.decodeIfPresent(Int.self, forKey: .currentCanonVersion)
        bootstrapStatus = try container.decode(BootstrapStatus.self, forKey: .bootstrapStatus)
    }
}

public struct NovelCreateRequest: Codable, Equatable, Sendable {
    public var title: String
    public var genre: String?
    public var language: String

    public init(title: String, genre: String?, language: String = "zh-Hans") {
        self.title = title
        self.genre = genre
        self.language = language
    }
}

public struct ChapterCreateRequest: Codable, Equatable, Sendable {
    public var chapterNo: Int
    public var title: String?
    public var targetWordCount: Int

    public init(chapterNo: Int, title: String?, targetWordCount: Int = 3000) {
        self.chapterNo = chapterNo
        self.title = title
        self.targetWordCount = targetWordCount
    }
}

public struct BootstrapChapterInput: Codable, Equatable, Sendable {
    public var chapterNo: Int
    public var title: String?
    public var text: String

    public init(chapterNo: Int, title: String?, text: String) {
        self.chapterNo = chapterNo
        self.title = title
        self.text = text
    }
}

public struct BootstrapImportRequest: Codable, Equatable, Sendable {
    public var chapters: [BootstrapChapterInput]

    public init(chapters: [BootstrapChapterInput]) {
        self.chapters = chapters
    }
}

public struct NovelBootstrapStatus: Codable, Equatable, Sendable {
    public var novelId: String
    public var status: BootstrapStatus
    public var importId: String?
    public var importedChapterCount: Int
    public var analysisReady: Bool
    public var updatedAt: Date?

    public init(
        novelId: String,
        status: BootstrapStatus,
        importId: String?,
        importedChapterCount: Int,
        analysisReady: Bool,
        updatedAt: Date?
    ) {
        self.novelId = novelId
        self.status = status
        self.importId = importId
        self.importedChapterCount = importedChapterCount
        self.analysisReady = analysisReady
        self.updatedAt = updatedAt
    }
}

public struct BootstrapAnalyzeResult: Codable, Equatable, Sendable {
    public var novelId: String
    public var status: BootstrapStatus
    public var importId: String
    public var analysis: [String: AnyCodable]

    public init(novelId: String, status: BootstrapStatus, importId: String, analysis: [String: AnyCodable]) {
        self.novelId = novelId
        self.status = status
        self.importId = importId
        self.analysis = analysis
    }
}

public enum BootstrapStatus: String, Equatable, Sendable {
    case notStarted = "not_started"
    case importing
    case imported
    case analyzing
    case analyzed
    case completed
    case failed

    public var displayName: String {
        switch self {
        case .notStarted: "未导入"
        case .importing: "导入中"
        case .imported: "已导入"
        case .analyzing: "分析中"
        case .analyzed: "已分析"
        case .completed: "已完成"
        case .failed: "失败"
        }
    }
}

extension BootstrapStatus: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case "notStarted", "not_started":
            self = .notStarted
        case "importing":
            self = .importing
        case "imported":
            self = .imported
        case "analyzing":
            self = .analyzing
        case "analyzed":
            self = .analyzed
        case "completed":
            self = .completed
        case "failed":
            self = .failed
        default:
            self = .notStarted
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
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

public struct LLMProvider: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public var name: String
    public var baseUrl: String
    public var model: String
    public var timeoutSeconds: Double
    public var hasApiKey: Bool
    public var isActive: Bool

    public init(id: String, name: String, baseUrl: String, model: String, timeoutSeconds: Double, hasApiKey: Bool, isActive: Bool) {
        self.id = id
        self.name = name
        self.baseUrl = baseUrl
        self.model = model
        self.timeoutSeconds = timeoutSeconds
        self.hasApiKey = hasApiKey
        self.isActive = isActive
    }
}

public struct LLMProvidersResponse: Codable, Equatable, Sendable {
    public var activeProviderId: String?
    public var providers: [LLMProvider]

    public init(activeProviderId: String?, providers: [LLMProvider]) {
        self.activeProviderId = activeProviderId
        self.providers = providers
    }
}

public struct LLMProviderUpsert: Codable, Equatable, Sendable {
    public var name: String
    public var baseUrl: String
    public var model: String
    public var apiKey: String?
    public var timeoutSeconds: Double

    public init(name: String, baseUrl: String, model: String, apiKey: String?, timeoutSeconds: Double) {
        self.name = name
        self.baseUrl = baseUrl
        self.model = model
        self.apiKey = apiKey
        self.timeoutSeconds = timeoutSeconds
    }
}

public struct ActiveLLMProviderRequest: Codable, Equatable, Sendable {
    public var providerId: String

    public init(providerId: String) {
        self.providerId = providerId
    }
}

public struct LLMTestRequest: Codable, Equatable, Sendable {
    public var providerId: String?
    public var prompt: String

    public init(providerId: String?, prompt: String) {
        self.providerId = providerId
        self.prompt = prompt
    }
}

public struct LLMTestResponse: Codable, Equatable, Sendable {
    public var ok: Bool
    public var providerId: String
    public var model: String
    public var message: String
    public var tokenUsage: [String: AnyCodable]

    public init(ok: Bool, providerId: String, model: String, message: String, tokenUsage: [String: AnyCodable]) {
        self.ok = ok
        self.providerId = providerId
        self.model = model
        self.message = message
        self.tokenUsage = tokenUsage
    }
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
    public var sectionKey: String? = nil
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
    public var currentState: CharacterCurrentState
    public var dialogueStyle: String
    public var relationships: [CharacterRelationship]
    public var forbiddenBehavior: [String]
    public var lastActiveChapterNo: Int?
    public var canonVersion: Int

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case aliases
        case role
        case stableTraits
        case currentState
        case dialogueStyle
        case relationships
        case forbiddenBehavior
        case lastActiveChapterNo
        case canonVersion
    }

    public init(
        id: String,
        name: String,
        aliases: [String],
        role: String,
        stableTraits: [String],
        currentState: CharacterCurrentState,
        dialogueStyle: String,
        relationships: [CharacterRelationship],
        forbiddenBehavior: [String],
        lastActiveChapterNo: Int?,
        canonVersion: Int
    ) {
        self.id = id
        self.name = name
        self.aliases = aliases
        self.role = role
        self.stableTraits = stableTraits
        self.currentState = currentState
        self.dialogueStyle = dialogueStyle
        self.relationships = relationships
        self.forbiddenBehavior = forbiddenBehavior
        self.lastActiveChapterNo = lastActiveChapterNo
        self.canonVersion = canonVersion
    }

    public init(
        id: String,
        name: String,
        aliases: [String],
        role: String,
        stableTraits: [String],
        currentState: String,
        dialogueStyle: String,
        relationships: [CharacterRelationship],
        forbiddenBehavior: [String],
        lastActiveChapterNo: Int?,
        canonVersion: Int
    ) {
        self.init(
            id: id,
            name: name,
            aliases: aliases,
            role: role,
            stableTraits: stableTraits,
            currentState: CharacterCurrentState(summary: currentState),
            dialogueStyle: dialogueStyle,
            relationships: relationships,
            forbiddenBehavior: forbiddenBehavior,
            lastActiveChapterNo: lastActiveChapterNo,
            canonVersion: canonVersion
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        aliases = try container.decodeIfPresent([String].self, forKey: .aliases) ?? []
        role = try container.decodeIfPresent(String.self, forKey: .role) ?? ""
        stableTraits = try container.decodeIfPresent([String].self, forKey: .stableTraits) ?? []
        currentState = try container.decodeIfPresent(CharacterCurrentState.self, forKey: .currentState) ?? CharacterCurrentState()
        dialogueStyle = try container.decodeStringOrSummary(forKey: .dialogueStyle)
        relationships = try container.decodeIfPresent([CharacterRelationship].self, forKey: .relationships) ?? []
        forbiddenBehavior = try container.decodeIfPresent([String].self, forKey: .forbiddenBehavior) ?? []
        lastActiveChapterNo = try container.decodeIfPresent(Int.self, forKey: .lastActiveChapterNo)
        canonVersion = try container.decodeIfPresent(Int.self, forKey: .canonVersion) ?? 1
    }
}

public struct CharacterCurrentState: Codable, Equatable, Sendable {
    public var physical: String
    public var emotional: String
    public var goal: String
    public var summary: String

    public init(physical: String = "", emotional: String = "", goal: String = "", summary: String = "") {
        self.physical = physical
        self.emotional = emotional
        self.goal = goal
        self.summary = summary
    }

    public var displaySummary: String {
        summary.isEmpty ? [physical, emotional, goal].filter { !$0.isEmpty }.joined(separator: " / ") : summary
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self.init(summary: value)
            return
        }
        if let value = try? container.decode([String: String].self) {
            self.init(
                physical: value["physical"] ?? "",
                emotional: value["emotional"] ?? "",
                goal: value["goal"] ?? "",
                summary: value["summary"] ?? value["text"] ?? value["content"] ?? ""
            )
            return
        }
        if let value = try? container.decode([String: AnyCodable].self) {
            self.init(
                physical: value["physical"]?.displayString ?? "",
                emotional: value["emotional"]?.displayString ?? "",
                goal: value["goal"]?.displayString ?? "",
                summary: value["summary"]?.displayString
                    ?? value["text"]?.displayString
                    ?? value["content"]?.displayString
                    ?? ""
            )
            return
        }
        self.init()
    }
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
    public var visibility: [String: KnowledgeState]
    public var allowedNarration: String
    public var canonVersion: Int

    private enum CodingKeys: String, CodingKey {
        case id
        case factTitle
        case truthStatus
        case authorKnowledge
        case readerKnowledge
        case visibility
        case characterKnowledge
        case allowedNarration
        case canonVersion
    }

    public init(
        id: String,
        factTitle: String,
        truthStatus: String,
        authorKnowledge: KnowledgeState,
        readerKnowledge: KnowledgeState,
        visibility: [String: KnowledgeState],
        allowedNarration: String,
        canonVersion: Int
    ) {
        self.id = id
        self.factTitle = factTitle
        self.truthStatus = truthStatus
        self.authorKnowledge = authorKnowledge
        self.readerKnowledge = readerKnowledge
        self.visibility = visibility
        self.allowedNarration = allowedNarration
        self.canonVersion = canonVersion
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        factTitle = try container.decode(String.self, forKey: .factTitle)
        truthStatus = try container.decodeIfPresent(String.self, forKey: .truthStatus) ?? ""
        authorKnowledge = try container.decodeIfPresent(KnowledgeState.self, forKey: .authorKnowledge) ?? .unknown
        readerKnowledge = try container.decodeIfPresent(KnowledgeState.self, forKey: .readerKnowledge) ?? .readerUnknown
        var normalizedVisibility = try container.decodeIfPresent([String: KnowledgeState].self, forKey: .visibility) ?? [:]
        if let legacyKnowledge = try container.decodeIfPresent([CharacterKnowledge].self, forKey: .characterKnowledge) {
            for item in legacyKnowledge {
                let key = item.characterName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? item.characterId
                    : item.characterName
                guard !key.isEmpty else { continue }
                normalizedVisibility[key] = item.state
            }
        }
        visibility = normalizedVisibility
        allowedNarration = try container.decodeStringOrSummary(forKey: .allowedNarration)
        canonVersion = try container.decodeIfPresent(Int.self, forKey: .canonVersion) ?? 1
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(factTitle, forKey: .factTitle)
        try container.encode(truthStatus, forKey: .truthStatus)
        try container.encode(authorKnowledge, forKey: .authorKnowledge)
        try container.encode(readerKnowledge, forKey: .readerKnowledge)
        try container.encode(visibility, forKey: .visibility)
        try container.encode(allowedNarration, forKey: .allowedNarration)
        try container.encode(canonVersion, forKey: .canonVersion)
    }
}

public struct CharacterKnowledge: Identifiable, Codable, Equatable, Sendable {
    public var id: String { characterId }
    public var characterId: String
    public var characterName: String
    public var state: KnowledgeState
}

public extension KnowledgeMatrixEntry {
    var characterVisibility: [String: KnowledgeState] {
        visibility.filter { key, _ in
            let normalized = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return normalized != "author" && normalized != "reader" && !normalized.isEmpty
        }
    }
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
    public var novelId: String?
    public var chapterId: String?
    public var agentName: String
    public var runType: String
    public var model: String?
    public var summary: String
    public var status: String
    public var payload: [String: AnyCodable]
    public var inputPayload: [String: AnyCodable]
    public var outputPayload: [String: AnyCodable]
    public var inputJson: [String: AnyCodable]
    public var outputJson: [String: AnyCodable]
    public var tokenUsage: [String: AnyCodable]
    public var errorMessage: String?
    public var startedAt: Double?
    public var completedAt: String?
    public var latencyMs: Double?
    public var createdAt: Double
    public var timestampLabel: String

    public init(
        id: String,
        novelId: String? = nil,
        chapterId: String? = nil,
        agentName: String,
        runType: String = "workflow",
        model: String? = nil,
        summary: String,
        status: String,
        payload: [String: AnyCodable] = [:],
        inputPayload: [String: AnyCodable] = [:],
        outputPayload: [String: AnyCodable] = [:],
        inputJson: [String: AnyCodable] = [:],
        outputJson: [String: AnyCodable] = [:],
        tokenUsage: [String: AnyCodable] = [:],
        errorMessage: String? = nil,
        startedAt: Double? = nil,
        completedAt: String? = nil,
        latencyMs: Double? = nil,
        createdAt: Double = 0,
        timestampLabel: String = "—"
    ) {
        self.id = id
        self.novelId = novelId
        self.chapterId = chapterId
        self.agentName = agentName
        self.runType = runType
        self.model = model
        self.summary = summary
        self.status = status
        self.payload = payload
        self.inputPayload = inputPayload
        self.outputPayload = outputPayload
        self.inputJson = inputJson
        self.outputJson = outputJson
        self.tokenUsage = tokenUsage
        self.errorMessage = errorMessage
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.latencyMs = latencyMs
        self.createdAt = createdAt
        self.timestampLabel = timestampLabel == "—" ? Self.timestampLabel(from: createdAt) : timestampLabel
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case novelId
        case chapterId
        case agentName
        case runType
        case model
        case summary
        case status
        case payload
        case inputPayload
        case outputPayload
        case inputJson
        case outputJson
        case tokenUsage
        case errorMessage
        case startedAt
        case completedAt
        case latencyMs
        case createdAt
        case timestampLabel
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        novelId = try container.decodeIfPresent(String.self, forKey: .novelId)
        chapterId = try container.decodeIfPresent(String.self, forKey: .chapterId)
        agentName = try container.decode(String.self, forKey: .agentName)
        runType = try container.decodeIfPresent(String.self, forKey: .runType) ?? "workflow"
        model = try container.decodeIfPresent(String.self, forKey: .model)
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "unknown"
        payload = try container.decodeIfPresent([String: AnyCodable].self, forKey: .payload) ?? [:]
        inputPayload = try container.decodeIfPresent([String: AnyCodable].self, forKey: .inputPayload) ?? [:]
        outputPayload = try container.decodeIfPresent([String: AnyCodable].self, forKey: .outputPayload) ?? [:]
        inputJson = try container.decodeIfPresent([String: AnyCodable].self, forKey: .inputJson) ?? inputPayload
        outputJson = try container.decodeIfPresent([String: AnyCodable].self, forKey: .outputJson) ?? outputPayload
        tokenUsage = try container.decodeIfPresent([String: AnyCodable].self, forKey: .tokenUsage) ?? [:]
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        startedAt = try container.decodeIfPresent(Double.self, forKey: .startedAt)
        completedAt = try container.decodeIfPresent(String.self, forKey: .completedAt)
        latencyMs = try container.decodeIfPresent(Double.self, forKey: .latencyMs)
        createdAt = try container.decodeIfPresent(Double.self, forKey: .createdAt) ?? 0
        timestampLabel = try container.decodeIfPresent(String.self, forKey: .timestampLabel) ?? Self.timestampLabel(from: createdAt)
    }

    private static func timestampLabel(from createdAt: Double) -> String {
        guard createdAt > 0 else { return "—" }
        let date = Date(timeIntervalSinceReferenceDate: createdAt)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

public struct DraftStreamErrorPayload: Codable, Equatable, Sendable {
    public var kind: String
    public var message: String
    public var retryable: Bool
    public var partialWordCount: Int?
}

public struct DraftStreamEvent: Codable, Equatable, Sendable {
    public var event: String
    public var delta: String?
    public var wordCount: Int?
    public var tokens: [String: AnyCodable]?
    public var draftId: String?
    public var versionNo: Int?
    public var error: DraftStreamErrorPayload?
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
