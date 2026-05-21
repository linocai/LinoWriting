# LinoWriting · v1.0 最终施工方案 (v1_final_plan)

> 文档角色：本文件是 v1.0 上线前的**权威施工口径**。
> 适用对象：前端 / 后端 / 全栈施工成员（“代码施工队”）。
> 更新时间：2026-05-20。
> 优先级关系：本文件 **优先于** `audit_report_v1.md`、`novelos_macos_panel_redesign_change_list_v1.md`；与 `v1.0上线步骤.md` 的范围闸口保持一致；不取代用户即时指令。
> 配套可视化：`macOS新前端+改造后逻辑链路.html`（设计与逻辑链路稿，本文件中所有“前端目标态”均指其中样式）。

---

## 0. 一句话总览

> **前端**：用户感到“卡”，根因是 tab 切换重拉数据 + 网络无 optimistic + 动画缺位；本轮做缓存层、流式正文、统一动画系统、Inspector 四节点、基础文件模板化、版本与调试 → 改名「本章流程日志」。
> **后端**：写作链路跑通但离生产差“可重试、可流式、可观测、模板化输出”四件事；本轮做 LLM Gateway 重试 + token 记账细化、Writing Agent 流式、Audit 真做白名单比对、Bootstrap 模板化 schema、错误细分、KM visibility 契约校准。
> **本版不做**：云部署、多人、向量库生产化、出版排版。所有“好酷的功能”一律推到 v1.1+。

---

## 1. v1.0 范围闸口（不许越界）

只做 `v1.0上线步骤.md` Section 1 中列出的 7 件事。**任何不在闸口内的需求统统进 v1.1。**

闸口内：
1. 本地 `LinoI.app` + `http://127.0.0.1:7773` 后端。
2. 创建小说、导入前三章。
3. LLM 模板化分析前三章 → World Bible / Character / Memory / KM。
4. 第 4 章起跑完整五步工作流。
5. 数据持久化、备份、恢复。
6. LLM/网络/JSON 失败时有明确错误 + 可重试。
7. 基础文件可手动编辑且可回滚。

**禁止越界**：聊天 UI、Scene Plan UI、多用户、远程登录、自动连载、向量检索生产化（用 tag 匹配兜底即可）。

---

## 2. 前端施工清单（NovelOSMac）

> 所有目标态以 `macOS新前端+改造后逻辑链路.html` 为视觉基准。Swift 实现优先用原生 material + 自定义 token，**不要引入第三方动画/UI 库**。

### 2.1 P0 — 终结"点一下卡 1 秒"

#### 2.1.1 数据加载策略：`loadIfNeeded` 全面替代 `load`
- **文件**：`NovelOSMacCore/Stores/*Store.swift`（`ChapterWorkflowStore` / `BaseDocumentsStore` / `KnowledgeMatrixStore` / `NovelLibraryStore`）。
- **现状问题**：`BaseFilesView.swift:57-59` `.task { await store.loadDocuments() }`、`KnowledgeMatrixView.swift:129-131` `loadEntries()` 在每次 view 挂载都重拉数据；切换 tab 来回 1-2 秒不可用。
- **改造**：每个 store 增加 `var loadedAt: Date?` 与 `var inflight: Task<Void,Error>?`，并实现：
  ```swift
  func loadIfNeeded(maxAge: TimeInterval = 60) async throws {
      if let inflight { return try await inflight.value }
      if let loadedAt, Date().timeIntervalSince(loadedAt) < maxAge { return }
      inflight = Task { try await self.load() }
      defer { inflight = nil }
      try await inflight!.value
  }
  ```
- **触发点**：所有 `.task { … }` 改成调 `loadIfNeeded()`；切换小说时显式 `invalidate()`。

#### 2.1.2 Optimistic Update + 失败回滚
- **场景**：人物卡保存、KM 单元格修改、基础文件字段编辑、章节 Prompt 输入。
- **规范**：UI 先写入本地 state → 后台 `await store.save()` → 失败时 toast 错误并回滚 + 恢复焦点到失败字段。
- **新增**：`NovelOSMacCore/Stores/OptimisticEdit.swift`，封装 `apply / rollback / commit` 三态。
- **必做**：所有按钮 `disabled` 期间显示 `.loading` 旋转图标（按钮组件已在 HTML 中演示，见 `.btn.loading` 类）。

