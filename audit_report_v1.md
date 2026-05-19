# LinoWriting 项目偏离度审计 · 锐评与修改方案 v1

> 审计角色：资深全栈审计工程师
> 审计时间：2026-05-19
> 审计范围：`/Users/linotsai/Lino/LinoWriting` 仓库 vs `novel_ai_backend_plan_v1.md` / `novel_macos_frontend_codex_handbook_v1.md` / `novelos_macos_panel_redesign_change_list_v1.md`
> 一句话结论：**前端面板基本对得起改造清单（完成度约 75%），后端则是“持久化 Mock 服务”，离 plan v1 的“小说操作系统后端”差着一整条生产线（完成度约 15-20%）。**

---

## 0. 总判断（先看这里就够了）

| 模块 | 计划要做的事 | 实际做了的事 | 偏离度 |
|---|---|---|---|
| Backend Agent 系统 | Import / Intent / Context / Prompt / Writing / Audit / Revision / Extraction / Canon Merge 九大 Agent + LLM Gateway | 全部用 `mock_data.py` 里硬编码字符串返回，**零 LLM 调用、零检索、零白名单实际校验** | 🔴 严重 |
| Backend 数据建模 | 12 张表、JSONB 结构化字段、版本化、`agent_runs` 含 token/model/input_hash、`canon_edit_history` | 9 张表，多数 JSONB 退化为 text/列，缺 `structured_prompts` / `canon_update_patches` / `canon_edit_history` / `agent_runs` 关键字段 | 🟠 较大 |
| Backend API 覆盖 | Novel CRUD + Bootstrap 导入 + Base Docs + Chapter Workflow | Chapter Workflow + Base Docs + KM，**无 Novel CRUD、无 Bootstrap、无 World Bible CRUD 的完整闭环（只有 sections）** | 🟡 中等 |
| 前端信息架构 | 三栏 + Workspace/Library + 五步主流程 | 完全对得上 | 🟢 OK |
| 前端设计系统 | radius/spacing token、glass card、AppBackground、按钮样式族、SoftField/Picker | 已落 token、AppBackgroundView、glassPanel/glassCard 全套，已切 `.hiddenTitleBar` | 🟢 OK |
| 前端 Inspector | 4 个 section（安全边界 / 后台状态 / 用户只需关心 / macOS 建议） | **只有 1 个 section（本章安全边界）** | 🟠 较大 |
| 前端 KnowledgeMatrix | KnowledgeStatePillPicker + summary strip + 状态色强 | Summary strip ✓，但仍用 `SoftPicker` 默认下拉，不是 pill picker | 🟡 中等 |
| 前端 Chapter Studio | 玻璃 stepper 容器 + 五格、Prompt 输入页双栏（输入卡 + 右侧说明） | 玻璃 stepper ✓，但 **PromptInput 仍是单栏，没补回右侧 SideNote 和本章预设边界三块** | 🟡 中等 |
| 前端文案统一 | Sidebar 使用 "Knowledge Matrix"，页面 kicker 用 "知识矩阵 · 防穿帮" | `Workspace.knowledgeMatrix.title == "知识矩阵"`，Sidebar 也显示中文 | 🟡 中等 |

---

## 1. 后端：你管这叫 Plan 实现？

### 1.1 锐评

读 `novel_ai_backend_plan_v1.md` 你会看到这是一份**长篇小说操作系统**的后端设计：Orchestrator + LLM Gateway + 9 个 Agent + Canon Service + Retrieval Service + Audit Service + pgvector 检索 + 章节状态机 + 版本化基础文件 + 编辑历史。`README.md` 第一句就把底裤掀了：

> This phase is a persistent Mock API. It does not call a real LLM, run Agent orchestration, or implement auth.

也就是说，**当前后端就是一个能往 SQLite/Postgres 写 fixture 的 REST 外壳**。它的合法性只剩两点：

1. 让 macOS 前端有一个可联调的 URL；
2. 让章节状态机的 happy path（5 步）能被点完。

