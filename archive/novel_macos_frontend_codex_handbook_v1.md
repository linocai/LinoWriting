# AI 小说操作系统 macOS 前端施工指导手册 v1

> 目标读者：Codex / SwiftUI 前端施工队  
> 目标平台：macOS App，后续可扩展 iOS 版本  
> 原型来源：`novel_macos_frontend_prototype_v1.html`  
> 后端依据：`novel_ai_backend_plan_v1.md`  
> 产品定位：不是聊天续写器，而是“小说操作系统”的章节工作台

---

## 0. 施工总目标

把 HTML 原型实现为一个可运行的 macOS SwiftUI App。第一版重点不是炫技，而是把以下体验跑通：

```text
用户只做 5 个动作：
1. 输入本章 Prompt
2. 审核 / 修改 / 批准结构化 Prompt
3. 审核正文，必要时提交修改意见
4. 批准正文
5. 确认基础文档更新
```

前端必须把后端复杂流程收在后台，不把用户拖进 Agent 编排、Context Pack、Audit Report、Revision Plan 的细节里。

HTML 原型已经确定的信息架构如下：

```text
App Shell
├─ 左侧 Sidebar
│  ├─ Current Novel Card
│  ├─ Workspace
│  │  ├─ Chapter Studio
│  │  ├─ 基础文件
│  │  ├─ Knowledge Matrix
│  │  └─ 版本与调试
│  └─ Library
│     ├─ 章节列表
│     └─ 写作设置
├─ 中间 Main Workspace
│  ├─ Chapter Studio 五步流程
│  ├─ 基础文件编辑器
│  ├─ Knowledge Matrix 表格
│  ├─ 版本与调试
│  ├─ 章节列表
│  └─ 写作设置
└─ 右侧 Inspector
   ├─ 本章安全边界
   ├─ 后台运行状态
   ├─ 用户只需关心
   └─ macOS 交互建议
```

---

## 1. 硬性产品约束

这些约束必须落实到代码、组件和 API 流程里。

### 1.1 不做聊天 UI

禁止把主流程做成：

```text
用户消息 → AI 消息 → 用户消息 → AI 消息
```

应该做成：

```text
章节资产 → 当前步骤 → 表单 / 编辑器 / 审核面板 → 版本记录
```

Prompt 是章节指令，不是普通聊天消息。

### 1.2 不做 Scene Plan

后端已确认：

- 每章整体生成。
- 每章最多两个自然场景。
- 不需要 `ScenePlan` 数据模型。
- 不需要按 scene 调用写作 Agent。
- 前端不得出现“添加场景 / 拆分场景 / 场景生成进度”等主流程操作。

如果结构化 Prompt 中提到两个场景，只作为普通字段展示和编辑，不做独立工作流。

### 1.3 用户主流程只允许五类动作

前端主流程只允许用户做：

1. 输入 Prompt。
2. 审核结构化 Prompt。
3. 审核正文。
4. 批准正文。
5. 确认基础文档更新。

以下内容可以存在，但只能放在 Inspector 或“版本与调试”里，不能成为主流程必选步骤：

- Context Pack 审核。
- Agent 调用计划审核。
- Revision Plan 审核。
- Audit Report 逐条确认。
- 检索结果确认。
- Prompt Expander 中间日志。
- Extraction Agent 中间日志。

### 1.4 基础文件必须可手动编辑

基础文件包括：

```text
World Bible
Character Cards
Knowledge Matrix
Memory / Chapter Facts
```

要求：

- World Bible 是总 Bible，不是狭义世界规则。
- Style Bible 已经合并进 World Bible。
- 人物关系合并进 Character Card。
- 本版不做伏笔 / 悬念表。
- 基础文件编辑后必须触发保存、版本记录和后台 reindex。

### 1.5 写作安全边界必须可见但不打扰

HTML 右侧 Inspector 的意义是：

```text
让用户知道系统正在兜底，但不要求用户亲自管理兜底机制。
```

因此右侧可以展示：

- Active Cast。
- Allowed Names 数量。
- Mention Budget。
- 新增命名角色策略。
- Context Compiler 状态。
- Knowledge Guard 状态。
- Named Entity Linter 状态。

但不要要求用户点击“批准 Context Pack”。

---

## 2. 推荐技术栈

### 2.1 App 架构

建议使用：

```text
SwiftUI + Observation + async/await + URLSession + JSON Codable
```

可选本地持久化：

```text
SwiftData，用于缓存小说列表、章节列表、草稿、最近打开状态、离线编辑快照。
```

推荐最低目标：

```text
macOS 14+
```

原因：macOS 14+ 可以更自然地使用 Observation / `@Observable`、SwiftData、SwiftUI Inspector 等现代 API。若必须支持更低版本，需要改用 `ObservableObject` / `@Published` 和自定义右侧栏。

### 2.2 官方技术依据

施工时以 Apple 官方文档为准：

- `NavigationSplitView`：用于两栏 / 三栏 macOS 导航结构。  
  https://developer.apple.com/documentation/swiftui/navigationsplitview
- SwiftUI Inspector：用于右侧细节 / 检查器区域。  
  https://developer.apple.com/videos/play/wwdc2023/10161/
- Observation / `@Observable`：用于新式状态管理。  
  https://developer.apple.com/documentation/observation/observable
- SwiftData / `ModelContainer`：用于本地模型持久化。  
  https://developer.apple.com/documentation/swiftdata/modelcontainer
- macOS Split View HIG：用于三栏布局体验。  
  https://developer.apple.com/design/human-interface-guidelines/split-views

---

## 3. 项目目录建议

建议 Codex 按以下结构施工：

