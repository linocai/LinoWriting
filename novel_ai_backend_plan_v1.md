# AI 小说创作 App 后端规划文档 v1

> 目标读者：Codex / 后端实现者  
> 产品形态：iOS & macOS App + 后端 API + LLM Agent 工作流  
> 核心定位：不是长对话续写器，而是“小说操作系统”

---

## 0. 本版确认过的产品决策

本版本采用以下决策作为硬约束。

### 0.1 不做 Scene Plan

- 每章约 3000 字。
- 每章最多两个场景。
- 不需要独立的 `Scene Plan` 数据结构。
- 不需要按 scene 分段调用写作 Agent。
- 写作 Agent 以“整章”为单位生成正文。
- 如果一章内存在两个场景，只在结构化 Prompt 中自然描述，不拆成独立工作流。

### 0.2 用户只做五类动作

用户体验必须保持简单。用户只需要做：

1. 输入本章创作 Prompt。
2. 审核 / 修改 / 批准结构化 Prompt。
3. 审核正文。
4. 批准正文。
5. 确认基础文档更新。

除了这五类动作，不要增加额外交互负担。

尤其不要要求用户额外审核：

- Context Pack。
- Revision Plan。
- Agent 调用计划。
- 审核报告。
- 检索结果。
- 每个子 Agent 的中间输出。

这些内容可以作为高级调试面板存在，但不能成为主流程里的必需动作。

### 0.3 基础文件必须可手动编辑

因为系统只强制导入前三章，后续可能出现新人物、新地点、新设定、新关系、新写作规则，所以基础文件必须支持用户手动编辑。

基础文件包括：

- World Bible。
- Character Cards。
- Knowledge Matrix。
- Memory / Chapter Facts。

其中：

- 人物关系合并进人物卡，不单独做 Relationship Graph。
- 不做伏笔和悬念表，后续如果写悬疑小说再扩展。
- Style Bible 合并进 World Bible。
- World Bible 不是狭义“世界规则”，而是整本小说的总 Bible。它可以容纳现实世界小说中各种重要但不好归类的信息，例如叙事风格、时代背景、职业细节、主题限制、叙述禁忌、故事基调、现实逻辑等。

---

## 1. 核心目标

本系统要解决的问题不是“让 AI 继续写下一段”，而是：

1. 保持长篇小说的一致性。
2. 避免 AI 忘记已发生事实。
3. 避免 AI 让人物性格漂移。
4. 避免 AI 把所有人物和设定都塞进每一章。
5. 支持用户以低负担方式持续写完整本小说。
6. 支持后续新增人物、设定、关系、世界信息。
7. 支持基础文件人工修订和版本化。

最重要的设计原则：

```text
写作 Agent 不是全知的。
写作 Agent 只拿到本章需要的上下文。
完整 Canon 由后端保存。
上下文选择由 Context Compiler 控制。
越界检查由 Audit Agents 完成。
通过后的正文再反向更新基础文档。
```

---

## 2. 高层工作流

用户侧只看到五步：

```text
1. 用户输入本章 Prompt
        ↓
2. 用户审核结构化 Prompt
        ↓
3. 系统生成正文，用户审核正文
        ↓
4. 用户批准正文
        ↓
5. 用户确认基础文档更新
```

后端实际执行完整流程：

```text
用户输入本章 Prompt
        ↓
Intent Parser
        ↓
Context Compiler
        ↓
Prompt Expander
        ↓
用户审核 / 修改 / 批准结构化 Prompt
        ↓
Writing Agent
        ↓
Audit Agents
        ↓
如果有硬错误：自动进入 Revision Agent
        ↓
用户审核正文
        ↓
如果用户不满意：Revision Agent 根据用户意见修改
        ↓
用户批准正文
        ↓
Extraction Agent
        ↓
Canon Merge Agent
        ↓
用户确认基础文档更新
        ↓
更新 World Bible / Character Cards / Knowledge Matrix / Memory
```

注意：

- `Context Pack` 不需要用户审核。
- `Audit Report` 不需要用户审核。
- `Revision Plan` 不需要用户审核。
- 但这些都要保存，方便后续调试。

---

## 3. 系统边界

### 3.1 本系统做什么

- 导入前三章。
- 分析前三章，生成初始基础文件。
- 允许用户手动编辑基础文件。
- 根据用户本章 Prompt 自动扩展成结构化 Prompt。
- 生成 3000 字左右章节正文。
- 自动检查正文是否偏离 Canon。
- 根据用户修改意见自动修改正文。
- 用户批准后，自动提取本章新事实。
- 让用户确认基础文档更新。
- 版本化保存每一章、每次修改、每次基础文档变化。

### 3.2 本版暂不做什么

- 不做 Scene Plan。
- 不做按 scene 生成正文。
- 不做伏笔 / 悬念表。
- 不做复杂关系图谱可视化。
- 不做多人协作。
- 不做出版排版。
- 不做自动连载发布。
- 不做完全无人审核的自动写书。

---

## 4. 核心概念

### 4.1 Canon

Canon 是小说当前被确认的事实集合。它包括：

- 已发生事件。
- 人物当前状态。
- 人物关系。
- 地点状态。
- 重要物品状态。
- 现实逻辑或世界规则。
- 谁知道什么。
- 当前叙事风格与禁忌。

Canon 不是一个单独文件，而是多个基础文件 + 数据表的合称。

### 4.2 Memory

Memory 记录章节中已经发生的事实，偏向“故事历史”。

示例：

```json
{
  "chapter_no": 3,
  "fact_type": "event",
  "summary": "A 在雨夜发现 B 隐瞒了旧案真相。",
  "participants": ["A", "B"],
  "location": "旧码头",
  "evidence": "第3章第2段",
  "canon_status": "confirmed"
}
```

### 4.3 World Bible

World Bible 是整本书的总 Bible，不只是世界观设定。

它包含：