这件事本身没问题——MVP 阶段先做 fixture 是合理路径。**问题在于：plan 文档把这个阶段当成 Phase 0 都没好意思列出来**。Plan 的 §25 MVP Phase 1 是「Phase 1: 导入前三章 + 生成初始基础文件」，而仓库里：

- 没有 `bootstrap/import-first-three-chapters`
- 没有 `bootstrap/analyze`
- 没有 `bootstrap/status`
- 没有 Import Agent
- `seed.py` 直接把一个完成态小说塞进数据库

**第三章都不导，直接给你 Canon v12、四章故事，这跟 plan 第一句"导入前三章并生成初始基础文件"的承诺完全不一致。**

### 1.2 具体偏离清单

#### 1.2.1 Agent 全员"装样子"

`services.py` 里的 `run_prompt_pipeline`、`run_writing_agent`、`run_audit_pipeline`、`create_revision` 是 plan §6 中所有 Agent 的承载位置。实际行为：

| Agent | Plan 要求 | 实际实现 |
|---|---|---|
| Intent Parser | 解析用户 Prompt → 显式实体、情绪基调、是否允许新人物 | `services.py:135-144` 写一个固定 summary `"识别 A/B/C、旧码头、旧案、冷感基调。"`，payload 写死 entities=["A","B","C","旧码头","旧案"] |
| Context Compiler | 从 World Bible / Characters / KM / Memory 检索本章相关条目，构造 `allowed_named_entities` 白名单 | `services.py:68-81` 函数 `build_context_pack` 完全无视数据库，直接 `return {... "allowed_named_entities": ["A","B","C","旧码头","旧案","A 的母亲"], ...}` |
| Prompt Expander | 把用户 Prompt + Context Pack 扩成结构化 Prompt | `services.py:116-118` `dict(mock_data.STRUCTURED_PROMPT)` |
| Writing Agent | 调 LLM 写 3000 字章节正文 | `services.py:184-196` 返回 `mock_data.DRAFT_TEXT`（27 行雨夜旧码头）。`word_count=3120` 是硬编码 |
| Named Entity Auditor | 拿正文 + 白名单做实际比对 | `services.py:230-236` 直接读 `summary["illegal_named_entity_count"]`，永远是 mock_data 里的 `0` |
| Knowledge Auditor | 检查角色 / 旁白是否泄露 KM 限制 | 同上，`knowledge_violation_count` 永远 0 |
| Continuity Auditor | 检查事实改写、时间线 | 同上 |
| Revision Agent | 按用户 feedback 修改正文 | `services.py:323-355` 不管 feedback 是什么，永远返回 `mock_data.REVISED_DRAFT_TEXT`（同一个故事，删了 4 行） |
| Extraction Agent | 从批准正文提取候选事实 | 不存在。`approve-final-text` 直接 `ensure_canon_patch` 返回 `mock_data.CANON_PATCH` |
| Canon Merge Agent | 把 Extraction 输出合并、判冲突 | 不存在 |

**最致命的一条**：`audit_result_payload` 永远返回 `passed=True`，意味着 plan §22 的"防显摆设定"四层控制（上下文 / 白名单 / Prompt / 审核）在后端**一层都没有真正落地**。

#### 1.2.2 数据库偏离 plan §9