```text
NovelOSMac/
├─ App/
│  ├─ NovelOSMacApp.swift
│  ├─ AppEnvironment.swift
│  └─ AppConstants.swift
├─ Models/
│  ├─ Novel.swift
│  ├─ Chapter.swift
│  ├─ ChapterWorkflowState.swift
│  ├─ StructuredPrompt.swift
│  ├─ Draft.swift
│  ├─ AuditSummary.swift
│  ├─ CanonUpdatePatch.swift
│  ├─ WorldBible.swift
│  ├─ CharacterCard.swift
│  ├─ KnowledgeMatrix.swift
│  ├─ MemoryFact.swift
│  └─ AgentRun.swift
├─ Networking/
│  ├─ APIClient.swift
│  ├─ APIError.swift
│  ├─ Endpoint.swift
│  ├─ DTOs/
│  │  ├─ NovelDTO.swift
│  │  ├─ ChapterDTO.swift
│  │  ├─ StructuredPromptDTO.swift
│  │  ├─ DraftDTO.swift
│  │  ├─ CanonUpdatePatchDTO.swift
│  │  └─ BaseDocumentDTO.swift
│  └─ MockAPIClient.swift
├─ Stores/
│  ├─ AppStore.swift
│  ├─ NovelStore.swift
│  ├─ ChapterWorkflowStore.swift
│  ├─ BaseDocumentsStore.swift
│  ├─ KnowledgeMatrixStore.swift
│  └─ DebugStore.swift
├─ Views/
│  ├─ Root/
│  │  ├─ RootShellView.swift
│  │  ├─ SidebarView.swift
│  │  ├─ InspectorView.swift
│  │  └─ TopBarView.swift
│  ├─ ChapterStudio/
│  │  ├─ ChapterStudioView.swift
│  │  ├─ ChapterStepperView.swift
│  │  ├─ StepPromptInputView.swift
│  │  ├─ StepStructuredPromptReviewView.swift
│  │  ├─ StepDraftReviewView.swift
│  │  ├─ StepFinalApprovalView.swift
│  │  └─ StepCanonPatchReviewView.swift
│  ├─ BaseFiles/
│  │  ├─ BaseFilesView.swift
│  │  ├─ WorldBibleEditorView.swift
│  │  ├─ CharacterCardsView.swift
│  │  └─ MemoryFactsView.swift
│  ├─ Knowledge/
│  │  ├─ KnowledgeMatrixView.swift
│  │  ├─ KnowledgeMatrixTableView.swift
│  │  └─ KnowledgeEntryEditorView.swift
│  ├─ Debug/
│  │  ├─ VersionsDebugView.swift
│  │  ├─ ContextPackSnapshotView.swift
│  │  └─ AgentRunHistoryView.swift
│  ├─ Library/
│  │  ├─ ChaptersListView.swift
│  │  └─ WritingSettingsView.swift
│  └─ Components/
│     ├─ PillView.swift
│     ├─ CardView.swift
│     ├─ MetricRowView.swift
│     ├─ AuditIssueView.swift
│     ├─ EditableTextArea.swift
│     ├─ LoadingOverlayView.swift
│     ├─ EmptyStateView.swift
│     └─ ToastView.swift
├─ Resources/
│  ├─ Assets.xcassets
│  └─ PreviewData/
│     ├─ MockNovel.json
│     ├─ MockStructuredPrompt.json
│     ├─ MockDraft.json
│     └─ MockCanonPatch.json
└─ Tests/
   ├─ NetworkingTests/
   ├─ StoreTests/
   └─ SnapshotTests/
```

---

## 4. SwiftUI 根布局

### 4.1 Root Shell

HTML 原型是三栏：

```text
260px Sidebar + flexible Main + 340px Inspector
```

SwiftUI 推荐实现：

```swift
NavigationSplitView {
    SidebarView()
} content: {
    OptionalSecondaryColumnOrEmptyView()
} detail: {
    MainWorkspaceView()
        .inspector(isPresented: $store.isInspectorVisible) {
            InspectorView()
        }
}
```

但要注意：HTML 原型中的右侧 Inspector 是常驻状态栏。SwiftUI 的 `.inspector` 在 macOS 上适合这个语义，但如果实现遇到布局限制，也可以用自定义 `HStack`：

```swift
NavigationSplitView {
    SidebarView()
} detail: {
    HStack(spacing: 0) {
        MainWorkspaceView()
        Divider()
        InspectorView()
            .frame(width: 340)
    }
}
```

第一版允许使用自定义右栏，以便高度还原 HTML 原型。

### 4.2 Sidebar 宽度

建议：

```swift
.frame(minWidth: 220, idealWidth: 260, maxWidth: 300)
```

Sidebar 需要包含：

```text
Current Novel Card
Workspace Section
Library Section
设计约束说明 Footer
```

### 4.3 Main Workspace

中间区域根据 `selectedWorkspace` 切换：

```swift
enum Workspace: String, CaseIterable, Identifiable {
    case chapterStudio
    case baseFiles
    case knowledgeMatrix
    case versionsDebug
    case chaptersList
    case writingSettings
}
```

主视图：

```swift
@ViewBuilder
func workspaceView(_ workspace: Workspace) -> some View {
    switch workspace {
    case .chapterStudio:
        ChapterStudioView()
    case .baseFiles:
        BaseFilesView()
    case .knowledgeMatrix:
        KnowledgeMatrixView()
    case .versionsDebug:
        VersionsDebugView()
    case .chaptersList:
        ChaptersListView()
    case .writingSettings:
        WritingSettingsView()
    }
}
```

### 4.4 Inspector

Inspector 不承载主操作，只展示状态：

```text
本章安全边界
后台运行状态
用户只需关心
macOS 交互建议
```

Inspector 的数据来源：

```text
ChapterWorkflowStore.currentChapter
ChapterWorkflowStore.contextSafetySummary
ChapterWorkflowStore.agentStatusSummary
```

---

## 5. 全局状态模型

### 5.1 AppStore

```swift
@Observable
final class AppStore {
    var selectedWorkspace: Workspace = .chapterStudio
    var selectedNovelID: String?
    var selectedChapterID: String?
    var isInspectorVisible: Bool = true
    var toast: ToastState?
    var globalLoading: Bool = false
}
```

职责：

- 控制当前工作区。
- 控制当前小说和章节。
- 控制 Inspector 显隐。
- 控制全局提示。

不要把章节 workflow 的复杂状态放进 `AppStore`。

### 5.2 ChapterWorkflowStore

```swift
@Observable
final class ChapterWorkflowStore {
    var chapter: Chapter?
    var currentStep: ChapterStep = .promptInput
    var promptDraft: String = ""
    var structuredPrompt: StructuredPrompt?
    var draft: Draft?
    var reviewFeedback: String = ""
    var auditSummary: AuditSummary?
    var canonPatch: CanonUpdatePatch?
    var isLoading: Bool = false
    var error: APIError?
}
```

`ChapterStep`：