#### 2.1.3 流式正文（Writing Agent）
- **现状**：`POST /chapters/{id}/draft/generate` 同步等 20-60 秒，前端无视觉反馈，用户以为死了。
- **改造**：后端改 SSE（见 §3.3）；前端用 `URLSession.bytes(for:)` 增量解码，在 `DraftReviewView` 里 `Text(draft)` 加 `.id(draft.hashValue)` + `.transition(.opacity)`，按字流入。
- **副产物**：Inspector 「后台运行状态」实时显示当前字数 / 预计剩余时间。

#### 2.1.4 工作区切换瞬时化
- **目标**：⌘1-4 切换工作区在 60ms 内完成（数据已缓存）。
- **方法**：
  - 切换不触发新的网络请求（被 §2.1.1 保护）。
  - View 之间用 `.transition(.opacity.combined(with: .move(edge: .top)))` + `.animation(.smooth(duration: 0.18), value: workspace)`。
  - 避免 NavigationSplitView detail 区在切换时被重建（保留 `id` 一致）。

#### 2.1.5 命令面板（已取消）
- **决策**：v1.0 不实现 Command Palette，不注册 `⌘K`。
- **执行**：移除界面内所有 `⌘K` 快捷键提示，后续导航继续依赖 Sidebar、Inspector 与 `⌘1-4` 工作区切换。

### 2.2 P0 — 统一动画系统

新增 `Views/AnimationKit.swift`，把以下放到 `AppTheme.Motion`：

```swift
enum Motion {
    static let easeOut    = Animation.timingCurve(0.2, 0.7, 0.2, 1, duration: 0.18)
    static let spring     = Animation.spring(response: 0.32, dampingFraction: 0.78)
    static let viewSwitch = Animation.timingCurve(0.2, 0.7, 0.2, 1, duration: 0.22)
}
```

**强制规则**：
1. 所有状态变化都必须用 `.animation(Motion.easeOut, value: …)` 包裹，不要无动画硬切。
2. 按钮按压：`.scaleEffect(isPressed ? 0.985 : 1)` + `brightness(isPressed ? -0.04 : 0)`；不再用 opacity。
3. 卡片 hover：`y: -2` + `shadow: lg`（仅 macOS hover 有效）。
4. Stepper done 状态：`number circle` 用 `Image(systemName: "checkmark")` 替换数字，绿色实心；行背景 opacity 提到 0.10（现状 0.08 太弱）。
5. Inspector 切换：`.transition(.move(edge: .trailing).combined(with: .opacity))` 保留。

### 2.3 P0 — RootShell 三栏

- Sidebar 264 / Main 自适应 / Inspector 348。
- 背景仍由 `AppBackgroundView` 提供（已实现）；改两件事：
  - Sidebar `.background(.regularMaterial)` 之上再叠 `Color.white.opacity(0.86)`，否则太透看不清字。
  - Sidebar Footer **必须补回文案**（HTML 第 158 行）：「Context Compiler、Knowledge Guard、Named Entity Linter 默认后台运行。你只需要完成五个用户动作。」
- 导航项：active 用白卡 + 轻阴影 + `nav-icon` 着蓝色（HTML 演示）；不要再用整块蓝底。

### 2.4 P0 — Inspector 重写为 5 节点

**文件**：`Views/RootShellView.swift:185-211`（`InspectorView`）。

按 HTML 右栏顺序实现 5 节（**注意比 change_list v1 多 1 节，把 Audit 预览独立**）：

1. **本章安全边界**（保留）
   - 状态 pill / 出场人物 / 白名单数 / 弱提及预算 / 新增命名角色禁止。
2. **后台运行状态**
   - 6 行 Agent 状态：Writing Agent / Context Compiler / Prompt Expander / 3 个 Auditor。
   - 数据源：`ChapterWorkflowStore.agentRuns` 实时筛当前章节。
   - 视觉：running 状态 dot 用 `.pulse` 动画（HTML 已示意）。
3. **你只需要关心**
   - 渲染五步进度，绑定 `ChapterStep`。
4. **本章 Audit 预览（实时）**
   - 来自 `audit_reports` 表当前 chapter_version_id；S0/S1/S2 三色 chip。
5. **macOS 交互**
   - ⌘↩ / ⌘S / ⌘⇧I / ⌘1-4 四行。

抽象组件：

```swift
struct InspectorSection<Content: View>: View {
    let title: String
    let trailing: AnyView?
    @ViewBuilder var content: Content
}
```

### 2.5 P0 — Chapter Studio 五步细化

每个 Step View 都按 HTML 校准。重点改：

#### Step 1 (Prompt 输入)
- `StepPromptInputView.swift` 改成 `ViewThatFits`，左 prompt 卡 + 右 3 张 SideNote（HTML §"why"/"白名单"/"下一步" + 快捷键）。
- 左卡下方补三块 mini note（出场 / 弱提及 / 新增策略），数据从 `store.safetySummary` 取。