| 表 | Plan 要求关键字段 | 实际 |
|---|---|---|
| `novels` | `current_canon_version`、`status` | 有 `current_canon_version` ✓ 但缺 `status`、`language` |
| `chapters` | `approved_structured_prompt JSONB`、`canon_version_used` | 把 `structured_prompt` + `canon_patch` 全塞进 `chapters.structured_prompt`/`canon_patch` JSON 字段，**没有独立的 `structured_prompts` / `canon_update_patches` 表** |
| `chapter_versions` | `source ∈ {initial_generation, revision_by_user_feedback, revision_by_audit, manual_edit, approved_final}` | 字段有，但实现里只用了前两个值；缺 `user_feedback` 字段 |
| `world_bible_sections` | `section_key`、`importance ∈ {low/medium/high/critical}`、`activation_policy ∈ {always_in_context_brief/always_considered/tag_matched/manual_only}` | 缺 `section_key`，其他字段是字符串而没有 enum/check 约束 |
| `characters` | `stable_traits JSONB`、`current_state JSONB`、`voice JSONB`、`knowledge_summary JSONB`、`do_not_auto_mention BOOLEAN`、`default_visibility`、UNIQUE(novel_id, name) | `current_state` / `dialogue_style` 退化成 `Text`，`knowledge_summary`、`do_not_auto_mention`、`default_visibility` **完全缺失** |
| `knowledge_matrix_entries` | `fact TEXT`、`truth_status TEXT`、`visibility JSONB`（按角色 key 存可见状态）、`allowed_narration JSONB` | 把 `visibility` 拆成 `author_knowledge`/`reader_knowledge`/`character_knowledge JSONB`，`allowed_narration` 变成 Text。**API 结构与 plan 的"按 character_id 索引的 dict"完全不兼容**，后期接 LLM 时还要再迁移一次 |
| `memory_facts` | `time_in_story`、`metadata JSONB`、`created_by` | **全部缺失** |
| `context_packs` | `canon_version INTEGER NOT NULL` | 缺 `canon_version`，且 `chapter_id` 设 `unique=True`，**违背 plan 中"每次重跑都新建一份"的暗示** |
| `audit_reports` | 关联 `chapter_version_id`、`pass BOOLEAN`、`highest_severity` | 实际关联 `draft_id`（同义但命名不一致），缺 `pass`、`highest_severity` 字段 |
| `canon_update_patches` | 独立表，状态机 `pending_user_confirmation` → 确认 | 完全没有独立表，patch 塞在 `chapters.canon_patch` JSON 里 |
| `agent_runs` | `model`、`input_json`、`output_json`、`token_usage`、`error_message`、`completed_at` | 只有 `agent_name`/`summary`/`status`/`payload`/`timestamp_label`，**完全无法做 plan §24 的"日志与可观测性"** |
| `canon_edit_history` | 独立表 | **完全缺失** |

**结论**：当前数据库设计是为了"让 mock 数据跑起来"做的最小集，而不是为接 LLM 准备的。一旦后端开始真接 LLM，所有 base_documents / knowledge_matrix / agent_runs / chapters 表都要做有破坏性的迁移。

#### 1.2.3 服务拆分（plan §20）几乎没做

Plan 写得很清楚：

```
API Server / Workflow Engine / LLM Gateway / Canon Service / Retrieval Service / Audit Service
```

实际 `app/` 下：

```
main.py + database.py + models.py + schemas.py + services.py + mock_data.py + seed.py + routers/
```

`services.py` 单文件 356 行同时承担 Orchestrator + LLM Gateway + 全 9 个 Agent + Canon Service + Audit Service。这在 mock 阶段尚可接受，**但 plan §20 是后续可扩展性的根**：一旦真接 LLM，token 计费、模型降级、结构化输出重试、重试限制（plan §23）全都没有承载位置。

#### 1.2.4 其他小但真实的问题

- `main.py:39-44` `CORSMiddleware(allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])` — Mock 阶段可以，上线前必须收口。
- `routers/base_documents.py:13-52` 三个 `_require_*` 函数把 `from fastapi import HTTPException` 写进函数体内反复 import，是早期未清理的代码。
- `services.py:317-320` `increment_timestamp` 的逻辑只能处理"小时不进位且不跨日"的标签，把生成时间硬编码成 "12:01" / "12:08" 之类 —— **整套时间戳全是假的**，与 `created_at` 实际时间脱钩。
- `chapter_workflow.py:71-72` 同时用 `@router.post("/structured-prompt")` 和 `@router.post("/structured-prompt/approve")` 指向同一个函数，是为了兼容前端两种调用路径，但语义上 "POST /structured-prompt" 容易和"创建结构化 Prompt"混淆，应该删掉前者。
- `services.py:32-37` `require_context_pack` 用 `f"context_{chapter_id}"` 拼 ID，**导致 `ContextPackModel` 永远只有一份**，与 plan §9.8 中"每次重跑可以叠版本"的暗示不符。

### 1.3 后端修改方案（按优先级）

#### P0 — 别再骗自己了