```swift
enum ChapterStep: Int, CaseIterable, Identifiable, Codable {
    case promptInput = 1
    case structuredPromptReview = 2
    case draftReview = 3
    case finalApproval = 4
    case canonPatchReview = 5
}
```

展示名称：

```swift
extension ChapterStep {
    var title: String { ... }
    var subtitle: String { ... }
    var userActionIndex: String { ... } // "用户动作 1 / 5"
}
```

### 5.3 BaseDocumentsStore

```swift
@Observable
final class BaseDocumentsStore {
    var worldBibleSections: [WorldBibleSection] = []
    var characterCards: [CharacterCard] = []
    var memoryFacts: [MemoryFact] = []
    var selectedBaseDocument: BaseDocumentKind = .worldBible
    var isSaving: Bool = false
    var isIndexing: Bool = false
    var error: APIError?
}
```

### 5.4 KnowledgeMatrixStore

```swift
@Observable
final class KnowledgeMatrixStore {
    var entries: [KnowledgeMatrixEntry] = []
    var visibleCharacters: [String] = []
    var filterText: String = ""
    var selectedEntryID: String?
    var isSaving: Bool = false
    var error: APIError?
}
```

---

## 6. 核心数据模型

以下模型必须与后端 DTO 对齐。命名可以微调，但语义不要变。

### 6.1 Novel

```swift
struct Novel: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var genre: String?
    var currentChapterNo: Int?
    var currentCanonVersion: Int?
    var bootstrapStatus: BootstrapStatus
}
```

### 6.2 Chapter

```swift
struct Chapter: Identifiable, Codable, Equatable {
    let id: String
    let novelId: String
    var chapterNo: Int
    var title: String?
    var status: ChapterStatus
    var targetWordCount: Int
    var approvedVersionId: String?
    var currentVersionId: String?
    var canonVersionUsed: Int?
}
```

```swift
enum ChapterStatus: String, Codable {
    case draftInput
    case structuredPromptReady
    case structuredPromptApproved
    case draftGenerated
    case revisionRequired
    case draftApproved
    case canonPatchPending
    case completed
}
```

### 6.3 StructuredPrompt

结构化 Prompt 必须支持编辑。

```swift
struct StructuredPrompt: Identifiable, Codable, Equatable {
    let id: String
    let chapterId: String
    var chapterGoal: String
    var mustHappen: [String]
    var mustNotHappen: [String]
    var allowedNamedEntities: [AllowedEntity]
    var narrativeStyle: String
    var activationSummary: ActivationSummary?
    var version: Int
}

struct AllowedEntity: Identifiable, Codable, Equatable {
    var id: String { name + activation.rawValue }
    var name: String
    var activation: ActivationState
    var mentionBudget: Int?
}

enum ActivationState: String, Codable {
    case active = "ACTIVE"
    case mentionAllowed = "MENTION_ALLOWED"
    case background = "BACKGROUND"
    case lockedOut = "LOCKED_OUT"
    case newAllowed = "NEW_ALLOWED"
}
```

### 6.4 Draft

```swift
struct Draft: Identifiable, Codable, Equatable {
    let id: String
    let chapterId: String
    var versionNo: Int
    var text: String
    var wordCount: Int
    var auditSummary: AuditSummary?
    var createdAt: Date
}
```

### 6.5 AuditSummary

```swift
struct AuditSummary: Codable, Equatable {
    var s0Count: Int
    var s1Count: Int
    var s2Count: Int
    var illegalNamedEntityCount: Int
    var inactiveCharacterAppearanceCount: Int
    var knowledgeViolationCount: Int
    var newNamedEntityCount: Int
    var issues: [AuditIssue]
}

struct AuditIssue: Identifiable, Codable, Equatable {
    let id: String
    var severity: AuditSeverity
    var type: String
    var location: String?
    var message: String
    var suggestion: String?
}

enum AuditSeverity: String, Codable {
    case s0 = "S0"
    case s1 = "S1"
    case s2 = "S2"
}
```

### 6.6 CanonUpdatePatch

```swift
struct CanonUpdatePatch: Identifiable, Codable, Equatable {
    let id: String
    let chapterId: String
    var targetCanonVersion: Int
    var items: [CanonPatchItem]
}

struct CanonPatchItem: Identifiable, Codable, Equatable {
    let id: String
    var target: CanonPatchTarget
    var title: String
    var summary: String
    var proposedAction: PatchUserDecision
    var editablePayload: String?
}

enum CanonPatchTarget: String, Codable {
    case memory = "Memory"
    case character = "Character"
    case knowledge = "Knowledge"
    case worldBible = "WorldBible"
}

enum PatchUserDecision: String, Codable, CaseIterable {
    case accept
    case modify
    case reject
}
```

### 6.7 WorldBibleSection

```swift
struct WorldBibleSection: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var content: String
    var tags: [String]
    var importance: ImportanceLevel
    var activationPolicy: ActivationPolicy
    var canonVersion: Int
    var updatedAt: Date
}

enum ActivationPolicy: String, Codable, CaseIterable {
    case alwaysInContextBrief = "always_in_context_brief"
    case alwaysConsidered = "always_considered"
    case tagMatched = "tag_matched"
    case manualOnly = "manual_only"
}
```

### 6.8 CharacterCard

人物关系合并在人物卡里。

```swift
struct CharacterCard: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var aliases: [String]
    var role: String
    var stableTraits: [String]
    var currentState: String
    var dialogueStyle: String
    var relationships: [CharacterRelationship]
    var forbiddenBehavior: [String]
    var lastActiveChapterNo: Int?
    var canonVersion: Int
}

struct CharacterRelationship: Identifiable, Codable, Equatable {
    let id: String
    var targetCharacterName: String
    var relationshipSummary: String
    var currentTension: String?
    var lastChangedChapterNo: Int?
}
```

### 6.9 KnowledgeMatrixEntry

```swift
struct KnowledgeMatrixEntry: Identifiable, Codable, Equatable {
    let id: String
    var factTitle: String
    var truthStatus: String
    var authorKnowledge: KnowledgeState
    var readerKnowledge: KnowledgeState
    var characterKnowledge: [CharacterKnowledge]
    var allowedNarration: String
    var canonVersion: Int
}

struct CharacterKnowledge: Identifiable, Codable, Equatable {
    var id: String { characterId }
    var characterId: String
    var characterName: String
    var state: KnowledgeState
}

enum KnowledgeState: String, Codable, CaseIterable {
    case known
    case unknown
    case suspects
    case hinted
    case partial
    case mayKnow = "may_know"
    case readerKnown = "reader_known"
    case readerUnknown = "reader_unknown"
    case authorOnly = "author_only"
}
```