- 小说基调。
- 叙事风格。
- 语言风格。
- 现实背景。
- 职业 / 行业 / 社会信息。
- 地点信息。
- 时代背景。
- 价值观边界。
- 不允许出现的写法。
- 不知道放在哪里、但对整本小说关键的信息。

Style Bible 合并进 World Bible。

### 4.4 Character Card

人物卡包含：

- 稳定人格。
- 当前状态。
- 当前目标。
- 说话方式。
- 行为边界。
- 秘密。
- 和其他人物的关系。
- 本人物知道什么。
- 本人物不知道什么。

人物关系不单独建图，合并进人物卡。

### 4.5 Knowledge Matrix

Knowledge Matrix 是核心模块。

它记录：

```text
作者知道什么。
读者知道什么。
每个角色知道什么。
每个角色误解什么。
每个角色怀疑什么。
哪些秘密尚未公开。
```

它用于防止：

- 角色突然知道不该知道的信息。
- 旁白提前泄露秘密。
- 读者视角和角色视角混乱。
- 写作 Agent 把 author-only 信息写进正文。

### 4.6 Context Pack

Context Pack 是写作 Agent 本章唯一能看到的上下文包。

写作 Agent 不直接访问完整 Canon。  
写作 Agent 只看 Context Compiler 挑选出来的内容。

Context Pack 包括：

- 本章目标。
- 本章允许出场人物。
- 本章允许提及人物。
- 本章允许使用的专名。
- 相关 Memory。
- 相关 Character Card 摘要。
- 相关 Knowledge Matrix 限制。
- 相关 World Bible 摘要。
- 写作风格限制。
- 禁止事项。

---

## 5. 角色 / 设定激活机制

为了解决“AI 每章都把所有人物和世界观拿出来显摆”的问题，每章必须有激活机制。

### 5.1 Activation State

每个实体在每一章都可以处于以下状态之一：

```text
ACTIVE
本章可以出场、行动、说话、推动情节。

MENTION_ALLOWED
本章可以被短暂提及，但不能出场，不能展开支线。

BACKGROUND
存在于 Canon 中，但不进入写作 Agent 的上下文。

LOCKED_OUT
本章禁止出现。写作 Agent 不应看到其名字。

NEW_ALLOWED
本章允许新引入人物、地点或设定。
```

### 5.2 最重要的规则

不要把本章不该出现的人物名字交给写作 Agent。

错误方式：

```text
这章不要写 D、E、F。
```

正确方式：

```text
Context Pack 中根本不包含 D、E、F。
Audit Agent 在生成后检查是否意外出现 D、E、F。
```

### 5.3 Allowed Named Entities

每章必须生成 `allowed_named_entities` 白名单。

写作 Agent 只能使用白名单里的专名。

示例：

```json
{
  "allowed_named_entities": [
    "A",
    "B",
    "C",
    "旧码头",
    "旧案"
  ],
  "active_entities": ["A", "B", "C"],
  "mention_allowed_entities": [],
  "new_entity_policy": "allow_minor_unnamed_only"
}
```

### 5.4 Mention Budget

如果某人物或设定可以被提到，但不能展开，需要设置提及预算。

示例：

```json
{
  "entity": "A的母亲",
  "activation": "MENTION_ALLOWED",
  "mention_budget": 1,
  "allowed_form": "brief_memory",
  "forbidden_form": [
    "不能出场",
    "不能有对话",
    "不能展开完整回忆"
  ]
}
```

Audit Agent 需要检查实际提及次数。

---

## 6. Agent 设计

### 6.1 Orchestrator

Orchestrator 不是 LLM，建议用后端代码实现。

职责：

- 管理章节状态机。
- 调用各个 Agent。
- 控制哪些 Agent 能访问哪些数据。
- 保存中间结果。
- 执行自动重试。
- 处理用户动作。
- 记录 Agent 日志。

### 6.2 Import Agent

用于导入前三章。

输入：

- Chapter 1 原文。
- Chapter 2 原文。
- Chapter 3 原文。

输出：

- 初始 World Bible。
- 初始 Character Cards。
- 初始 Knowledge Matrix。
- 初始 Memory。

### 6.3 Intent Parser

输入：

- 用户本章 Prompt。
- 当前小说基础信息。

输出：

- 本章目标。
- 显式人物。
- 显式地点。
- 显式事件。
- 情绪基调。
- 是否允许新人物。
- 是否允许新地点。
- 是否可能涉及秘密信息。

### 6.4 Context Compiler

系统核心模块之一。

输入：

- Intent Parser 输出。
- World Bible。
- Character Cards。
- Knowledge Matrix。
- Memory。

输出：

- Context Pack。

职责：

- 选择本章相关人物。
- 选择本章相关世界信息。
- 选择本章相关历史事实。
- 构造 allowed_named_entities。
- 构造 Knowledge 限制。
- 隐藏本章不应出现的人物和设定。

### 6.5 Prompt Expander

输入：

- 用户原始 Prompt。
- Context Pack。

输出：

- 结构化 Prompt。

注意：

- Prompt Expander 不做正文写作。
- Prompt Expander 不输出 Scene Plan。
- Prompt Expander 可以在结构化 Prompt 中描述“一章内可能有两个自然段落/场面转换”，但不生成独立 scene 数据结构。

### 6.6 Writing Agent

输入：

- 用户批准后的结构化 Prompt。
- Context Pack。

输出：

- 一整章正文，约 3000 字。

限制：

- 不直接访问完整 Canon。
- 不使用 allowed_named_entities 之外的专名。
- 不主动显摆世界观。
- 不让未激活人物出场。
- 不泄露 Knowledge Matrix 中限制的信息。

### 6.7 Audit Agents

Audit Agents 在正文生成后自动运行。

建议拆成多个检查器：

1. Named Entity Auditor。
2. Continuity Auditor。
3. Knowledge Auditor。
4. Character Consistency Auditor。
5. World Bible Auditor。
6. Style / Exposition Auditor。

这些 Agent 可以访问更完整的 Canon，因为它们不负责写正文。

输出：