#### Step 2 (结构化 Prompt 审核)
- 现状是几个 TextEditor 堆叠。改为：本章目标 / 必须发生 / 禁止发生 / 白名单 / 文风 五个 `TemplateCard`，每张内部用结构化字段（参考 HTML §step-view "2"）。
- 「必须发生 / 禁止发生」用行级编辑，每行可单独编辑、删除；不要给一个大 TextEditor。
- 白名单用 `EntityChipGrid`，ACTIVE 绿、MENTION 橙、LOCKED 灰。

#### Step 3 (审核正文)
- 正文 minHeight 520、字体 15pt、行距 1.85（已在 HTML CSS `.draft-editor`）。
- 反馈输入框上方提示：「直接给一句话就行，系统会自动改写。不需要逐段标注。」
- 反馈提交后立即进入 Step 3 的 "running" 子态：显示 Revision Agent 流式进度。

#### Step 4 (批准正文)
- 移除 EmptyState；显示最终候选摘要（字数、Audit 通过 / S0=0、token 用量）+ 只读短预览（前 300 字）。
- 主按钮：「批准并生成基础文件更新」。

#### Step 5 (确认基础文档更新)
- Patch 列表用 timeline 形式：Memory(蓝) / Character(橙) / Knowledge(紫) / WorldBible(绿)。
- 每条都可单选删除、可编辑文本、可整体「全部确认」。
- 确认后进入 done 终态，主按钮 disabled，显示 "本章已完成" + "前往第 5 章"。

### 2.6 P0 — 基础文件模板化

**文件**：`Views/Workspaces/BaseFilesView.swift`（重写 character / world bible 编辑器）、新建 `Components/TemplateCard.swift`。

#### 痛点
LLM 现在直接把"段段大白话"塞进 `current_state`、`stable_traits` 等字段，UI 用单 String 渲染 → 用户看到一坨。

#### 解决方案
1. **后端模板** (§3.4) 强制结构化输出。
2. **前端按段渲染**：每张人物卡分 6 个 `TemplateCard`：
   - 基本信息（姓名 / 别名 / 角色定位）
   - 稳定人格（list）
   - 当前状态（身体 / 情绪 / 目标，三栏 kv）
   - 说话方式（对话风格 / 禁忌 list）
   - 关系（每条一卡，含 type / current_state / history_summary / last_changed_chapter）
   - 知道什么 / 不知道什么（chip grid）
3. **World Bible** 同理：基调 / 现实背景 / 禁忌写法 / 时空 / 主题 / 职业 / 价值观 7 节，每节 `TemplateCard`，字段：title / content / tags / importance / activation_policy。LLM 必须按这个 schema 输出（§3.4）。
4. **Memory** 改为 Timeline 视图，按 chapter_no 排序，左侧固定章节 badge，右侧 fact_type 标签（event 蓝 / state 橙 / item 紫）。
5. **编辑器统一**：长文本用 `SoftTextEditor`、单行用 `SoftTextField`、枚举用 `SoftPicker`，**禁止再用系统默认控件**。

#### 视觉
卡片视觉与 HTML §basefiles 完全一致：`.template-card`（白色 78% + 16px radius + 14px padding）。

### 2.7 P0 — Knowledge Matrix Pill Picker

**文件**：`Views/Workspaces/KnowledgeMatrixView.swift` + 新建 `Components/KnowledgeStatePillPicker.swift`。

- 现状：用 `SoftPicker` 默认下拉，单元格高 36，视觉沉重。
- 目标：每个 visibility 状态是一个 `KnowledgeStatePill`（HTML `.km-pill.*` 类），点击弹 `Menu`。颜色映射：

| 状态 | 颜色 |
|---|---|
| known / strongly_suspects | green |
| suspects / hinted / partial / may_know | orange |
| author_only | purple |
| unknown / reader_unknown | neutral |
| reader_known | blue |

- 表格 zebra 背景（HTML `tbody tr:nth-child(even)`）。
- 上方 3 张统计卡（总秘密 / 本章可见性变化 / Auditor 状态），见 HTML §km。

### 2.8 P0 — 「版本与调试」→ 「本章流程日志」

**文件改名**：`Views/Workspaces/VersionsDebugView.swift` → `Views/Workspaces/ChapterDebugLogView.swift`。
**Workspace 枚举**：`versionsDebug` → `chapterDebugLog`，title `"版本与调试"` → `"本章流程日志"`。