---

## 7. 后端 API 对接

前端必须围绕后端规划中的 API 构建。不要自造额外主流程接口。

### 7.1 Novel

```http
POST  /api/novels
GET   /api/novels/{novelId}
PATCH /api/novels/{novelId}
```

### 7.2 Bootstrap / Import

```http
POST /api/novels/{novelId}/bootstrap/import-first-three-chapters
POST /api/novels/{novelId}/bootstrap/analyze
GET  /api/novels/{novelId}/bootstrap/status
```

第一版 macOS 原型如果不做导入页，可以先用 mock 数据或已存在 novel。

### 7.3 Base Documents

```http
GET    /api/novels/{novelId}/world-bible
POST   /api/novels/{novelId}/world-bible/sections
PATCH  /api/novels/{novelId}/world-bible/sections/{sectionId}
DELETE /api/novels/{novelId}/world-bible/sections/{sectionId}

GET   /api/novels/{novelId}/characters
POST  /api/novels/{novelId}/characters
GET   /api/novels/{novelId}/characters/{characterId}
PATCH /api/novels/{novelId}/characters/{characterId}

GET    /api/novels/{novelId}/knowledge-matrix
POST   /api/novels/{novelId}/knowledge-matrix
PATCH  /api/novels/{novelId}/knowledge-matrix/{entryId}
DELETE /api/novels/{novelId}/knowledge-matrix/{entryId}

GET    /api/novels/{novelId}/memory
POST   /api/novels/{novelId}/memory
PATCH  /api/novels/{novelId}/memory/{factId}
DELETE /api/novels/{novelId}/memory/{factId}
```

### 7.4 Chapter Workflow

```http
POST /api/novels/{novelId}/chapters
```

创建章节。

```http
POST /api/chapters/{chapterId}/user-prompt
```

用户输入本章 Prompt。后端自动执行：

```text
Intent Parser → Context Compiler → Prompt Expander
```

前端不要展示这些子步骤，只显示 loading 和完成结果。

```http
GET   /api/chapters/{chapterId}/structured-prompt
PATCH /api/chapters/{chapterId}/structured-prompt
POST  /api/chapters/{chapterId}/structured-prompt/approve
```

用户审核 / 修改 / 批准结构化 Prompt。

```http
POST /api/chapters/{chapterId}/draft/generate
GET  /api/chapters/{chapterId}/draft/latest
```

生成正文。

```http
POST /api/chapters/{chapterId}/draft/review
```

请求体：

```json
{
  "decision": "revise",
  "feedback": "B 显得太心虚了，改得更克制；旧码头背景解释太多，压缩。"
}
```

或：

```json
{
  "decision": "approve"
}
```

如果 `decision=revise`，后端自动调用 Revision Agent 并重新 Audit。前端仍留在“审核正文”步骤，刷新正文版本。

```http
POST /api/chapters/{chapterId}/approve-final-text
```

用户批准正文。后端自动执行 Extraction 和 Canon Merge，生成基础文档更新 Patch。

```http
GET   /api/chapters/{chapterId}/canon-update-patch
PATCH /api/chapters/{chapterId}/canon-update-patch
POST  /api/chapters/{chapterId}/canon-update-patch/confirm
```

用户确认基础文档更新。

---

## 8. Chapter Studio 施工细则

Chapter Studio 是主页面，必须优先实现。

### 8.1 Stepper

HTML 原型的 Stepper 对应 SwiftUI 组件：

```swift
struct ChapterStepperView: View {
    let currentStep: ChapterStep
    let onSelect: (ChapterStep) -> Void
}
```

展示逻辑：

- 当前步骤：高亮。
- 已完成步骤：done 状态。
- 未到达步骤：可以禁用或允许查看，但不能跳过后端状态。

推荐规则：

```text
可以回看已完成步骤。
不能直接跳到尚未满足后端状态的步骤。
```

例如没有 structured prompt 时，不能点击第 3 步。

### 8.2 Step 1：输入 Prompt

视图：`StepPromptInputView`

必须包含：

- 大文本框：本章原始 Prompt。
- 可选辅助：本章出场人物。
- 可选辅助：不要展开 / Mention Budget。
- 新内容策略说明。
- 保存草稿按钮。
- 生成结构化 Prompt 按钮。

核心交互：

```text
用户输入 prompt
→ 前端 debounce 自动保存为本地草稿
→ 点击“生成结构化 Prompt”
→ POST /api/chapters/{chapterId}/user-prompt
→ 成功后 GET /structured-prompt
→ currentStep = structuredPromptReview
```

注意：

- 自动保存是草稿，不代表创建 workflow run。
- 点击生成按钮才进入后端 workflow。
- 如果用户 prompt 少于 10 字，按钮禁用并提示。
- 不要在这个页面展示 Context Pack 明细。

### 8.3 Step 2：审核结构化 Prompt

视图：`StepStructuredPromptReviewView`

必须包含：

- 本章目标。
- 必须发生。
- 禁止发生。
- 本章可用专名。
- 文风与叙事限制。
- 返回 Prompt。
- 批准并生成正文。

结构化 Prompt 必须可编辑。

推荐 UI：

```text
本章目标：TextEditor
必须发生：可编辑 List，每条支持新增 / 删除 / 重排
禁止发生：可编辑 List，每条支持新增 / 删除 / 重排
本章可用专名：Chip List，只读为主，未来可允许打开辅助编辑器
文风与叙事限制：TextEditor
```

第一版允许简化：

```text
本章目标 TextEditor
必须发生 TextEditor，每行一条
禁止发生 TextEditor，每行一条
文风 TextEditor
Allowed Names Chip 只读
```

核心交互：

```text
用户编辑 Structured Prompt
→ 自动保存 PATCH /structured-prompt，或点击批准前统一 PATCH
→ 点击“批准并生成正文”
→ POST /structured-prompt/approve
→ POST /draft/generate
→ GET /draft/latest
→ currentStep = draftReview
```

注意：