- 审核问题列表。
- 严重程度。
- 修复建议。
- 是否必须自动修改。

严重程度：

```text
S0：硬错误，必须修改。
S1：明显问题，建议修改。
S2：可选优化。
```

### 6.8 Revision Agent

输入：

- 当前正文。
- 用户修改意见。
- Audit Agents 的问题。
- Context Pack。
- 结构化 Prompt。

输出：

- 修改后的正文。

规则：

- 优先修复 S0。
- 保持用户已满意的部分。
- 不擅自大改整章，除非用户明确要求。
- 修改后重新运行 Audit。

### 6.9 Extraction Agent

在用户批准正文后运行。

输入：

- 最终批准正文。
- 当前 Canon。

输出：

- 候选基础文档更新。

必须区分：

```text
客观发生的事实。
角色相信的事。
角色怀疑的事。
读者得到的暗示。
作者级秘密。
可能需要用户确认的设定变化。
```

### 6.10 Canon Merge Agent

输入：

- Extraction Agent 候选更新。
- 当前基础文档。

输出：

- 基础文档更新 Patch。

职责：

- 判断新事实是否与旧事实冲突。
- 判断是新增、覆盖、补充还是撤销。
- 生成用户可确认的更新列表。
- 用户确认后写入数据库。

---

## 7. Agent 权限矩阵

| 模块 | 可看完整 World Bible | 可看完整 Character Cards | 可看完整 Knowledge Matrix | 可看完整 Memory | 可写正文 | 可写基础文档 |
|---|---:|---:|---:|---:|---:|---:|
| Import Agent | 是 | 是 | 是 | 是 | 否 | 生成初始草案 |
| Intent Parser | 否 | 否 | 否 | 少量摘要 | 否 | 否 |
| Context Compiler | 是 | 是 | 是 | 是 | 否 | 否 |
| Prompt Expander | 否，只看 Context Pack | 否，只看 Context Pack | 否，只看 Context Pack | 否，只看 Context Pack | 否 | 否 |
| Writing Agent | 否，只看 Context Pack | 否，只看 Context Pack | 否，只看 Context Pack | 否，只看 Context Pack | 是 | 否 |
| Audit Agents | 是 | 是 | 是 | 是 | 否 | 否 |
| Revision Agent | 否，只看必要上下文 | 否，只看必要上下文 | 否，只看必要上下文 | 否，只看必要上下文 | 是 | 否 |
| Extraction Agent | 是 | 是 | 是 | 是 | 否 | 生成候选更新 |
| Canon Merge Agent | 是 | 是 | 是 | 是 | 否 | 用户确认后写入 |

---

## 8. 基础文件结构

### 8.1 World Bible

World Bible 是自由度最高的基础文档，但内部仍建议结构化保存。

```json
{
  "novel_id": "novel_001",
  "version": 1,
  "title": "World Bible",
  "sections": [
    {
      "section_id": "tone_and_style",
      "title": "叙事基调与文风",
      "content": "整体冷静、克制，避免夸张情绪宣泄。",
      "tags": ["style", "tone", "global"],
      "importance": "high",
      "activation_policy": "always_considered"
    },
    {
      "section_id": "real_world_background",
      "title": "现实背景",
      "content": "故事发生在当代城市，人物行动需要符合现实社会逻辑。",
      "tags": ["setting", "realism", "global"],
      "importance": "high",
      "activation_policy": "always_considered"
    },
    {
      "section_id": "forbidden_patterns",
      "title": "禁用写法",
      "content": "不要用百科式旁白解释人物过去。不要让角色直接说出真实心理。",
      "tags": ["style", "forbidden"],
      "importance": "high",
      "activation_policy": "always_in_context_brief"
    }
  ],
  "updated_at": "2026-05-17T00:00:00Z"
}
```

字段说明：

- `content` 允许长文本。
- `tags` 用于 Context Compiler 检索。
- `importance` 用于控制是否进入 Context Pack。
- `activation_policy` 控制何时激活。

建议的 `activation_policy`：

```text
always_considered
每章都会参与筛选，但不一定全部进入写作上下文。

always_in_context_brief
每章都进入 Context Pack 的简短摘要。

tag_matched
只有本章 Prompt 或相关实体命中 tag 时进入 Context Pack。

manual_only
默认不自动进入 Context Pack，除非用户或系统明确调用。
```

### 8.2 Character Card

```json
{
  "character_id": "char_A",
  "name": "A",
  "aliases": ["阿A"],
  "status": "active",
  "role": "protagonist",
  "stable_traits": [
    "克制",
    "不轻易承认恐惧",
    "遇到亲密关系时习惯后撤"
  ],
  "current_state": {
    "physical": "左肩受伤未愈",
    "emotional": "对 B 产生怀疑",
    "goal": "查明旧案真相"
  },
  "voice": {
    "dialogue_style": "短句，少解释，常用反问",
    "forbidden": ["不会主动长篇袒露脆弱"]
  },
  "relationships": [
    {
      "target_character_id": "char_B",
      "target_name": "B",
      "relationship_type": "former_ally",
      "current_state": "信任破裂但仍有依赖",
      "history_summary": "前三章中 A 发现 B 隐瞒旧案细节。",
      "last_changed_chapter": 3
    }
  ],
  "knowledge_summary": {
    "knows": ["B 对旧案有所隐瞒"],
    "suspects": ["B 可能知道旧案关键证人"],
    "does_not_know": ["旧案真正凶手"]
  },
  "default_visibility": "on_demand",
  "do_not_auto_mention": true,
  "created_chapter": 1,
  "last_active_chapter": 3,
  "updated_at": "2026-05-17T00:00:00Z"
}
```

### 8.3 Knowledge Matrix

Knowledge Matrix 可以用结构化表保存。