#### 内容重做（核心：让用户一眼看懂这页存在的理由）
1. **顶部摘要条**：本章 Agent 调用 N 次 / Token X / 估价 ¥Y / 失败重试 Z 次。
2. **Agent Timeline**：当前章节所有 `agent_runs` 按时间渲染（HTML `.timeline`）。
   - 颜色左侧条：ok 绿 / warn 橙 / err 红 / running 蓝。
   - 每条可点「查看 IO」打开 sheet 显示 input/output JSON（带 copy）。
3. **章节版本卡片**：横排显示 v1 / v2 / v3，每张含字数、S0/S1 数、修订原因；可点击查看 diff（v1 → v2 行级 diff，红 / 绿高亮）。
4. **原始 JSON 块**：折叠式，给开发者用。

#### 删掉的内容
- 「上下文快照」卡片：跟 Inspector 重复，删。
- 不再展示 Mock 数据；空状态用 EmptyState。

#### Sidebar 角标
Sidebar 「本章流程日志」右侧显示 `dot N`，N 表示本章失败重试次数。

### 2.9 P1 — 章节列表 / 写作设置 / 等

#### 章节列表
- HTML §chapters 那张表照搬：#、标题、状态、字数、Canon、更新时间。
- 状态 pill：已批准（green）/ 生成中（blue + step number）/ 未开始（dark）。

#### 写作设置
- 全部控件迁到 SoftTextField / SoftPicker。
- 加 "LLM Provider" 当前状态卡（HTML §settings 右栏）。
- "本地数据位置" 卡片显示数据库路径 + 一键打开 Finder + 备份按钮。

### 2.10 P1 — 文案统一

- `Workspace.knowledgeMatrix.title` → `"Knowledge Matrix"`（英文）；TopBar kicker 留 `"知识矩阵 · 防穿帮"`。
- `Workspace.versionsDebug.title` → `"本章流程日志"`。
- Sidebar 「基础文件」保留中文；「Chapter Studio」保留英文（Apple 中文 mac 习惯）。

### 2.11 P2 — 长尾

- Skeleton 加载态（HTML `.skeleton.sk-line`）：BaseFiles / KM / Chapters 列表首次加载时显示骨架屏。
- 错误 toast 系统：`Components/Toaster.swift`，分 error / warn / ok 三色。
- 大文件保护：人物卡字段长度 > 2000 字时折叠 + 「展开全部」按钮。

---

## 3. 后端施工清单（NovelOSBackend）

### 3.1 P0 — LLM Gateway 加固

**文件**：`app/llm/gateway.py`。

#### 现状问题
- 无重试。任何瞬时网络抖动直接 502。
- 错误统一 `LLMGatewayError`，前端看不懂是 401 还是 429 还是 timeout。
- Token usage 字段在结构化输出里被忽略。

#### 必做
1. **加重试装饰器**：
   ```python
   async def _with_retry(self, coro_factory, *, max_attempts=3, backoff=(0.5, 1.5, 4.0)):
       last = None
       for i in range(max_attempts):
           try: return await coro_factory()
           except (httpx.ConnectError, httpx.ReadTimeout, httpx.RemoteProtocolError) as e:
               last = e; await asyncio.sleep(backoff[i]); continue
           except httpx.HTTPStatusError as e:
               if e.response.status_code in (429, 502, 503, 504):
                   last = e; await asyncio.sleep(backoff[i]); continue
               raise
       raise last
   ```
2. **错误细分**：新建 `app/llm/errors.py`：
   - `LLMAuthError` (401/403) → 502 + retryable=false + `kind="auth"`。
   - `LLMRateLimitError` (429) → 502 + retryable=true + `kind="rate_limit"`。
   - `LLMTimeoutError` → 502 + retryable=true + `kind="timeout"`。
   - `LLMJSONParseError` → 502 + retryable=true + `kind="parse"` + 原始片段。
   - `LLMProviderError` (5xx) → 502 + retryable=true + `kind="provider"`。
3. **结构化输出**：`complete_structured()` 收到响应后必须按 Pydantic schema 校验；不通过自动重试一次并强化 system prompt（"必须严格输出指定 JSON schema"）。
4. **Token 记账**：所有调用必须落 `agent_runs.token_usage = {prompt, completion, total, model}`。

### 3.2 P0 — 流式 Writing Agent

**新增**：`POST /api/chapters/{id}/draft/generate/stream` (SSE)。