- 这里是主流程唯一需要用户“编辑结构”的地方。
- 不要增加“审核 Context Pack”按钮。
- Allowed Names 可以展示，但不建议第一版让用户复杂编辑；如果用户要改出场人物，应回到 Prompt 或后续增加轻量实体选择器。

### 8.4 Step 3：审核正文

视图：`StepDraftReviewView`

必须包含：

- 正文编辑器。
- 我的修改意见文本框。
- 自动审计摘要。
- 越界检查摘要。
- 按我的意见修改。
- 保存当前版本。
- 我满意，进入批准。

核心交互：

#### 8.4.1 按我的意见修改

```text
用户输入 feedback
→ POST /draft/review { decision: "revise", feedback }
→ 后端执行 Revision Agent + Audit
→ GET /draft/latest
→ 更新正文、版本号、auditSummary
→ 仍停留 Step 3
```

按钮禁用条件：

```text
feedback.trim().isEmpty == true
```

#### 8.4.2 保存当前版本

如果后端提供保存接口，则 PATCH 当前 draft。若后端暂未提供，先保存到本地草稿或调用 `/draft/review` 的扩展接口。

#### 8.4.3 我满意，进入批准

```text
POST /draft/review { decision: "approve" }
→ currentStep = finalApproval
```

如果 auditSummary.s0Count > 0：

```text
禁止进入批准。
提示：存在 S0 硬错误，系统需要先修复。
```

如果只有 S1/S2：

```text
允许进入批准，但在按钮附近展示摘要。
```

### 8.5 Step 4：批准正文

视图：`StepFinalApprovalView`

必须包含：

- 最终版本摘要。
- 版本号。
- 字数。
- 审计状态。
- Canon 版本变化。
- 返回正文审核。
- 批准正文并提取更新。

核心交互：

```text
POST /approve-final-text
→ 后端执行 Extraction + Canon Merge
→ GET /canon-update-patch
→ currentStep = canonPatchReview
```

注意：

- 这个页面不要展示复杂 Agent 报告。
- 文案要清楚：批准正文不是自动改基础文件；基础文件更新下一步确认。

### 8.6 Step 5：确认基础文档更新

视图：`StepCanonPatchReviewView`

必须包含：

- Patch item 列表。
- 每项显示 target、title、summary。
- 每项选择：接受 / 修改 / 拒绝。
- 修改时可以展开编辑 payload。
- 稍后确认。
- 确认更新，完成本章。

核心交互：

```text
用户修改 patch decisions
→ PATCH /canon-update-patch
→ 点击确认
→ POST /canon-update-patch/confirm
→ 章节状态 completed
```

第一版可以允许“稍后确认”只保存 patch 状态，不关闭章节。

验收要求：

```text
只有确认更新后，本章才显示 completed。
```

---

## 9. 基础文件页面施工细则

### 9.1 BaseFilesView

HTML 原型结构：

```text
左侧 doc list
右侧编辑器
下方人物卡样式
```

SwiftUI 结构：

```swift
struct BaseFilesView: View {
    @Environment(BaseDocumentsStore.self) private var store

    var body: some View {
        HStack(spacing: 16) {
            BaseDocumentListView(selection: $store.selectedBaseDocument)
            selectedEditor
        }
    }
}
```

`BaseDocumentKind`：

```swift
enum BaseDocumentKind: String, CaseIterable, Identifiable {
    case worldBible
    case characterCards
    case memoryFacts
}
```

### 9.2 World Bible 编辑器

World Bible 是总 Bible，需要像备忘录 / Notion 一样好编辑。

每个 Section 显示：

- 标题。
- 内容。
- tags。
- importance。
- activation_policy。
- canon version。
- 保存状态。

第一版最少实现：

```text
Section 标题 + 内容 TextEditor + activation_policy Picker + 保存按钮
```

保存后：

```text
PATCH /world-bible/sections/{sectionId}
→ 显示保存成功
→ 后端自动 reindex
→ 前端显示“已索引”或“索引中”
```

不要让用户管理向量库或检索参数。

### 9.3 Character Cards

人物卡必须包含人物关系，不单独做 Relationship Graph。

第一版展示方式：

```text
三列 card grid
每张卡展示：
- 名字
- 角色标签
- 稳定人格
- 当前状态
- 关系摘要
```

编辑方式：

- 点击人物卡打开详情 sheet 或右侧编辑器。
- 详情里使用表单：稳定特征、当前状态、说话方式、关系、禁用行为。
- 允许新增人物。

### 9.4 Memory / Chapter Facts

第一版可以做成时间线或表格：

```text
章节号 | 类型 | 摘要 | 参与人物 | 地点 | canon_status | evidence
```

要求：

- 支持新增事实。
- 支持编辑事实。
- 支持删除事实。
- 支持按章节筛选。

---

## 10. Knowledge Matrix 页面施工细则

Knowledge Matrix 是核心防穿帮模块，不能做成普通备注。

### 10.1 表格结构

HTML 原型列：

```text
事实 / 秘密
作者
读者
A
B
C
允许叙述
```

SwiftUI 推荐：

```swift
Table(store.filteredEntries) {
    TableColumn("事实 / 秘密") { entry in ... }
    TableColumn("作者") { entry in KnowledgeStatePill(entry.authorKnowledge) }
    TableColumn("读者") { entry in KnowledgeStatePill(entry.readerKnowledge) }
    ForEach(store.visibleCharacters) { character in
        TableColumn(character.name) { entry in ... }
    }
    TableColumn("允许叙述") { entry in ... }
}
```

如果 `Table` 动态列实现复杂，第一版可以用 `ScrollView([.horizontal, .vertical]) + Grid` 或自定义 `LazyVGrid`。

### 10.2 状态颜色

Knowledge 状态建议映射：

```text
known / reader_known         green
suspects / hinted / partial  orange
unknown / reader_unknown     gray
author_only                  red / purple
may_know                     blue-orange mixed, first version use orange
```

使用 `PillView` 统一样式。

### 10.3 筛选

第一版至少支持：

- 搜索事实标题。
- 按角色筛选。
- 按状态筛选：unknown / suspects / known / author_only。

### 10.4 编辑

点击条目打开 `KnowledgeEntryEditorView`：

```text
factTitle
truthStatus
authorKnowledge
readerKnowledge
characterKnowledge[]
allowedNarration
```