1. **把 `README.md` 写清楚当前是 Mock Phase**（已写到位 ✓），并在仓库根放一个 `roadmap.md`，说明 Phase A（Mock，当前）→ Phase B（接 LLM，Agent 框架）→ Phase C（pgvector + 检索）→ Phase D（可观测性 + 版本化）。
2. **建一个 `app/agents/` 目录骨架**，即使现在每个 Agent 内部还是 fixture，也要先把接口分出来：
   ```
   app/agents/
     base.py          # Agent 抽象类，统一 run(input) -> output + log
     intent_parser.py
     context_compiler.py
     prompt_expander.py
     writing_agent.py
     audit/
       named_entity.py
       knowledge.py
       continuity.py
     revision_agent.py
     extraction_agent.py
     canon_merge_agent.py
   ```
   `services.py` 退化成 Orchestrator 调度层，不再亲自构造 fixture。这一步可以纯重构，**零行为变化**，但为接 LLM 留好位置。
3. **`app/llm/gateway.py` 占位**：提供 `LLMGateway.complete_structured(prompt, schema)` / `LLMGateway.complete_text(prompt)` 接口。当前实现内部读 `mock_data`，但调用方再也看不到 fixture 字典名字。

#### P1 — 数据库迁到 plan 形状（在还没真数据之前）

4. **拆出独立表**：`structured_prompts`、`canon_update_patches`、`canon_edit_history`、`audit_reports`（已存在，但字段补全 `pass`/`highest_severity`）。
5. **改 `knowledge_matrix_entries.visibility` 为 JSONB**：`{"author": "known", "reader": "hinted", "char_A": "suspects", "char_B": "known"}`。前端 `KnowledgeMatrixEntry.characterKnowledge` 是 list，需要后端 schema 同步改为 dict，或在 router 层做转换。**越早改越便宜**。
6. **`agent_runs` 补字段**：`model TEXT`、`input_json JSONB`、`output_json JSONB`、`token_usage JSONB`、`completed_at TIMESTAMPTZ`、`error_message TEXT`。这些字段在 mock 阶段可以全 NULL，但 schema 必须先到位。
7. **`characters` 把 `current_state` / `dialogue_style` / `knowledge_summary` 改回 JSONB**。Plan 里这些是结构化字段（情绪 / 物理 / 目标分开），前端 `Models.swift:209-221` 现在用 `currentState: String` 处理是因为后端只给 String。**要重新校准**。
8. **`memory_facts` 补 `time_in_story` / `metadata` / `created_by`**。
9. **加 alembic 迁移脚本**，不要再依赖 `Base.metadata.create_all(bind=engine)`。

#### P2 — Bootstrap / Import 流程

10. **建 `POST /api/novels`**：plan §19.1 的 Novel CRUD 现在完全缺失。前端 `NovelStore.swift` 见不到，但后续多小说要靠它。
11. **建 `POST /api/novels/{novelId}/bootstrap/import-first-three-chapters`** 占位接口：接受 3 段 markdown，存储到 object storage（mock 阶段写 `data/imports/`），异步触发 Import Agent 占位。
12. **`seed.py` 提供"空仓库 + 三章原文"模式**：默认不再 seed 完成态 Canon v12，让 bootstrap 流程能被测试。

#### P3 — 安全 / 工程化

13. CORS allow_origins 收口为环境变量。
14. `agent_runs.timestamp_label` 删掉，用 `created_at` 渲染；前端 timeline 自己格式化。
15. `chapter_workflow.py:71` 删掉 `@router.post("/structured-prompt")` 重复路由。
16. `base_documents.py` 把内部的 `from fastapi import HTTPException` 提到模块顶部。

---

## 2. 前端：方向对了，差最后一公里

### 2.1 锐评

`novelos_macos_panel_redesign_change_list_v1.md` 是 5 月 18 日的最新设计指令，章节式开了 27 个 P0/P1/P2 改造任务。读完代码：

