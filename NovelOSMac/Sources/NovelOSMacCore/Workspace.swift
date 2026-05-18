import Foundation

public enum Workspace: String, CaseIterable, Identifiable, Codable, Equatable, Sendable {
    case chapterStudio
    case baseFiles
    case knowledgeMatrix
    case versionsDebug
    case chaptersList
    case writingSettings

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .chapterStudio: "Chapter Studio"
        case .baseFiles: "基础文件"
        case .knowledgeMatrix: "知识矩阵"
        case .versionsDebug: "版本记录"
        case .chaptersList: "章节列表"
        case .writingSettings: "写作设置"
        }
    }

    public var systemImage: String {
        switch self {
        case .chapterStudio: "square.and.pencil"
        case .baseFiles: "doc.text"
        case .knowledgeMatrix: "tablecells"
        case .versionsDebug: "ladybug"
        case .chaptersList: "list.bullet.rectangle"
        case .writingSettings: "gearshape"
        }
    }

    public var section: WorkspaceSection {
        switch self {
        case .chapterStudio, .baseFiles, .knowledgeMatrix, .versionsDebug:
            .workspace
        case .chaptersList, .writingSettings:
            .library
        }
    }
}

public enum WorkspaceSection: String, Codable, Equatable, Sendable {
    case workspace
    case library
}

public enum ChapterStep: Int, CaseIterable, Identifiable, Codable, Comparable, Sendable {
    case promptInput = 1
    case structuredPromptReview = 2
    case draftReview = 3
    case finalApproval = 4
    case canonPatchReview = 5

    public var id: Int { rawValue }

    public static func < (lhs: ChapterStep, rhs: ChapterStep) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var title: String {
        switch self {
        case .promptInput: "输入 Prompt"
        case .structuredPromptReview: "审核结构化 Prompt"
        case .draftReview: "审核正文"
        case .finalApproval: "批准正文"
        case .canonPatchReview: "确认基础文档更新"
        }
    }

    public var subtitle: String {
        switch self {
        case .promptInput: "只写本章大致走向"
        case .structuredPromptReview: "修改、批准，进入正文"
        case .draftReview: "读正文，必要时给修改意见"
        case .finalApproval: "锁定最终章节版本"
        case .canonPatchReview: "确认 Memory / Bible / 人物卡"
        }
    }

    public var userActionIndex: String {
        "用户动作 \(rawValue) / 5"
    }
}

public enum BaseDocumentKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case worldBible
    case characterCards
    case memory

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .worldBible: "World Bible"
        case .characterCards: "Character Cards"
        case .memory: "Memory / Chapter Facts"
        }
    }

    public var summary: String {
        switch self {
        case .worldBible: "总 Bible，含文风、现实逻辑、背景、禁用写法、杂项关键设定。"
        case .characterCards: "人物稳定特征、当前状态、人物关系、说话方式。"
        case .memory: "章节事实、历史事件、地点状态、物品状态。"
        }
    }
}