保存：

```http
PATCH /api/novels/{novelId}/knowledge-matrix/{entryId}
```

新增：

```http
POST /api/novels/{novelId}/knowledge-matrix
```

---

## 11. 版本与调试页面施工细则

这个页面是高级区。不要在主流程里强制用户进入。

### 11.1 Context Pack Snapshot

展示只读 JSON。

第一版可以用：

```swift
Text(contextPackPrettyJSON)
    .font(.system(.caption, design: .monospaced))
    .textSelection(.enabled)
```

要求：

- 支持复制。
- 支持导出日志。
- 不支持在此编辑 Context Pack。

### 11.2 Agent Run History

展示时间线：

```text
时间 | Agent 名称 | 摘要 | 状态 pill
```

数据来源：

```text
GET debug endpoint，或第一版使用 mock 数据。
```

注意：

- Debug Only。
- 不让用户在这里重新调度 Agent。
- 不把 Agent 流程变成主要产品体验。

---

## 12. 章节列表页面施工细则

章节列表不是聊天记录。

展示：

```text
第 1 章 | 导入原文 | locked
第 2 章 | 导入原文 | locked
第 3 章 | 初始基础文件完成 | locked
第 4 章 | AI 创作中 | current
```

每章点击后：

```text
selectedChapterID = chapter.id
selectedWorkspace = .chapterStudio
loadWorkflow(chapter.id)
```

新建下一章：

```http
POST /api/novels/{novelId}/chapters
```

成功后跳到 Chapter Studio Step 1。

---

## 13. 写作设置页面施工细则

写作设置影响后台，不增加主流程动作。

第一版字段：

```text
目标字数：默认 3000 ± 400
每章最多场景：最多 2 个自然场景，不拆 Scene Plan
新命名角色策略：默认禁止，除非结构化 Prompt 批准
S0 硬错误：自动要求修复
S1 明显问题：提示给用户
S2 可选优化：折叠展示
```

注意：

- “每章最多场景”只是文案和后端配置，不产生 Scene Plan UI。
- 设置保存后不应影响当前已批准的章节版本。

---

## 14. UI 组件库

### 14.1 PillView

用于状态标签。

```swift
enum PillStyle {
    case blue, green, orange, red, purple, dark, gray
}

struct PillView: View {
    let text: String
    let style: PillStyle
}
```

用途：

- Canon v12。
- S0 / S1 / S2。
- ACTIVE / MENTION。
- pass / suggest / locked / current。
- Knowledge State。

### 14.2 CardView

统一卡片容器。

```swift
struct CardView<Content: View>: View {
    let title: String?
    let subtitle: String?
    @ViewBuilder var content: Content
}
```

样式：

- 圆角 16–22。
- 半透明白色或系统 background。
- 轻微阴影。
- 边线使用 `separator` 颜色。

### 14.3 MetricRowView

用于右侧 Inspector 和摘要。

```swift
struct MetricRowView: View {
    let label: String
    let value: String
    var valueStyle: PillStyle?
}
```

### 14.4 AuditIssueView

用于正文审核侧栏。

```swift
struct AuditIssueView: View {
    let issue: AuditIssue
}
```

颜色：

```text
S0 red
S1 orange
S2 blue / gray
```

### 14.5 EditableTextArea

macOS `TextEditor` 第一版即可。后续如需更强编辑能力，可封装 AppKit `NSTextView`。

需求：

- 支持长文本。
- 支持复制 / 粘贴。
- 支持自动保存 debounce。
- 支持选中文本后用户手动改正文。

---

## 15. Loading、错误和状态反馈

### 15.1 Loading 文案

不要暴露过多 Agent 名称。

推荐文案：

```text
正在生成结构化 Prompt…
正在生成正文…
正在根据你的意见修改正文…
正在提取基础文档更新…
正在保存基础文件…
```

可以在 Debug 页显示真实 Agent 名称。

### 15.2 错误处理

统一错误模型：

```swift
struct UserFacingError: Identifiable {
    let id = UUID()
    var title: String
    var message: String
    var retryAction: (() -> Void)?
}
```

错误展示：

- 网络失败：toast + 可重试。
- 结构化 Prompt 生成失败：留在 Step 1。
- 正文生成失败：留在 Step 2。
- 修改失败：留在 Step 3，不丢失用户反馈。
- Canon Patch 冲突：留在 Step 5，展示冲突项。

### 15.3 自动保存

自动保存策略：

```text
Prompt 输入：本地 debounce 保存。
Structured Prompt 编辑：本地 debounce + 批准前 PATCH。
正文编辑：本地 debounce，保存当前版本时提交。
基础文件编辑：显式保存为主，避免误改 Canon。
```

建议 debounce：

```text
700ms–1200ms
```

---

## 16. 权限与数据安全

### 16.1 API Key

前端不得直接持有大模型 API Key。

前端只调用自家后端：

```text
macOS App → Backend API → LLM Gateway
```

### 16.2 本地缓存

可以缓存：

- 最近打开小说 ID。
- 最近章节 ID。
- Prompt 草稿。
- 编辑器临时内容。
- 列表数据。

不要长期明文缓存用户完整小说，除非后续增加本地加密策略。

### 16.3 版本安全

用户批准正文前，任何自动修改都只影响 draft version。

用户确认 Canon Patch 前，基础文件不得被最终改写。

---

## 17. Codex 施工顺序

按以下顺序实现，避免先做花哨页面导致主流程不通。

### Phase 1：静态 SwiftUI 还原 HTML

目标：不接后端，用 mock 数据还原主要页面。

任务：

1. 建立项目目录。
2. 实现 `RootShellView` 三栏结构。
3. 实现 `SidebarView`。
4. 实现 `ChapterStudioView` 五步切换。
5. 实现 `InspectorView`。
6. 实现基础组件：Pill、Card、MetricRow、AuditIssue。
7. 使用 mock 数据填充当前小说、结构化 Prompt、正文、Patch。

验收：

```text
打开 App 后能看到三栏结构。
左侧导航可切换 6 个工作区。
Chapter Studio 五步可切换。
视觉层级接近 HTML 原型。
```

### Phase 2：接入 Chapter Workflow API

目标：跑通一章主流程。

任务：