- **P0 部分完成度约 80%**：DesignSystem token 全套、AppBackgroundView、glassPanel/glassCard/softControl modifier、ChapterStepper 玻璃容器、PromptCard、SoftTextEditor/SoftTextField、统一按钮样式（PrimaryButtonStyle/BlueButtonStyle/GhostButtonStyle/DangerButtonStyle）、StatusBanner、`.windowStyle(.hiddenTitleBar)` + `.windowToolbarStyle(.unifiedCompact)`、Cmd+S/Cmd+Shift+I 快捷键……都到位了。这部分施工质量很高。
- **但 P0 还差几块关键拼图**，下面逐一点名。

总体感觉：**Swift 工程已经从"系统默认控件拼出来的工程界面"过渡到"接近 HTML 原型的创作工作台"，但还不能完全交付**。

### 2.2 必须修的偏离

#### 2.2.1 RootShell / Inspector

| 改造清单条目 | 实际状态 | 偏离 |
|---|---|---|
| §3.3 Inspector 宽度 340 | `InspectorView().frame(width: 340)` ✓ | 🟢 |
| §3.5 移除 78pt 顶部硬 inset | `Sidebar.padding(.top, macOSWindowControlsClearance)` 改成了 44pt，已切 `.hiddenTitleBar` | 🟡 仍是硬编码，但已合规 |
| §12.3 Inspector 4 个 section | **只有 1 个 `本章安全边界`** | 🔴 缺 `后台运行状态` / `用户只需关心` / `macOS 交互建议` |
| §4.4.3 Sidebar Footer 加 "Context Compiler / Knowledge Guard / Named Entity Linter 默认后台运行" | `Spacer(minLength: 18)` 占位，**没写文案** | 🟠 |
| §3.4 主窗口背景蓝紫双径向光 | `AppBackgroundView` 已实现 ✓ | 🟢 |

`RootShellView.swift:185-211` 的 `InspectorView` 必须扩成四节点。否则右栏永远显得"信息密度不足"——这正是 change list §12.2 原话。

#### 2.2.2 Chapter Studio Prompt 输入页

`StepPromptInputView.swift` 现在是单卡片 + SoftTextEditor + 两个按钮，**完全缺**改造清单 §7 要求的：

- 左侧输入卡内部下方补三块 mini note（本章出场 / 弱提及 / 新角色策略）
- 右侧 `promptHelpRail`，三张 SideNoteView（你只需要写方向 / 为什么不是聊天 / 下一步）
- `ViewThatFits` 横竖自适应布局

这条偏离很显眼：**第一步页面在窗口最宽时也只占左半边，剩下半边空着**。完全跟"小说操作系统工作台"质感不搭。

#### 2.2.3 Knowledge Matrix

| 条目 | 实际 | 偏离 |
|---|---|---|
| §14.4 顶部 summary strip | 存在 ✓ | 🟢 |
| §14.5 KnowledgeStatePill / Pill Picker | 仍用 `SoftPicker(...) { ForEach(KnowledgeState.allCases) }` 默认下拉 | 🟠 |
| §14.6 Row zebra background | Grid 没做 zebra | 🟡 |
| §14.7 `allowedNarration` multiline editor | 待确认（未完整读 KnowledgeMatrixView） | 🟡 |

#### 2.2.4 文案统一（改造清单 §24）

`Workspace.swift:17`：

```swift
case .knowledgeMatrix: "知识矩阵"
```

改造清单 §24.1 要求 Sidebar 显示 `Knowledge Matrix`，页面 kicker 用 `知识矩阵 · 防穿帮`。当前 Sidebar 显示中文 "知识矩阵"，**和 kicker 文案重复**，违反原则。

修改：
- `Workspace.knowledgeMatrix.title` → `"Knowledge Matrix"`
- `KnowledgeMatrixView` 顶部 TopBarView 的 kicker 保留 `"知识矩阵 · 防穿帮"`

#### 2.2.5 Stepper Done 状态过弱

`ChapterStudioView.swift:135-156` 当前 done 状态：

```swift
if isDone { return AppTheme.green.opacity(0.08) }    // 背景几乎看不见
if isDone { return AppTheme.green.opacity(0.24) }    // border 也很弱
```