```python
# app/routers/chapter_workflow.py
@router.post("/draft/generate/stream")
async def stream_draft(chapter_id: str, ...):
    async def gen():
        async for chunk in writing_agent.run_stream(...):
            yield f"data: {json.dumps({'text': chunk.delta, 'tokens': chunk.tokens})}\n\n"
        yield "data: {\"done\": true}\n\n"
    return EventSourceResponse(gen())
```

- Writing Agent 内部用 OpenAI compat 的 `stream=True`；按字符增量写 `chapter_versions.text`；最终落 `chapter_versions.source="initial_generation"`。
- 失败时落 `agent_runs.status="failed"` + 部分文本作为草稿保留。
- 同步接口保留作为 fallback（前端无法 SSE 时）。

### 3.3 P0 — Audit Agent 真比对

**文件**：`app/agents/audit/named_entity.py` / `knowledge.py` / `continuity.py`。

#### 现状
现在 `audit_summary` 写死 `passed=True`、`s0_count=0`，S0 拦截路径从未真跑过。

#### 改造
1. **Named Entity Auditor**（纯本地代码，不用 LLM）：
   - 输入：`draft_text` + `allowed_named_entities` + 全量 character / location 表。
   - 用 jieba 或正则切词（中文）；O(n) 扫描词频；标记白名单外的命名实体出现位置（段落 + 偏移）。
   - 输出 S0 list。
2. **Knowledge Auditor**（LLM 调用）：
   - Prompt 模板：「以下正文是否让任一角色获得了 knowledge_constraints 之外的信息？」
   - 输出 schema：`[{character, fact, constraint, severity, evidence_snippet}]`。
3. **Continuity Auditor**（LLM 调用）：
   - Prompt 模板：「以下正文是否改写或矛盾了已批准的 Memory？」
   - 输入 Memory 摘要 list，输出 S0/S1 list。
4. **三个 Auditor 并发跑**：`asyncio.gather(...)`，最差用时 = 最慢的那个。
5. **S0 ≥ 1 时自动 Revision**：`orchestrator.run_audit()` 现在已经有架子；落地 `auto_revise_on_s0=True`，最多循环 2 次（按 plan §23.3）。

### 3.4 P0 — Bootstrap 分析模板化

**文件**：`app/agents/import_agent.py` + `app/services.py:apply_bootstrap_canon_analysis`。

#### 现状
ImportAgent 用 `complete_structured` 但 schema 比较松；用户感觉"LLM 总结的太散"。

#### 改造
1. **强 schema**：在 `app/agents/import_agent.py` 顶部定义 Pydantic schema：

```python
class WorldBibleSectionSchema(BaseModel):
    section_key: Literal["tone_and_style", "real_world_background", "forbidden_patterns",
                          "time_and_place", "themes", "profession_and_society", "value_boundary"]
    title: str
    content: str = Field(..., min_length=20, max_length=800)
    tags: list[str] = Field(default_factory=list)
    importance: Literal["low", "medium", "high"] = "medium"
    activation_policy: Literal["always_in_context_brief", "always_considered", "tag_matched", "manual_only"] = "tag_matched"

class CharacterCardSchema(BaseModel):
    name: str
    aliases: list[str] = []
    role: Literal["protagonist", "deuteragonist", "antagonist", "supporting"]
    stable_traits: list[str] = Field(..., min_items=2, max_items=6)
    current_state: dict  # {physical, emotional, goal}
    voice: dict  # {dialogue_style, forbidden}
    relationships: list[dict]
    knowledge_summary: dict  # {knows, suspects, does_not_know}

class KnowledgeEntrySchema(BaseModel):
    fact: str
    truth_status: Literal["confirmed_open", "confirmed_author_only", "hinted", "misdirection", "uncertain"]
    visibility: dict  # {"author": "known", "reader": "hinted", "<char_name>": "suspects", ...}
    allowed_narration: dict
    source: str
```

2. **Prompt 用 schema 反射生成**：System prompt 里贴 schema JSON Schema，要求模型严格输出。
3. **校验失败重试一次**，仍然失败则把"原始输出 + 错误信息"塞 `agent_runs.error_message`，让前端展示 `LLMJSONParseError`。
4. **幂等**：`apply_bootstrap_canon_analysis` 必须支持重跑——同 section_key / character.name 覆盖而不是 append。
5. **七个 World Bible section 是必填**：缺失的项后端自动写"待补充" + `importance="low"`，让用户看到模板形状。

### 3.5 P0 — KM visibility 字段契约修正

#### 现状
`models.py:207` `visibility: Optional[dict]`、`character_knowledge: Optional[list]`，前后端都按 list 处理；但 plan §8.3 是 dict。