1. 实现 `APIClient`。
2. 实现 Chapter DTO。
3. 实现 `ChapterWorkflowStore`。
4. Step 1 调用 `/user-prompt`。
5. Step 2 加载、编辑、批准 structured prompt。
6. Step 3 生成、展示、修改 draft。
7. Step 4 批准 final text。
8. Step 5 加载、修改、确认 canon patch。

验收：

```text
用户可以从 Prompt 输入一路走到 Canon Patch 确认。
流程中没有额外必需审核动作。
S0 > 0 时不能批准正文。
修改正文后仍停留在 Step 3。
```

### Phase 3：基础文件编辑

目标：World Bible、人物卡、Memory 可手动编辑。

任务：

1. 实现 `BaseDocumentsStore`。
2. 接入 World Bible API。
3. 接入 Characters API。
4. 接入 Memory API。
5. 实现新增、编辑、删除。
6. 保存后显示 reindex 状态。

验收：

```text
用户能编辑 World Bible section。
用户能新增人物。
人物关系在人物卡里编辑。
用户能编辑 Memory fact。
没有 Relationship Graph 页面。
没有伏笔 / 悬念表页面。
```

### Phase 4：Knowledge Matrix

目标：实现防开天眼核心表格。

任务：

1. 实现 `KnowledgeMatrixStore`。
2. 接入 Matrix API。
3. 实现表格视图。
4. 实现状态 pill。
5. 实现新增 / 编辑 / 删除。
6. 实现按角色和状态筛选。

验收：

```text
Matrix 以表格呈现。
可以清楚看到作者、读者、各角色分别知道什么。
可以编辑 allowedNarration。
每章主流程不会展示完整 Matrix，只展示相关限制摘要。
```

### Phase 5：版本与调试

目标：留痕但不打扰。

任务：

1. 实现 Context Pack JSON 快照展示。
2. 实现 Agent Run 时间线。
3. 实现导出日志。
4. 实现章节版本列表。

验收：

```text
Debug 信息只在“版本与调试”出现。
主流程没有 Agent Run 审核步骤。
Context Pack 只读不可编辑。
```

---

## 18. 关键交互验收清单

### 18.1 主流程验收

必须满足：

- [ ] 用户能输入本章 Prompt。
- [ ] 用户能生成结构化 Prompt。
- [ ] 用户能编辑结构化 Prompt。
- [ ] 用户能批准结构化 Prompt 并生成正文。
- [ ] 用户能阅读正文。
- [ ] 用户能输入修改意见并触发修改。
- [ ] 用户能看到 Audit 摘要。
- [ ] 用户能批准正文。
- [ ] 用户能确认基础文档更新。
- [ ] 用户没有被要求审核 Context Pack。
- [ ] 用户没有被要求审核 Agent 调用计划。
- [ ] 用户没有被要求审核 Revision Plan。

### 18.2 防“显摆设定”验收

必须满足：

- [ ] 结构化 Prompt 页面展示 Allowed Named Entities。
- [ ] Inspector 展示 Active Cast、Allowed Names、Mention Budget。
- [ ] Draft 审核侧栏展示非法专名数量。
- [ ] Draft 审核侧栏展示未激活角色出场数量。
- [ ] Draft 审核侧栏展示 Knowledge 越界数量。
- [ ] S0 硬错误不允许进入批准正文。

### 18.3 基础文件验收

必须满足：

- [ ] World Bible 可编辑。
- [ ] Character Cards 可编辑。
- [ ] Memory / Chapter Facts 可编辑。
- [ ] Knowledge Matrix 可编辑。
- [ ] 人物关系不单独成图，而在人物卡内。
- [ ] Style 相关内容出现在 World Bible。
- [ ] 没有伏笔 / 悬念表。

### 18.4 macOS 体验验收

必须满足：

- [ ] 三栏布局在宽屏下自然显示。
- [ ] 窄屏时 Inspector 可以隐藏。
- [ ] Sidebar 选中状态清晰。
- [ ] 长文本编辑区可滚动、可复制、可粘贴。
- [ ] 表格区域可横向滚动。
- [ ] 支持快捷键保存 `⌘S`。
- [ ] 支持常见编辑快捷键。
- [ ] 重要按钮有 loading / disabled 状态。

---

## 19. 不要做的事情

Codex 施工时必须避免：

```text
不要做聊天气泡。
不要做 Scene Plan。
不要按 scene 生成。
不要新增“审核 Context Pack”的主流程步骤。
不要新增“确认 Agent Plan”的主流程步骤。
不要把 Audit Report 做成必须逐条处理。
不要把 Debug 页做成用户每天必须看的页面。
不要把 World Bible 限定成世界观规则。
不要把 Style Bible 独立成单独页面。
不要把人物关系独立成 Relationship Graph。
不要做伏笔 / 悬念表。
不要在前端直接调用大模型 API。
不要让用户管理向量索引。
```

---

## 20. 文案规范

### 20.1 用户可见文案

使用产品语言，不使用底层 Agent 语言。

推荐：

```text
正在生成结构化 Prompt
正在生成正文
正在根据你的意见修改
正在准备基础文档更新
本章安全边界
越界检查
基础文档更新
```

避免：

```text
Intent Parser running
Context Compiler run id xxx
Prompt Expander tool call failed
LLM retry count
Vector retrieval result
```

这些可以在 Debug 页出现。

### 20.2 主流程按钮文案

固定使用：

```text
生成结构化 Prompt
批准并生成正文
按我的意见修改
我满意，进入批准
批准正文并提取更新
确认更新，完成本章
```

不要随意改成更模糊的文案。

---

## 21. Mock 数据要求

为了让前端先跑起来，需要准备 mock 数据。

### 21.1 Mock Novel

```json
{
  "id": "novel_001",
  "title": "雨夜旧码头",
  "genre": "现实向",
  "currentChapterNo": 4,
  "currentCanonVersion": 12,
  "bootstrapStatus": "completed"
}
```

### 21.2 Mock Structured Prompt