```json
{
  "knowledge_id": "know_001",
  "fact": "B 与旧案有关",
  "truth_status": "confirmed_author_only",
  "visibility": {
    "author": "known",
    "reader": "hinted",
    "A": "suspects",
    "B": "knows",
    "C": "unknown"
  },
  "allowed_narration": {
    "A_pov": "只能写 A 的怀疑和观察，不能直接确认 B 与旧案有关。",
    "omniscient": "本书不使用全知视角提前揭露。"
  },
  "source": "前三章导入分析",
  "last_updated_chapter": 3
}
```

建议的可见状态：

```text
known
unknown
suspects
misunderstands
hinted
reader_known
reader_unknown
author_only
```

### 8.4 Memory / Chapter Facts

```json
{
  "fact_id": "fact_004_001",
  "novel_id": "novel_001",
  "chapter_no": 4,
  "fact_type": "event",
  "summary": "A 在旧码头发现门锁被换过。",
  "participants": ["A"],
  "location": "旧码头",
  "time_in_story": "第四日夜",
  "evidence": "第4章第1部分",
  "canon_status": "confirmed",
  "created_by": "extraction_agent",
  "created_at": "2026-05-17T00:00:00Z"
}
```

---

## 9. 数据库建议

建议使用：

- PostgreSQL：主数据。
- pgvector 或独立向量库：检索 World Bible、Memory、Character Cards 片段。
- Object Storage：保存章节全文、导入原文、Agent 原始输入输出。

### 9.1 novels