#### 改造（一次性 alembic 迁移）
1. 数据库：`knowledge_matrix_entries.visibility JSONB`（确保 NOT NULL DEFAULT '{}'）。
2. Schema：`KnowledgeMatrixEntry.visibility: dict[str, str]`，删除 `character_knowledge` 字段。
3. 老数据迁移：把 list 形式的 `[{character_id, character_name, state}]` 收成 `{character_name: state}` dict。
4. 前端 `Models.swift`：`characterKnowledge: [CharacterKnowledge]` → `visibility: [String: String]`，KnowledgeMatrixView 行渲染按动态列宽（人物 N 多时横滚）。
5. 同步改 `ImportAgent` 输出（已在 §3.4 schema 中改好）。

### 3.6 P0 — Agent 模板化输出（防"散"）

> 用户原话：「llm 自己总结的东西太散了，确实是需要一个模板，它可能会总结的好一些」。

所有 Agent 的 LLM 调用必须满足：
1. **System Prompt 顶部贴 schema 反射**（JSON Schema dump）。
2. **`response_format={"type": "json_object"}`**（OpenAI compat 支持的服务都开）。
3. **后端用 Pydantic 二次校验**，失败重试 1 次并 strengthen system prompt。
4. **失败超过 2 次** → 落 `agent_runs.status="failed"` + 前端可重试按钮。

涉及 Agent：`import_agent` / `intent_parser` / `prompt_expander` / `extraction_agent`。
`writing_agent` 和 `revision_agent` 输出是纯文本，**不强制 JSON**，但要按字数闸门：< 70% 或 > 140% 自动让模型扩写 / 压缩（plan §23.2）。

### 3.7 P0 — 错误处理细分

**文件**：`app/errors.py`。

```python
class APIError(Exception):
    http_status: int = 500
    kind: str = "unknown"
    retryable: bool = False

class ValidationFailedError(APIError):
    http_status = 422; kind = "validation"

class WorkflowStateError(APIError):
    """e.g. 试图在 step 1 没批准时直接调 step 3"""
    http_status = 409; kind = "workflow"; retryable = False

class LLMGatewayError(APIError):
    http_status = 502; retryable = True
    # 子类 LLMAuthError / LLMRateLimitError / LLMTimeoutError / LLMJSONParseError / LLMProviderError
```

所有路由统一：`raise APIError` → exception handler 返回标准 envelope：
```json
{
  "error": { "kind": "rate_limit", "message": "上游 429，建议 5 秒后重试", "retryable": true, "agent_run_id": "..." }
}
```

前端 toast 按 `kind` 显文案，按 `retryable` 决定是否显示 "重试" 按钮。

### 3.8 P0 — 章节状态机硬约束

**文件**：`app/services.py`。

```python
ALLOWED_TRANSITIONS = {
    "empty": {"user_prompt_submitted"},
    "user_prompt_submitted": {"structured_prompt_ready"},
    "structured_prompt_ready": {"structured_prompt_approved", "user_prompt_submitted"},  # 用户可以回炉
    "structured_prompt_approved": {"draft_generating"},
    "draft_generating": {"draft_generated", "draft_failed"},
    "draft_generated": {"draft_revising", "draft_approved"},
    "draft_revising": {"draft_generated"},
    "draft_approved": {"canon_patch_ready"},
    "canon_patch_ready": {"completed"},
}
```

任何不在转移表中的状态变化 → `WorkflowStateError`，避免半成品状态污染数据库。

### 3.9 P1 — Service 拆分（轻量）

不要一步到位拆 6 个服务。本期只做：
- `app/services.py` 拆成 `app/services/chapter_workflow.py` / `bootstrap.py` / `base_docs.py`，按 plan §20。
- `orchestrator.py` 保留为协调层。
- `app/agents/base.py` 已存在，**所有 Agent 改成继承同一基类**，强制 `run(input: AgentInput) -> AgentResult`。

### 3.10 P1 — 可观测性

新建 `GET /api/admin/agent-runs?novel_id&chapter_id`：
- 用于前端「本章流程日志」拉数据。
- 返回字段：`agent_name`、`model`、`input_payload`、`output_payload`、`token_usage`、`status`、`error_message`、`latency_ms`、`created_at`。

`latency_ms` 字段：`agent_runs` 表新增 `started_at`, `completed_at`；前端用 `completed_at - started_at` 显示。

### 3.11 P1 — 数据备份脚本