```json
{
  "id": "sp_004",
  "chapterId": "chapter_004",
  "chapterGoal": "让 A 对 B 的怀疑从模糊变成具体：B 不直接承认，但在旧码头的细节反应中暴露他知道旧案的关键部分。",
  "mustHappen": [
    "A 独自抵达旧码头，发现入口处的门锁被换过。",
    "B 出现并试图把 A 带离码头，语气克制，不直接心虚。",
    "A 试探旧案细节，B 对一个不该知道的细节反应过快。",
    "C 在结尾短暂出现，给出‘当年还有目击者’的线索。"
  ],
  "mustNotHappen": [
    "不要揭露旧案完整真相。",
    "不要新增有姓名角色。",
    "不要让未激活人物出场、回忆、客串或被旁白解释。",
    "不要把旧码头历史写成百科式说明。"
  ],
  "allowedNamedEntities": [
    { "name": "A", "activation": "ACTIVE" },
    { "name": "B", "activation": "ACTIVE" },
    { "name": "C", "activation": "ACTIVE" },
    { "name": "旧码头", "activation": "ACTIVE" },
    { "name": "旧案", "activation": "ACTIVE" },
    { "name": "A 的母亲", "activation": "MENTION_ALLOWED", "mentionBudget": 1 }
  ],
  "narrativeStyle": "第三人称有限视角，贴近 A。冷感、克制、少解释。通过动作、停顿和对话错位制造压力。B 的异常要藏在细节里，不要写成明显心虚。",
  "version": 1
}
```

### 21.3 Mock Draft

使用 HTML 中正文片段即可。

### 21.4 Mock Canon Patch

```json
{
  "id": "patch_004",
  "chapterId": "chapter_004",
  "targetCanonVersion": 13,
  "items": [
    {
      "id": "patch_memory_001",
      "target": "Memory",
      "title": "新增章节事实",
      "summary": "A 在旧码头发现门锁被更换；B 在与旧案相关的细节上反应异常；C 给出‘当年还有目击者’的线索。",
      "proposedAction": "accept"
    },
    {
      "id": "patch_character_001",
      "target": "Character",
      "title": "更新 A 的当前状态",
      "summary": "A 对 B 的怀疑从直觉转为有具体证据，但仍不知道旧案真相。",
      "proposedAction": "accept"
    },
    {
      "id": "patch_knowledge_001",
      "target": "Knowledge",
      "title": "更新 Knowledge Matrix",
      "summary": "A：suspects → strongly_suspects；读者：hinted；B：knows。旁白仍不能确认旧案完整真相。",
      "proposedAction": "accept"
    },
    {
      "id": "patch_world_001",
      "target": "WorldBible",
      "title": "补充地点信息",
      "summary": "旧码头入口门锁在第 4 章前被替换；该信息与旧码头状态相关。",
      "proposedAction": "accept"
    }
  ]
}
```

---

## 22. SwiftUI 伪代码骨架

### 22.1 App Entry

```swift
@main
struct NovelOSMacApp: App {
    @State private var appStore = AppStore()
    @State private var chapterStore = ChapterWorkflowStore(apiClient: APIClient.live)
    @State private var baseDocumentsStore = BaseDocumentsStore(apiClient: APIClient.live)
    @State private var knowledgeStore = KnowledgeMatrixStore(apiClient: APIClient.live)

    var body: some Scene {
        WindowGroup {
            RootShellView()
                .environment(appStore)
                .environment(chapterStore)
                .environment(baseDocumentsStore)
                .environment(knowledgeStore)
        }
        .commands {
            CommandGroup(after: .saveItem) {
                Button("保存") {
                    // route to current store save action
                }
                .keyboardShortcut("s", modifiers: .command)
            }
        }
    }
}
```

### 22.2 RootShellView

```swift
struct RootShellView: View {
    @Environment(AppStore.self) private var appStore

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .frame(minWidth: 220, idealWidth: 260)
        } detail: {
            HStack(spacing: 0) {
                MainWorkspaceView()
                if appStore.isInspectorVisible {
                    Divider()
                    InspectorView()
                        .frame(width: 340)
                }
            }
        }
    }
}
```

### 22.3 ChapterStudioView

```swift
struct ChapterStudioView: View {
    @Environment(ChapterWorkflowStore.self) private var store

    var body: some View {
        VStack(spacing: 16) {
            TopBarView(
                kicker: "Chapter Studio · 主流程",
                title: "一章一个工作台，不把你拖进 Agent 流程里"
            )

            ChapterStepperView(currentStep: store.currentStep) { step in
                store.tryMoveToStep(step)
            }

            switch store.currentStep {
            case .promptInput:
                StepPromptInputView()
            case .structuredPromptReview:
                StepStructuredPromptReviewView()
            case .draftReview:
                StepDraftReviewView()
            case .finalApproval:
                StepFinalApprovalView()
            case .canonPatchReview:
                StepCanonPatchReviewView()
            }
        }
        .padding(22)
    }
}
```

---

## 23. 后续扩展，但第一版不做

可以预留，但不要在第一版施工：

```text
iOS 适配。
多人协作。
章节导出为 EPUB。
复杂关系图谱。
悬疑小说伏笔表。
语音输入 Prompt。
全文搜索。
AI 自动改写局部选区。
基础文件 diff 可视化。
```

第一版目标是：

```text
一个稳定、清晰、低打扰的 macOS 章节工作台。
```

---

## 24. 最终验收定义

当以下场景可完整演示时，前端 v1 合格：

```text
1. 打开 App，看到当前小说“雨夜旧码头”，第 4 章，Canon v12。
2. 左侧导航清楚展示 Chapter Studio、基础文件、Knowledge Matrix、版本与调试、章节列表、写作设置。
3. Chapter Studio 默认停在 Step 1。
4. 用户输入第 4 章 Prompt，点击生成结构化 Prompt。
5. App 进入 Step 2，显示可编辑结构化 Prompt。
6. 用户批准，App 生成整章正文，进入 Step 3。
7. 用户看到正文、Audit 摘要、越界检查。
8. 用户输入修改意见，正文更新但仍留在 Step 3。
9. 用户满意后进入 Step 4，批准正文。
10. App 进入 Step 5，显示 Memory / Character / Knowledge / World Bible 更新候选。
11. 用户逐条接受 / 修改 / 拒绝，然后确认更新。
12. 章节完成，Canon v12 → v13。
13. 基础文件页面能手动编辑 World Bible、人物卡和 Memory。
14. Knowledge Matrix 页面能表格化展示“谁知道什么”。
15. 版本与调试页面能查看 Context Pack 和 Agent Run，但主流程从未要求用户审核这些内容。
```

这就是 HTML 原型转 SwiftUI 前端的第一版施工完成标准。