改造清单 §6.3 要求 done 是 "green weak background"，可以保留弱化但要让用户一眼看出"这步走过了"。建议背景至少 `.opacity(0.14)`，number circle 内部加 `Image(systemName: "checkmark")` 替换数字。

### 2.3 前端修改方案

#### P0 — 让 macOS 工作台"信息密度"达标

1. **`RootShellView.swift:185-211` 重写 `InspectorView`**：抽出 `InspectorSection` 组件（已有 `private struct` 雏形），添加四节点。每节点的数据源应来自 `ChapterWorkflowStore.safetySummary` / `chapterStore.runs` / 静态文案。
   - `本章安全边界`（保留）
   - `后台运行状态`：3 行 `MetricRowView` 显示 Context Compiler / Knowledge Guard / Named Entity Linter 的 mock 状态。
   - `用户只需关心`：5 行编号文案，与 `ChapterStep.title` 同源。
   - `macOS 交互建议`：3-4 行静态文案介绍 ⌘S / ⌘⇧I / ⌘↩。
2. **`RootShellView.swift` Sidebar 底部加 Footer**：在 `Spacer(minLength: 18)` 后加一段 caption 文案 `Context Compiler、Knowledge Guard、Named Entity Linter 默认后台运行。你只需要完成五个用户动作。`
3. **`StepPromptInputView.swift` 改造成左卡 + 右导轨**：
   - 把当前 `PromptInputCard` 保留为主卡，下方追加三块 `MiniNoteRow`（本章出场 / 弱提及额度 / 新角色策略），数据从 `store.safetySummary` 取。
   - 新增 `private struct PromptHelpRail`，三张 `SideNoteView` 文案直接照抄 change list §7.5。
   - 外层用 `ViewThatFits(in: .horizontal) { HStack { promptCard.frame(minWidth: 620); promptHelpRail.frame(width: 300) } } else { VStack { promptCard; promptHelpRail } }`。
4. **`Workspace.swift:17` 改文案**：`"知识矩阵"` → `"Knowledge Matrix"`。
5. **`KnowledgeMatrixView.swift` 引入 KnowledgeStatePill / KnowledgeStatePillPicker**：把每个状态 Picker 包成一个可点击 pill，颜色按 change list §14.5 映射（known/strongly_suspects=green，suspects/hinted/partial/may_know=orange，author_only=purple，unknown/reader_unknown=neutral，reader_known=green）。点击弹 `Menu`。
6. **`ChapterStepperView` done 状态加强**：number circle 用 `Image(systemName: "checkmark")` + 绿色实心；行背景 opacity 0.14。

#### P1 — 把改造清单后半段补齐

7. **`StepCanonPatchReviewView`** 重做 timeline 风格 + target badge 颜色（Memory blue / Character orange / Knowledge purple / WorldBible green）。
8. **`StepFinalApprovalView`** 移除 EmptyState，加最终候选摘要 + 只读短预览。
9. **`StepDraftReviewView`** 正文 minHeight 调到 520，字体 15pt，行距贴近 1.8。
10. **`BaseFilesView` 字段补全**：CharacterCard 当前已经支持 stableTraits / currentState / dialogueStyle / relationships，但仍以 String 处理 `currentState`——**这条改造其实卡在后端字段类型**（参见 §1.3 第 7 条）。先修后端字段，再回前端拆 emotional/physical/goal。

#### P2 — 长尾收尾

11. `ChaptersListView` 字段补全（章节号 / 标题 / 摘要 / 字数 / Canon version / pill）。
12. `WritingSettingsView` 全部控件迁移到 SoftTextField / SoftPicker。
13. `VersionsDebugView` 的 Agent Run timeline 视觉对齐 change list §15.4。

---

## 3. 跨端契约风险（看这里防止双端各走各的）

### 3.1 KnowledgeMatrix 数据结构错位

后端 `KnowledgeMatrixEntry.character_knowledge: list` 是 `[{character_id, character_name, state}, ...]`。
Plan §8.3 说应该是 `visibility: {"A": "suspects", "B": "knows", ...}` 这种 dict。
前端 `KnowledgeMatrixEntry.characterKnowledge: [CharacterKnowledge]` 跟后端 list 一致。