- `scripts/backup_local.sh`：tar `~/Library/Application Support/LinoI/` + `imports/` → `~/Library/Application Support/LinoI/backups/YYYY-MM-DD-HHmm.tar.gz`。
- `scripts/restore_local.sh`：支持 `LINOI_DRY_RUN_RESTORE=1` 预演 + `LINOI_CONFIRM_RESTORE=1` 真做。
- App 设置页右栏 "本地数据位置" 卡片要能调起这两个脚本（或显示命令）。

---

## 4. 跨端契约（双端必须同步对齐）

| 契约 | 现状 | 目标 | 同步迁移点 |
|---|---|---|---|
| KM `visibility` | list + dict 双形态 | dict only | §3.5 + 前端 `Models.swift` |
| 错误返回 envelope | 各路由格式不一 | 统一 `{error: {kind, message, retryable, ...}}` | §3.7 + 前端 `APIError` |
| Agent run timeline | mock | 真 latency + token | §3.10 + 前端 `ChapterDebugLogView` |
| character `current_state` | string | dict {physical, emotional, goal} | §2.6 + §3.4 schema |
| Workspace 命名 | "知识矩阵" / "版本与调试" | "Knowledge Matrix" / "本章流程日志" | §2.10 |
| 流式正文 | 同步 POST | SSE | §3.2 + 前端 `URLSession.bytes` |

**契约更新规则**：后端先在 dev 分支落地新 schema，前端拉到新 schema 后立即修；不允许任一端单方面停留在旧 schema 超过半天。

---

## 5. 错误与重试矩阵

| 触发 | 后端动作 | 前端动作 |
|---|---|---|
| LLM timeout / 5xx | 重试 3 次（0.5s / 1.5s / 4s） | 失败后 toast + 重试按钮 |
| LLM 429 | 重试 3 次（4s / 8s / 16s） | 显示"上游限流，已自动等待" |
| LLM 401 | 不重试 | 跳设置页 + 高亮 LLM Provider |
| JSON 解析失败 | 重试 1 次（强化 system prompt） | 显示"模型输出格式异常，重试一次" |
| Audit S0 ≥ 1 | 自动 Revision，最多 2 轮 | Inspector 显示 "硬错误已自动修复 N 次" |
| Workflow 状态非法 | 不重试 | toast "请先完成上一步" |
| 网络断开 | 重试 3 次 | 顶部 banner "本地后端不可达"，提示重启 LaunchAgent |
| DB 写入失败 | 不重试 | toast + "请截图反馈"，保留草稿到 IndexedDB-like 缓存 |

---

## 6. 测试矩阵

### 6.1 后端
- `pytest` 必须新增以下 case：
  - `test_llm_gateway_retry_on_timeout`：mock httpx 超时 → 重试 3 次 → 第二次成功。
  - `test_llm_gateway_429_backoff`：模拟 429 后回 200。
  - `test_audit_named_entity_catches_unauthorized`：构造一段含 "D" 的正文 → 必出 S0。
  - `test_bootstrap_schema_validation_fails`：mock LLM 返回缺字段 → ImportAgent 抛 LLMJSONParseError。
  - `test_workflow_state_machine_rejects_skip`：试图从 step 1 跳 step 3 → 409。
  - `test_km_visibility_dict_roundtrip`：保存 dict → 读出 dict，且向后兼容老 list。

### 6.2 前端
- `swift test` 新增：
  - `LoadIfNeededTests`：连续调 5 次 `loadIfNeeded` 只触发 1 次网络。
  - `OptimisticEditTests`：失败回滚后 UI 状态恢复。
  - `ChapterStepGuardTests`：locked step 不响应点击。

### 6.3 手工 E2E (Step 5 of v1.0上线步骤.md)
- 新建一本书 → 导入 3 章 → 分析 → 验证 4 类基础文件都非空、字段都填了。
- 跑第 4-6 章五步流程；每章至少 1 次"要求修改"，验证 Revision 流程。
- 在 LLM Provider 填错 API key → 第 4 章 step 2 触发 → 必弹错误 + 跳设置；改回 → 重试成功。
- 关闭后端 → 重新打开 App → 顶部 banner "本地后端不可达"。
- 修人物卡 "current_state" → 重启 App → 编辑仍在。

---

## 7. 施工顺序（5 周）

**前置规则**：前后端契约改动周内必须对齐；当周不对齐的契约改动延后到下周。

### Week 1 · 后端打地基
1. LLM Gateway 加重试 + 错误细分（§3.1, §3.7）。
2. Agent 模板化 + Bootstrap schema 强约束（§3.4, §3.6）。
3. alembic 迁移 KM visibility 为 dict（§3.5）。
4. 章节状态机校验（§3.8）。
5. 单测全跑通。