```sql
CREATE TABLE novels (
  id UUID PRIMARY KEY,
  title TEXT NOT NULL,
  genre TEXT,
  language TEXT DEFAULT 'zh-CN',
  status TEXT NOT NULL DEFAULT 'active',
  current_canon_version INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### 9.2 chapters

```sql
CREATE TABLE chapters (
  id UUID PRIMARY KEY,
  novel_id UUID NOT NULL REFERENCES novels(id),
  chapter_no INTEGER NOT NULL,
  status TEXT NOT NULL,
  user_prompt TEXT,
  approved_structured_prompt JSONB,
  approved_text TEXT,
  canon_version_used INTEGER,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(novel_id, chapter_no)
);
```

### 9.3 chapter_versions

```sql
CREATE TABLE chapter_versions (
  id UUID PRIMARY KEY,
  chapter_id UUID NOT NULL REFERENCES chapters(id),
  version_no INTEGER NOT NULL,
  text TEXT NOT NULL,
  source TEXT NOT NULL,
  user_feedback TEXT,
  audit_summary JSONB,
  created_by_agent TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(chapter_id, version_no)
);
```

`source` 可选：

```text
initial_generation
revision_by_user_feedback
revision_by_audit
manual_edit
approved_final
```

### 9.4 world_bible_sections

```sql
CREATE TABLE world_bible_sections (
  id UUID PRIMARY KEY,
  novel_id UUID NOT NULL REFERENCES novels(id),
  section_key TEXT NOT NULL,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  tags TEXT[] DEFAULT '{}',
  importance TEXT DEFAULT 'medium',
  activation_policy TEXT DEFAULT 'tag_matched',
  version INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### 9.5 characters

```sql
CREATE TABLE characters (
  id UUID PRIMARY KEY,
  novel_id UUID NOT NULL REFERENCES novels(id),
  name TEXT NOT NULL,
  aliases TEXT[] DEFAULT '{}',
  status TEXT DEFAULT 'active',
  role TEXT,
  stable_traits JSONB DEFAULT '[]',
  current_state JSONB DEFAULT '{}',
  voice JSONB DEFAULT '{}',
  relationships JSONB DEFAULT '[]',
  knowledge_summary JSONB DEFAULT '{}',
  default_visibility TEXT DEFAULT 'on_demand',
  do_not_auto_mention BOOLEAN DEFAULT true,
  created_chapter INTEGER,
  last_active_chapter INTEGER,
  version INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(novel_id, name)
);
```

### 9.6 knowledge_matrix_entries

```sql
CREATE TABLE knowledge_matrix_entries (
  id UUID PRIMARY KEY,
  novel_id UUID NOT NULL REFERENCES novels(id),
  fact TEXT NOT NULL,
  truth_status TEXT NOT NULL,
  visibility JSONB NOT NULL DEFAULT '{}',
  allowed_narration JSONB DEFAULT '{}',
  source TEXT,
  last_updated_chapter INTEGER,
  version INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### 9.7 memory_facts

```sql
CREATE TABLE memory_facts (
  id UUID PRIMARY KEY,
  novel_id UUID NOT NULL REFERENCES novels(id),
  chapter_no INTEGER,
  fact_type TEXT NOT NULL,
  summary TEXT NOT NULL,
  participants TEXT[] DEFAULT '{}',
  location TEXT,
  time_in_story TEXT,
  evidence TEXT,
  canon_status TEXT DEFAULT 'confirmed',
  metadata JSONB DEFAULT '{}',
  created_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### 9.8 context_packs

```sql
CREATE TABLE context_packs (
  id UUID PRIMARY KEY,
  chapter_id UUID NOT NULL REFERENCES chapters(id),
  canon_version INTEGER NOT NULL,
  pack JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### 9.9 structured_prompts

```sql
CREATE TABLE structured_prompts (
  id UUID PRIMARY KEY,
  chapter_id UUID NOT NULL REFERENCES chapters(id),
  context_pack_id UUID REFERENCES context_packs(id),
  status TEXT NOT NULL DEFAULT 'draft',
  prompt_json JSONB NOT NULL,
  user_modified_json JSONB,
  approved_json JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### 9.10 audit_reports

```sql
CREATE TABLE audit_reports (
  id UUID PRIMARY KEY,
  chapter_version_id UUID NOT NULL REFERENCES chapter_versions(id),
  report JSONB NOT NULL,
  pass BOOLEAN NOT NULL,
  highest_severity TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### 9.11 canon_update_patches

```sql
CREATE TABLE canon_update_patches (
  id UUID PRIMARY KEY,
  chapter_id UUID NOT NULL REFERENCES chapters(id),
  status TEXT NOT NULL DEFAULT 'pending_user_confirmation',
  patch_json JSONB NOT NULL,
  user_confirmed_json JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  confirmed_at TIMESTAMPTZ
);
```

### 9.12 agent_runs

```sql
CREATE TABLE agent_runs (
  id UUID PRIMARY KEY,
  novel_id UUID REFERENCES novels(id),
  chapter_id UUID REFERENCES chapters(id),
  agent_name TEXT NOT NULL,
  model TEXT,
  input_json JSONB,
  output_json JSONB,
  status TEXT NOT NULL,
  error_message TEXT,
  token_usage JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ
);
```

---

## 10. 章节状态机

```text
EMPTY
  ↓
USER_PROMPT_SUBMITTED
  ↓
CONTEXT_PACK_CREATED
  ↓
STRUCTURED_PROMPT_CREATED
  ↓
STRUCTURED_PROMPT_APPROVED
  ↓
DRAFT_GENERATED
  ↓
DRAFT_AUDITED
  ↓
DRAFT_NEEDS_REVISION  ← 用户不满意或 Audit 有 S0
  ↓                    ↘
DRAFT_REVISED           DRAFT_APPROVED
  ↓                         ↓
DRAFT_AUDITED              EXTRACTION_DONE
                            ↓
CANON_PATCH_CREATED
                            ↓
CANON_PATCH_CONFIRMED
                            ↓
CHAPTER_COMPLETED
```

用户只看到：

```text
输入 Prompt
审核结构化 Prompt
审核正文
批准正文
确认基础文档更新
```

---

## 11. Context Pack 格式

```json
{
  "chapter_no": 4,
  "target_word_count": 3000,
  "user_intent_summary": "A 去旧码头调查，遇到 B，发现 B 隐瞒旧案。C 在结尾给线索。",
  "active_entities": [
    {
      "entity_type": "character",
      "id": "char_A",
      "name": "A",
      "activation": "ACTIVE",
      "role_in_chapter": "视角人物，调查者",
      "relevant_traits": ["克制", "对 B 产生怀疑"],
      "current_state": "左肩受伤未愈；正在查旧案",
      "voice_brief": "短句，少解释，避免主动袒露脆弱"
    },
    {
      "entity_type": "character",
      "id": "char_B",
      "name": "B",
      "activation": "ACTIVE",
      "role_in_chapter": "被试探者",
      "relevant_traits": ["擅长转移话题", "回避旧案"],
      "current_state": "试图掩盖旧案相关信息"
    },
    {
      "entity_type": "character",
      "id": "char_C",
      "name": "C",
      "activation": "ACTIVE",
      "role_in_chapter": "结尾提供线索，不展开个人支线"
    }
  ],
  "mention_allowed_entities": [],
  "allowed_named_entities": ["A", "B", "C", "旧码头", "旧案"],
  "new_entity_policy": {
    "allow_new_named_characters": false,
    "allow_new_named_locations": false,
    "allow_minor_unnamed_characters": true,
    "instructions": "如需路人，只使用普通称谓，不给姓名。"
  },
  "relevant_memory": [
    "第3章中 A 已经怀疑 B 隐瞒旧案。",
    "旧码头曾在第2章被提及为旧案相关地点。"
  ],
  "knowledge_constraints": [
    {
      "fact": "B 与旧案有关",
      "constraint": "A 只能怀疑，不能完全确认。旁白不能直接揭示真相。"
    }
  ],
  "world_bible_brief": [
    "整体文风克制、冷静，避免过度抒情。",
    "现实主义逻辑：调查行为必须符合普通人的能力边界。",
    "不要百科式解释旧案背景。"
  ],
  "hard_forbidden": [
    "不得使用 allowed_named_entities 之外的专名。",
    "不得让未激活人物出场。",
    "不得提前揭露旧案真相。",
    "不得大段解释世界观或背景。"
  ]
}
```

---

## 12. 结构化 Prompt 格式

结构化 Prompt 是用户会审核的核心内容。

不包含 Scene Plan，但可以包含“章节内部推进顺序”。

```json
{
  "chapter_no": 4,
  "target_word_count": 3000,
  "chapter_goal": "让 A 对 B 的怀疑从模糊变成具体证据。",
  "chapter_summary": "A 夜里去旧码头调查，发现异常；B 出现并试图转移话题；A 通过细节确认 B 有隐瞒；结尾 C 给出下一步线索。",
  "narrative_order": [
    "A 抵达旧码头并发现环境异常。",
    "B 出现，二人围绕旧案进行克制的试探。",
    "A 抓住 B 的一个反应，确认 B 至少隐瞒了部分事实。",
    "C 在结尾提供一个新线索，推动下一章。"
  ],
  "active_cast": [
    {
      "name": "A",
      "function": "视角人物，调查和承压",
      "arc_this_chapter": "从怀疑到确认 B 有隐瞒"
    },
    {
      "name": "B",
      "function": "被试探者，制造紧张感",
      "arc_this_chapter": "表面镇定，细节露出破绽"
    },
    {
      "name": "C",
      "function": "结尾给出线索",
      "arc_this_chapter": "短暂出现，不展开个人支线"
    }
  ],
  "must_include": [
    "旧码头的门锁被换过。",
    "B 对某个旧案细节反应异常。",
    "A 不能直接说破，而是通过试探逼近真相。",
    "结尾给出下一章追查方向。"
  ],
  "must_not_include": [
    "不要揭露旧案完整真相。",
    "不要让未激活人物出场或被频繁提及。",
    "不要新增有姓名的重要角色。",
    "不要写成长篇背景说明。"
  ],
  "knowledge_limits": [
    "A 只能怀疑 B 与旧案有关，不能确认全部真相。",
    "读者只能获得更多疑点，不能获得答案。"
  ],
  "style_directives": [
    "压抑、冷感、克制。",
    "多用动作、停顿、反应和对话推进。",
    "少解释人物心理，避免直接说教。",
    "环境描写服务于紧张感。"
  ],
  "ending_requirement": "以新的线索或未解决的紧张关系收束，不要完全解决冲突。"
}
```

用户可在 UI 里直接编辑这个 JSON 的可视化版本。后端保存用户批准后的版本。

---

## 13. Writing Agent Prompt 要点

系统提示词必须强调：

```text
你是长篇小说章节写作 Agent。
你不是世界观百科，也不是全知设定库。
你只能根据 Context Pack 和用户批准的结构化 Prompt 写作。

硬性规则：
1. 只能使用 allowed_named_entities 中列出的专名。
2. 不得让未激活角色出场、说话、被回忆、被旁白解释。
3. 不得主动展示与本章目标无关的世界信息。
4. 不得改写 Context Pack 中的已确认事实。
5. 不得让视角人物知道 Knowledge Constraints 之外的信息。
6. 不得新增重大人物、重大地点、重大组织或重大设定。
7. 如果需要路人，只使用普通称谓，不给姓名。
8. 保持 World Bible Brief 中的文风和禁忌。
9. 输出只包含正文，不解释创作思路。
```

---

## 14. Audit 规则

### 14.1 Named Entity Auditor

输入：

- 正文。
- `allowed_named_entities`。
- 全量人物 / 地点 / 组织 / 术语表。

检查：

- 是否出现未授权专名。
- 是否出现未激活人物。
- 是否新增有姓名角色。
- Mention Allowed 是否超预算。

输出示例：

```json
{
  "pass": false,
  "issues": [
    {
      "severity": "S0",
      "type": "unauthorized_entity",
      "entity": "D",
      "location": "第6段",
      "reason": "D 不在 allowed_named_entities 中。",
      "fix_instruction": "删除 D 的提及，改为 A 对旧码头异常的感受。"
    }
  ]
}
```

### 14.2 Knowledge Auditor

检查：

- 角色是否知道了不该知道的信息。
- 旁白是否泄露了 author-only 信息。
- 读者是否提前获得不该获得的真相。
- 角色误解是否被写成客观事实。

### 14.3 Continuity Auditor

检查：

- 已发生事实是否被改写。
- 人物身体状态是否连续。
- 道具位置是否连续。
- 时间线是否合理。
- 章节间因果是否断裂。

### 14.4 Character Consistency Auditor

检查：

- 人物语言是否符合人物卡。
- 人物行为是否符合当前状态。
- 人物关系是否突然跳变。
- 人物是否说了不符合其人格边界的话。

### 14.5 World Bible Auditor

检查：

- 是否违反 World Bible 中的全局要求。
- 是否文风明显偏离。
- 是否出现不符合现实主义逻辑的行为。
- 是否出现用户明确禁止的写法。

### 14.6 Exposition Auditor

检查：

- 是否重复解释已知设定。
- 是否显摆世界观。
- 是否出现与本章目标无关的背景说明。
- 是否信息量挤压剧情推进。

---

## 15. Revision 策略

Revision Agent 自动处理两类问题：

1. Audit 发现的 S0 硬错误。
2. 用户在“审核正文”时提出的修改意见。

用户不需要审核 Revision Plan。

后端可以内部生成：

```json
{
  "revision_strategy": [
    "删除未授权人物 D 的提及。",
    "压缩第8段背景解释。",
    "把 B 的心虚改成更克制的反应。"
  ],
  "scope": "局部修改，不重写整章"
}
```

但 UI 主流程只展示修改后的正文。

---

## 16. Extraction 输出格式

用户批准正文后，Extraction Agent 生成候选更新。

```json
{
  "memory_facts_to_add": [
    {
      "fact_type": "event",
      "summary": "A 在旧码头发现门锁被换过。",
      "participants": ["A"],
      "location": "旧码头",
      "evidence": "第4章开头",
      "canon_status": "confirmed"
    }
  ],
  "character_updates": [
    {
      "character": "A",
      "field": "current_state.emotional",
      "old_value": "对 B 产生怀疑",
      "new_value": "确认 B 至少隐瞒了旧案部分事实",
      "evidence": "第4章中段"
    }
  ],
  "relationship_updates": [
    {
      "character": "A",
      "target": "B",
      "old_state": "信任破裂但仍有依赖",
      "new_state": "怀疑加深，开始主动试探",
      "evidence": "第4章对话"
    }
  ],
  "knowledge_matrix_updates": [
    {
      "fact": "B 隐瞒旧案部分事实",
      "visibility_change": {
        "A": "suspects -> strongly_suspects",
        "reader": "hinted -> strongly_hinted"
      },
      "evidence": "第4章中段"
    }
  ],
  "world_bible_updates": [],
  "new_entities": [],
  "requires_user_confirmation": [
    {
      "type": "character_state_update",
      "reason": "会影响后续 A 与 B 的互动。"
    }
  ]
}
```

---

## 17. 基础文档更新确认

用户最后一步是“确认基础文档更新”。

UI 展示应简化为：

```text
本章将写入以下更新：

1. Memory 新增 3 条事实。
2. A 的当前状态更新 1 条。
3. A 与 B 的关系更新 1 条。
4. Knowledge Matrix 更新 2 条。
5. World Bible 无更新。
6. 新人物无。
```

用户可以：

- 全部确认。
- 删除某条更新。
- 编辑某条更新。
- 确认后写入。

这仍属于第五类用户动作，不算新增动作。

---

## 18. 手动编辑基础文件

基础文件必须支持随时手动编辑。

### 18.1 可编辑内容

用户可以编辑：

- World Bible section。
- Character Card。
- 人物关系字段。
- Knowledge Matrix 条目。
- Memory fact。

### 18.2 编辑后要做什么

每次编辑基础文件后：

- 创建新版本。
- 记录编辑者为 `user`。
- 重新生成该条目的 embedding。
- 更新 `updated_at`。
- 不自动改写已经批准的章节正文。

### 18.3 编辑版本记录

```sql
CREATE TABLE canon_edit_history (
  id UUID PRIMARY KEY,
  novel_id UUID NOT NULL REFERENCES novels(id),
  target_type TEXT NOT NULL,
  target_id UUID NOT NULL,
  old_value JSONB,
  new_value JSONB,
  edited_by TEXT NOT NULL,
  reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

---

## 19. API 设计

### 19.1 Novel

```http
POST /api/novels
GET /api/novels/{novelId}
PATCH /api/novels/{novelId}
```

### 19.2 Bootstrap / Import

```http
POST /api/novels/{novelId}/bootstrap/import-first-three-chapters
POST /api/novels/{novelId}/bootstrap/analyze
GET  /api/novels/{novelId}/bootstrap/status
```

### 19.3 Base Documents

```http
GET   /api/novels/{novelId}/world-bible
POST  /api/novels/{novelId}/world-bible/sections
PATCH /api/novels/{novelId}/world-bible/sections/{sectionId}
DELETE /api/novels/{novelId}/world-bible/sections/{sectionId}

GET   /api/novels/{novelId}/characters
POST  /api/novels/{novelId}/characters
GET   /api/novels/{novelId}/characters/{characterId}
PATCH /api/novels/{novelId}/characters/{characterId}

GET   /api/novels/{novelId}/knowledge-matrix
POST  /api/novels/{novelId}/knowledge-matrix
PATCH /api/novels/{novelId}/knowledge-matrix/{entryId}
DELETE /api/novels/{novelId}/knowledge-matrix/{entryId}

GET   /api/novels/{novelId}/memory
POST  /api/novels/{novelId}/memory
PATCH /api/novels/{novelId}/memory/{factId}
DELETE /api/novels/{novelId}/memory/{factId}
```

### 19.4 Chapter Workflow

```http
POST /api/novels/{novelId}/chapters
```

创建章节。

```http
POST /api/chapters/{chapterId}/user-prompt
```

用户输入本章 Prompt，后端自动执行 Intent Parser、Context Compiler、Prompt Expander。

```http
GET /api/chapters/{chapterId}/structured-prompt
PATCH /api/chapters/{chapterId}/structured-prompt
POST /api/chapters/{chapterId}/structured-prompt/approve
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

用户审核正文。

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

如果 `decision=revise`，后端自动调用 Revision Agent 并重新 Audit。

```http
POST /api/chapters/{chapterId}/approve-final-text
```

用户批准正文。后端自动执行 Extraction 和 Canon Merge，生成基础文档更新 Patch。

```http
GET /api/chapters/{chapterId}/canon-update-patch
PATCH /api/chapters/{chapterId}/canon-update-patch
POST /api/chapters/{chapterId}/canon-update-patch/confirm
```

用户确认基础文档更新。

---

## 20. 后端服务拆分

### 20.1 API Server

职责：

- 提供 REST API。
- 处理鉴权。
- 校验请求。
- 返回章节状态。
- 与 Workflow Engine 通信。

### 20.2 Workflow Engine

职责：

- 管理章节状态机。
- 调用 Agent。
- 保存中间输出。
- 执行自动重试。
- 控制用户动作后的下一步。

### 20.3 LLM Gateway

职责：

- 统一调用模型。
- 注入 system prompt。
- 处理结构化输出。
- 记录 token 使用。
- 处理重试。
- 处理模型降级。

### 20.4 Canon Service

职责：

- 读取 / 写入 World Bible。
- 读取 / 写入 Character Cards。
- 读取 / 写入 Knowledge Matrix。
- 读取 / 写入 Memory。
- 管理版本。

### 20.5 Retrieval Service

职责：

- 根据 Prompt 和 tags 检索相关 Bible sections。
- 检索相关 Memory。
- 检索相关人物信息。
- 生成 Context Compiler 候选集合。

### 20.6 Audit Service

职责：

- 命名实体检查。
- 连续性检查。
- Knowledge 检查。
- World Bible 检查。
- 风格与显摆设定检查。

---

## 21. 新人物和新设定处理

因为只导入前三章，后续一定会出现新人物和新设定。

### 21.1 新人物出现策略

结构化 Prompt 里必须有：

```json
{
  "new_entity_policy": {
    "allow_new_major_character": false,
    "allow_new_minor_named_character": false,
    "allow_unnamed_minor_character": true
  }
}
```

如果用户原始 Prompt 明确要求新人物，例如：

```text
这一章让一个新角色林岚出现，她是 A 的旧同事。
```

Intent Parser 应识别：

```json
{
  "new_entities_requested_by_user": [
    {
      "type": "character",
      "name": "林岚",
      "role_hint": "A 的旧同事"
    }
  ]
}
```

Context Compiler 应把 `林岚` 加入 allowed_named_entities，并生成临时人物卡。

章节通过后，Extraction Agent 生成正式 Character Card 候选更新，用户在基础文档更新阶段确认。

### 21.2 新世界信息出现策略

如果用户 Prompt 明确引入新设定或现实信息，结构化 Prompt 可以包含。

如果 Writing Agent 擅自引入重大新设定，Audit Agent 应标记为 S0 或 S1。

---

## 22. 防止“显摆设定”的实现细节

必须同时使用四层控制。

### 22.1 上下文层控制

不把无关人物和设定放进 Context Pack。

### 22.2 白名单层控制

`allowed_named_entities` 限制正文可出现专名。

### 22.3 Prompt 层控制

Writing Agent system prompt 明确禁止百科式展示。

### 22.4 审核层控制

Audit Agent 检查：

- 未授权人物。
- 未授权地点。
- 未授权术语。
- 无关背景解释。
- 设定重复解释。

---

## 23. 错误处理

### 23.1 结构化输出解析失败

- LLM Gateway 自动重试。
- 第二次失败时使用更严格 schema prompt。
- 第三次失败时返回错误给 Workflow Engine。

### 23.2 写作结果字数偏差

如果小于目标 70% 或大于目标 140%，自动要求 Writing Agent 局部扩写或压缩。

### 23.3 Audit 出现 S0

- 自动调用 Revision Agent。
- 修复后重新 Audit。
- 最多自动循环 2 次。
- 仍有 S0 时，在正文审核界面提示用户“系统发现硬错误”，但不增加新的用户动作。

### 23.4 Canon Patch 冲突

如果 Canon Merge Agent 发现新旧基础文档冲突，进入用户确认基础文档更新阶段，由用户决定保留旧设定还是接受新设定。

---

## 24. 日志与可观测性

每次 Agent 调用必须记录：

- agent_name。
- model。
- input hash。
- output。
- token usage。
- latency。
- success / failure。
- chapter_id。
- canon_version。

建议提供内部调试页：

```text
Chapter Debug View
- User Prompt
- Intent Parser Output
- Context Pack
- Structured Prompt
- Draft Versions
- Audit Reports
- Revision History
- Extraction Output
- Canon Patch
```

但调试页不属于用户主流程。

---

## 25. MVP 实现顺序

### Phase 1：基础数据与导入

- 创建 novel。
- 导入前三章。
- 生成初始 World Bible。
- 生成初始 Character Cards。
- 生成初始 Knowledge Matrix。
- 生成初始 Memory。
- 支持手动编辑基础文件。

### Phase 2：章节生成主流程

- 用户输入本章 Prompt。
- Intent Parser。
- Context Compiler。
- Prompt Expander。
- 用户审核结构化 Prompt。
- Writing Agent 生成正文。

### Phase 3：审核与修改

- Named Entity Auditor。
- Knowledge Auditor。
- Continuity Auditor。
- Revision Agent。
- 用户审核正文。
- 用户批准正文。

### Phase 4：提取与基础文档更新

- Extraction Agent。
- Canon Merge Agent。
- 生成基础文档更新 Patch。
- 用户确认更新。
- 写入 Canon。

### Phase 5：稳定性和调试

- Agent 日志。
- 版本回滚。
- Context Pack 调试。
- Audit 报告调试。
- 成本统计。

---

## 26. 最小可行版本必须实现的能力

MVP 最低要求：

1. 导入前三章并生成初始基础文件。
2. 基础文件可手动编辑。
3. 每章生成 Context Pack。
4. 结构化 Prompt 可供用户审核和修改。
5. Writing Agent 只看 Context Pack 和批准后的结构化 Prompt。
6. `allowed_named_entities` 白名单检查。
7. Knowledge Matrix 检查。
8. 用户不满意正文时可以输入修改意见并自动改稿。
9. 用户批准正文后自动提取基础文档更新。
10. 用户确认后再写入基础文件。

---

## 27. 实现注意事项

### 27.1 不要把基础文件全文直接塞给写作 Agent

这是系统成败的关键。

写作 Agent 只能看到 Context Pack。

### 27.2 不要让 Extraction Agent 直接写数据库

Extraction Agent 只生成候选更新。  
Canon Merge Agent 生成 Patch。  
用户确认后再写数据库。

### 27.3 不要让用户审核过多中间步骤

用户体验必须保持五个动作。

内部 Agent 可以很多，但用户不应该感觉自己在管理 Agent。

### 27.4 不要把“没有提到”当成“不存在”

Context Pack 没给 Writing Agent 的人物，并不是从小说世界中删除，只是本章不进入叙事视野。

### 27.5 新人物必须允许，但要可控

如果用户明确引入新人物，系统必须支持。  
如果 AI 擅自引入新人物，系统应拦截。

---

## 28. 一章的端到端示例

### 28.1 用户输入

```text
第4章：A 去旧码头调查，遇到 B，发现 B 隐瞒旧案。C 在结尾给一个线索。整体压抑一点，不要把真相说破。
```

### 28.2 后端自动生成结构化 Prompt

```json
{
  "chapter_goal": "让 A 对 B 的怀疑从模糊变成具体证据。",
  "chapter_summary": "A 到旧码头调查，发现门锁异常；B 出现并回避旧案；A 通过细节确认 B 有隐瞒；C 在结尾提供下一步线索。",
  "active_cast": ["A", "B", "C"],
  "allowed_named_entities": ["A", "B", "C", "旧码头", "旧案"],
  "must_include": [
    "A 发现旧码头异常。",
    "B 回避关键问题。",
    "C 在结尾提供线索。"
  ],
  "must_not_include": [
    "不要揭露旧案真相。",
    "不要引入未授权人物。",
    "不要大段解释背景。"
  ],
  "style_directives": [
    "压抑",
    "克制",
    "多动作与对话",
    "少解释心理"
  ]
}
```

### 28.3 用户审核并批准

用户可以修改结构化 Prompt，例如：

```text
把 C 的出现压到最后 300 字以内。
B 不要明显心虚，只在一个细节上露出问题。
```

### 28.4 系统生成正文并自动审核

如果正文提到 D，Named Entity Auditor 标记 S0，Revision Agent 自动删除或改写。

### 28.5 用户审核正文

用户如果不满意，输入：

```text
B 还是太明显了，改得更像是在正常解释，但让 A 注意到一个前后矛盾的小细节。
```

Revision Agent 修改。

### 28.6 用户批准正文

系统提取：

- A 去过旧码头。
- A 发现门锁被换。
- A 对 B 的怀疑加深。
- C 给出新线索。
- A 对某个秘密仍不知道完整真相。

### 28.7 用户确认基础文档更新

系统展示 Patch，用户确认后写入。

---

## 29. 本版本结论

本后端架构的核心不是“让一个超大 Prompt 写完小说”，而是：

```text
基础文档保存小说真相。
Context Compiler 决定本章可见内容。
结构化 Prompt 决定本章写作目标。
Writing Agent 只负责文学化生成。
Audit Agents 负责防越界。
Extraction Agent 负责提取新事实。
用户只保留关键审核权。
```

只要严格执行“写作 Agent 不看完整 Canon”和“allowed_named_entities 白名单”，就能显著降低每章乱提无关人物、乱显摆世界观、乱泄露秘密的问题。