**结论**：双端在错的方向上一致。Plan 是对的，因为按 character_id 索引可以 O(1) 取状态，list 形式新增/删除角色都得线性扫描。**越早换 dict 越省成本**。

### 3.2 字段命名 Snake / Camel

后端 schemas 用 snake_case（`s0_count`、`current_canon_version`），前端 Codable 用 camelCase（`s0Count`、`currentCanonVersion`）。`NovelOSMacCore/Networking/APIJSONCoding.swift` 应该做了 `.convertFromSnakeCase`，但建议在 Phase B 接 LLM 之前**统一锁定为 snake_case in transit**，避免 KnowledgeMatrix dict 改造时再连环改。

### 3.3 Audit 永远 pass

后端 `audit_summary` 是 mock 固定数据，`s0_count` 永远 0，导致前端的 `finalApprovalBlockedReason` 永远是 nil，**S0 拦截路径完全没被联调过**。前端有 `injectS0ForTesting()` 这个本地注入函数，**但不应该是常态测试方式**。后端必须能配置返回带 S0 的 fixture（一个环境变量或 query 参数都行）。

---

## 4. 文档与实现错位

1. `novel_macos_frontend_codex_handbook_v1.md` §3 推荐的目录结构是 `App/Models/Networking/Stores/Views/...` 分层，实际仓库走的是 `NovelOSMac` + `NovelOSMacCore` 双 target，单 file `BasicComponents.swift` 24K。这种偏离合理（package 分包更 Swift 化），但 handbook 应该补一句"实际采用 module split，不强求按 handbook 目录"。
2. 改造清单 §15.2 提到 `Workspace.versionsDebug.title` 从"版本记录"改为"版本与调试" — **已改 ✓**。
3. 改造清单 §25.12 提到 `ActivationPolicy.displayName` / `KnowledgeState.displayName` 中文化 — **已做 ✓**。
4. README 第 51 行：`Character cards intentionally do not expose DELETE, matching novel_ai_backend_plan_v1.md.` — 这句是对的（plan §19.3 确实只列 POST/GET/PATCH），但 plan 里没解释"为什么不让删"。建议在 README 补一句业务理由（一旦人物出现在已完成章节里就不能物理删除，只能设 `status="retired"`）。

---

## 5. 推荐执行顺序

```
第 1 周（后端先动）：
  - 拆 app/agents/ 骨架（纯重构）
  - 拆 app/llm/gateway.py 占位
  - alembic 接入 + 迁移 knowledge_matrix.visibility 为 JSONB
  - 补 agent_runs 字段
  - 补 Novel CRUD + bootstrap import 占位

第 2 周（前端补齐 P0）：
  - InspectorView 四节点
  - StepPromptInputView 双栏改造
  - KnowledgeStatePillPicker
  - Workspace 文案统一
  - Stepper done 状态加强

第 3 周（联调 S0 路径）：
  - 后端加 mock_audit_with_s0 开关
  - 前端走 S0 阻拦 → 自动 revision 全流程
  - 删除 injectS0ForTesting 本地后门

第 4 周（前端 P1 收尾 + 后端字段类型校准）：
  - characters.current_state 改 JSONB
  - CharacterCard 拆 emotional/physical/goal 显示
  - StepCanonPatchReviewView 改 timeline

第 5 周起（Phase B：真接 LLM）：
  - LLMGateway 接 Claude API
  - Context Compiler 接入 World Bible / KM / Memory 检索
  - Named Entity Auditor 真做正文 vs 白名单比对
  - 错误处理（plan §23）落地
```

---

## 6. 一句话总结

**前端是个还差几针绣完的成衣，后端是个挂着"小说操作系统"招牌的样品间。**

前端再走 1-2 周就能交付 macOS Phase 1；后端如果不在 Phase B 前先把数据模型校准、Agent 接口拆开、KnowledgeMatrix 结构改 dict，到接 LLM 时会被破坏性迁移搞到崩溃。

**当前最该做的不是炫技，而是承认现状，把 plan 落到合理的 Phase 划分，并把"哪些是 Mock、哪些是真实"在 README/roadmap 里写清楚。**