### Week 2 · 前端基础设施
1. `loadIfNeeded` 全替换（§2.1.1）。
2. 统一动画 token（§2.2）。
3. RootShell 三栏调宽 + Inspector 重写为 5 节（§2.3, §2.4）。
4. Workspace 命名 + Sidebar Footer 文案（§2.10）。
5. KM Pill Picker + visibility dict 适配（§2.7 + §3.5 联动）。

### Week 3 · 五步流程视觉细化
1. Step 1 双栏 + mini note（§2.5 Step 1）。
2. Step 2 TemplateCard 重写（§2.5 Step 2）。
3. Step 3 draft 字体 + 反馈 UX（§2.5 Step 3）。
4. Stepper done 状态加强（§2.2）。

### Week 4 · 流式 + 调试日志
1. 后端 SSE Writing Agent（§3.2）。
2. 前端流式接入 + Inspector 实时字数（§2.1.3 + §2.4）。
3. 「本章流程日志」重写（§2.8）+ Admin agent-runs API（§3.10）。
4. Audit 真比对 + S0 自动 Revision（§3.3）。

### Week 5 · 基础文件 + 收尾
1. BaseFiles TemplateCard 全部落地（§2.6）。
2. 备份 / 恢复脚本（§3.11）。
3. 取消 Command Palette，移除 `⌘K` 快捷键提示（§2.1.5）。
4. 测试矩阵全跑通；`v1.0.0-local` tag 需最终发布冻结时单独确认。

---

## 8. v1.0 验收闸口（必须全过）

### 8.1 体感
- [ ] 切换工作区延迟 < 80ms（含动画）。
- [ ] 切换章节延迟 < 120ms。
- [ ] 主按钮按下后 80ms 内显示 loading 状态。
- [ ] Writing Agent 流式可见，从空到 ~3000 字过程中**没有"等了 30 秒突然出现"的体验**。

### 8.2 功能
- [ ] 新书导入 3 章 → 4 类基础文件都非空、都按模板填好。
- [ ] 第 4-6 章每章都跑完五步，且 Knowledge Matrix 不出现自相矛盾。
- [ ] 人物卡 `current_state` 是结构化的（身体/情绪/目标分开显示）。
- [ ] World Bible 必须包含 7 个 section_key 全集。
- [ ] LLM 失败、JSON 失败、网络失败时 toast 文案准确，可重试。
- [ ] 「本章流程日志」能看到完整 Agent timeline + 每条 IO + token + latency。
- [ ] Sidebar Footer 文案到位；Inspector 5 节都有内容；KM 用 Pill Picker。

### 8.3 数据
- [ ] 重启 App + 重启后端 → 编辑都保留。
- [ ] `scripts/backup_local.sh` 可生成完整备份；`scripts/restore_local.sh` 可恢复。
- [ ] `canon_edit_history` 记录所有手动编辑。
- [ ] `.env` / API key / owner token 不在 git。

### 8.4 工程
- [ ] `pytest` 全过（含新测试）。
- [ ] `swift test` 全过。
- [ ] `Scripts/package_app.sh` 出 `LinoI.app` 且 codesign 通过。
- [ ] Git tag `v1.0.0-local` 推上去。

---

## 9. 不在本期做的（v1.1+）

按优先级排：

1. **v1.1**：后台任务队列 + 进度轮询 + 失败任务可一键续跑；远程 LLM provider 切换不需要重启。
2. **v1.2**：Canon conflict detection（手动编辑 vs Canon Merge Agent 的冲突合并 UI）。
3. **v1.3**：pgvector / 真检索；Context Compiler 不再用 tag 匹配兜底。
4. **v1.4**：自动更新、签名公证、Sparkle 集成。
5. **v2.0**：云部署、多设备同步、多人协作（重大变更，单独立项）。

---

## 10. 一段话给施工队

> 这一期不要再写"还差一公里"的话。本期施工目标只有一件事：**让 v1.0 在一台你自己每天用的 Mac 上，不卡、能跑、不会丢稿子、出错知道为什么错。**
>
> 优先级永远是：**正确性 > 性能 > 视觉**。如果某个动画或玻璃材质让 60Hz 掉到 30Hz，先关掉动画再说。
>
> 所有方案都已经在 `macOS新前端+改造后逻辑链路.html` 里画过样子；不要自由发挥，按 HTML 落 SwiftUI。颜色 token、间距、圆角都对齐 HTML 的 CSS 变量。
>
> 任何"我觉得这里再加一个功能会更好"的冲动，请压住。v1.0 之后我们有的是时间。
