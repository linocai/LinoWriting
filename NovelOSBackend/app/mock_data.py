APPLE_REFERENCE_NOW = 800_000_000.0

NOVEL = {
    "id": "novel_001",
    "title": "雨夜旧码头",
    "genre": "现实向",
    "status": "active",
    "language": "zh-Hans",
    "current_chapter_no": 4,
    "current_canon_version": 12,
    "bootstrap_status": "completed",
}

CHAPTER = {
    "id": "chapter_004",
    "novel_id": "novel_001",
    "chapter_no": 4,
    "title": "旧码头",
    "status": "draftInput",
    "target_word_count": 3000,
    "approved_version_id": None,
    "current_version_id": None,
    "canon_version_used": 12,
}

IMPORTED_CHAPTERS = [
    {
        "chapter": {
            "id": "chapter_001",
            "novel_id": "novel_001",
            "chapter_no": 1,
            "title": "雨夜来信",
            "status": "completed",
            "target_word_count": 3000,
            "approved_version_id": "draft_001_import_v1",
            "current_version_id": "draft_001_import_v1",
            "canon_version_used": 4,
        },
        "draft": {
            "id": "draft_001_import_v1",
            "chapter_id": "chapter_001",
            "version_no": 1,
            "text": """雨下到后半夜时，A 收到了一封没有署名的邮件。

邮件里只有一张旧码头的照片。照片拍得很暗，仓库外墙被雨水洗得发黑，门口那盏坏掉多年的灯却亮着。A 盯着那一点光看了很久，直到屏幕自动暗下去。

他知道旧码头不该有人去。三年前的案子在那里结束，也在那里被匆忙封存。档案写得干净，结论写得确定，可 A 一直记得母亲听见旧码头三个字时突然停住的手。

照片下方还有一句话：如果你还想知道真相，明天去查那把旧锁。
""",
            "word_count": 224,
            "audit_summary": None,
            "source": "imported_source",
            "created_at": APPLE_REFERENCE_NOW,
        },
    },
    {
        "chapter": {
            "id": "chapter_002",
            "novel_id": "novel_001",
            "chapter_no": 2,
            "title": "旧锁",
            "status": "completed",
            "target_word_count": 3000,
            "approved_version_id": "draft_002_import_v1",
            "current_version_id": "draft_002_import_v1",
            "canon_version_used": 8,
        },
        "draft": {
            "id": "draft_002_import_v1",
            "chapter_id": "chapter_002",
            "version_no": 1,
            "text": """第二天清晨，A 没有先去警局。

他绕到旧码头外围，从一条被杂草挡住的小路进去。铁门还在，锁也还在，锈迹沿着锁孔边缘结成一圈暗红色的线。A 拍下照片，把它和邮件里的那张反复对照。

B 是在他离开前出现的。对方没有问他为什么在这里，只说这片地方早就封了，继续查下去对谁都没有好处。

A 听见这句话时，反而确定 B 知道更多。不是因为 B 阻止他，而是因为 B 太熟悉这条小路，熟悉到不像偶然经过。
""",
            "word_count": 229,
            "audit_summary": None,
            "source": "imported_source",
            "created_at": APPLE_REFERENCE_NOW,
        },
    },
    {
        "chapter": {
            "id": "chapter_003",
            "novel_id": "novel_001",
            "chapter_no": 3,
            "title": "没进档案的人",
            "status": "completed",
            "target_word_count": 3000,
            "approved_version_id": "draft_003_import_v1",
            "current_version_id": "draft_003_import_v1",
            "canon_version_used": 12,
        },
        "draft": {
            "id": "draft_003_import_v1",
            "chapter_id": "chapter_003",
            "version_no": 1,
            "text": """C 把见面地点定在一间快打烊的便利店。

她没有解释自己为什么现在才出现，只把一只旧录音笔推到 A 面前。录音笔外壳有裂痕，标签上写着旧案日期，字迹已经被磨得发浅。

“当年有个人看见了码头里的事。”C 说，“但那个人没有出现在任何笔录里。”

A 没有立刻碰录音笔。他想起 B 看见旧锁时那一瞬间的沉默，也想起母亲多年前在厨房里突然关掉水龙头的声音。所有线索都还很散，但它们第一次指向同一个方向。
""",
            "word_count": 225,
            "audit_summary": None,
            "source": "imported_source",
            "created_at": APPLE_REFERENCE_NOW,
        },
    },
]

PROMPT_DRAFT = "第4章：A 去旧码头调查，遇到 B，发现 B 对旧案有所隐瞒。C 在结尾出现，给 A 一个关于目击者的新线索。整体气氛冷一点，不要太快揭露真相。"

STRUCTURED_PROMPT = {
    "id": "sp_004",
    "chapter_id": "chapter_004",
    "chapter_goal": "让 A 对 B 的怀疑从模糊变成具体：B 不直接承认，但在旧码头的细节反应中暴露他知道旧案的关键部分。",
    "must_happen": [
        "A 独自抵达旧码头，发现入口处的门锁被换过。",
        "B 出现并试图把 A 带离码头，语气克制，不直接心虚。",
        "A 试探旧案细节，B 对一个不该知道的细节反应过快。",
        "C 在结尾短暂出现，给出“当年还有目击者”的线索。",
    ],
    "must_not_happen": [
        "不要揭露旧案完整真相。",
        "不要新增有姓名角色。",
        "不要让未激活人物出场、回忆、客串或被旁白解释。",
        "不要把旧码头历史写成百科式说明。",
    ],
    "allowed_named_entities": [
        {"name": "A", "activation": "ACTIVE", "mention_budget": None},
        {"name": "B", "activation": "ACTIVE", "mention_budget": None},
        {"name": "C", "activation": "ACTIVE", "mention_budget": None},
        {"name": "旧码头", "activation": "ACTIVE", "mention_budget": None},
        {"name": "旧案", "activation": "ACTIVE", "mention_budget": None},
        {"name": "A 的母亲", "activation": "MENTION_ALLOWED", "mention_budget": 1},
    ],
    "narrative_style": "第三人称有限视角，贴近 A。冷感、克制、少解释。通过动作、停顿和对话错位制造压力。B 的异常要藏在细节里，不要写成明显心虚。",
    "activation_summary": {
        "active_cast": ["A", "B", "C"],
        "allowed_names_count": 6,
        "mention_budget_total": 1,
        "new_named_character_policy": "禁止，除非结构化 Prompt 明确批准",
    },
    "version": 1,
}

AUDIT_SUMMARY = {
    "s0_count": 0,
    "s1_count": 2,
    "s2_count": 1,
    "illegal_named_entity_count": 0,
    "inactive_character_appearance_count": 0,
    "knowledge_violation_count": 0,
    "new_named_entity_count": 0,
    "issues": [
        {
            "id": "audit_s1_001",
            "severity": "S1",
            "type": "暴露略早",
            "location": "第 8-10 段",
            "message": "B 的回避过于直接，可能削弱悬念。",
            "suggestion": "把明显的否认改为更克制的动作和停顿。",
        },
        {
            "id": "audit_s1_002",
            "severity": "S1",
            "type": "背景解释偏重",
            "location": "第 14 段",
            "message": "旧码头历史说明偏多。",
            "suggestion": "压缩为环境细节，避免百科式解释。",
        },
        {
            "id": "audit_s2_001",
            "severity": "S2",
            "type": "句式重复",
            "location": "中段",
            "message": "连续短句较密，节奏略硬。",
            "suggestion": "保留压迫感，同时让句长有一点变化。",
        },
    ],
}

DRAFT_TEXT = """旧码头的铁门比 A 记忆里更窄。雨水顺着门框往下淌，积在门槛前，像一条没有流向的黑线。

他停在门外，没有立刻伸手。

锁被换过。

前三天他来过这里。那时锁孔边缘还有一圈旧锈，像被人反复撬开又重新合上的痕迹。现在那圈锈不见了，新锁贴着门板，干净得突兀。

“你不该来这里。”

B 的声音从身后传来，平稳得几乎没有起伏。

A 没有回头。他看着新锁，问：“你怎么知道我会来？”

B 走到离他三步远的位置，停下。雨水落在他的袖口，颜色慢慢变深。“这里已经封了。谁来都不合适。”

“我问的是，你怎么知道。”

B 没有立刻回答。他的目光落在锁上，又很快移开，像那只是一个不值得停留的细节。

A 在那一瞬间确定，B 见过这把锁，至少知道它为什么会换。

“当年那个人，是从这道门进去的？”

B 抬眼的速度快了一点。

太快了。

手机在这时震了一下。

C 只发来一句话：当年还有一个目击者，没进档案。
"""

REVISED_DRAFT_TEXT = """旧码头的铁门比 A 记忆里更窄。雨水顺着门框往下淌，积在门槛前，像一条没有流向的黑线。

他停在门外，没有立刻伸手。

锁被换过。

“你不该来这里。”

B 的声音从身后传来，平稳得几乎没有起伏。

A 没有回头。他看着新锁，问：“你怎么知道我会来？”

B 走近两步，又停住。“这里已经封了。谁来都不合适。”

“我问的是，你怎么知道。”

B 看了一眼锁。那一眼很短，短到像是被雨声切断。A 没有追问，只把手从锁壳上收回来。

“当年那个人，是从这道门进去的？”

B 抬眼的速度快了一点。

太快了。

C 只发来一句话：当年还有一个目击者，没进档案。
"""

CANON_PATCH = {
    "id": "patch_004",
    "chapter_id": "chapter_004",
    "target_canon_version": 13,
    "items": [
        {
            "id": "patch_memory_001",
            "target": "Memory",
            "title": "新增章节事实",
            "summary": "A 在旧码头发现门锁被更换；B 在与旧案相关的细节上反应异常；C 给出“当年还有目击者”的线索。",
            "proposed_action": "accept",
            "editable_payload": "A 在旧码头发现门锁被更换；B 在与旧案相关的细节上反应异常；C 给出“当年还有目击者”的线索。",
        },
        {
            "id": "patch_character_001",
            "target": "Character",
            "title": "更新 A 的当前状态",
            "summary": "A 对 B 的怀疑从直觉转为有具体证据，但仍不知道旧案真相。",
            "proposed_action": "accept",
            "editable_payload": "A 对 B 的怀疑从直觉转为有具体证据，但仍不知道旧案真相。",
        },
        {
            "id": "patch_knowledge_001",
            "target": "Knowledge",
            "title": "更新 Knowledge Matrix",
            "summary": "A：suspects -> strongly_suspects；读者：hinted；B：knows。旁白仍不能确认旧案完整真相。",
            "proposed_action": "accept",
            "editable_payload": "A：suspects -> strongly_suspects；读者：hinted；B：knows。旁白仍不能确认旧案完整真相。",
        },
        {
            "id": "patch_world_001",
            "target": "WorldBible",
            "title": "补充地点信息",
            "summary": "旧码头入口门锁在第 4 章前被替换；该信息与旧码头状态相关。",
            "proposed_action": "accept",
            "editable_payload": "旧码头入口门锁在第 4 章前被替换；该信息与旧码头状态相关。",
        },
    ],
}

WORLD_BIBLE_SECTIONS = [
    {
        "id": "wb_style",
        "section_key": "style",
        "title": "叙事基调与文风",
        "content": "整体冷静、克制，避免夸张情绪宣泄。环境描写服务于人物心理和现实压力，不做纯景物铺陈。对话要留白，角色不直接说出真实心理。",
        "tags": ["style", "tone"],
        "importance": "high",
        "activation_policy": "always_in_context_brief",
        "canon_version": 12,
        "updated_at": APPLE_REFERENCE_NOW,
    },
    {
        "id": "wb_logic",
        "section_key": "logic",
        "title": "现实逻辑",
        "content": "故事发生在当代城市。人物调查、报警、出入封锁地点都必须符合现实社会规则，不能像游戏任务一样随意推进。",
        "tags": ["realism", "rules"],
        "importance": "critical",
        "activation_policy": "always_considered",
        "canon_version": 12,
        "updated_at": APPLE_REFERENCE_NOW,
    },
]

CHARACTER_CARDS = [
    {
        "id": "char_A",
        "name": "A",
        "aliases": [],
        "role": "主角",
        "stable_traits": ["克制", "不轻易承认恐惧"],
        "current_state": {
            "emotional": "对 B 的怀疑加深。",
            "physical": "左肩受伤未愈。",
            "goal": "确认 B 是否知道旧案关键细节。",
            "summary": "对 B 的怀疑加深，左肩受伤未愈。",
        },
        "dialogue_style": {
            "cadence": "短句，少解释。",
            "taboo": "避免主动袒露脆弱。",
            "summary": "短句，少解释，避免主动袒露脆弱。",
        },
        "knowledge_summary": {"old_case": "suspects", "B_involvement": "suspects"},
        "do_not_auto_mention": False,
        "default_visibility": "active_when_prompted",
        "relationships": [
            {
                "id": "rel_A_B",
                "target_character_name": "B",
                "relationship_summary": "信任破裂但仍有依赖。",
                "current_tension": "A 开始主动试探 B。",
                "last_changed_chapter_no": 3,
            }
        ],
        "forbidden_behavior": ["不能突然全知旧案真相", "不能用长篇独白解释心理"],
        "last_active_chapter_no": 4,
        "canon_version": 12,
    },
    {
        "id": "char_B",
        "name": "B",
        "aliases": [],
        "role": "关键人物",
        "stable_traits": ["善于转移话题", "控制情绪"],
        "current_state": {
            "emotional": "回避旧案追问。",
            "physical": "无明确伤病。",
            "goal": "阻止 A 深查旧码头。",
            "summary": "回避旧案追问，试图阻止 A 深查旧码头。",
        },
        "dialogue_style": {
            "cadence": "平稳、克制。",
            "strategy": "习惯把核心问题转成现实阻碍。",
            "summary": "平稳、克制，习惯把核心问题转成现实阻碍。",
        },
        "knowledge_summary": {"old_case": "partial", "B_involvement": "known"},
        "do_not_auto_mention": False,
        "default_visibility": "active_when_prompted",
        "relationships": [
            {
                "id": "rel_B_A",
                "target_character_name": "A",
                "relationship_summary": "对 A 有隐瞒，不愿完全切断联系。",
                "current_tension": "越阻止越暴露自己知道更多。",
                "last_changed_chapter_no": 3,
            }
        ],
        "forbidden_behavior": ["不能直接承认旧案真相", "不能表现成明显心虚"],
        "last_active_chapter_no": 4,
        "canon_version": 12,
    },
    {
        "id": "char_C",
        "name": "C",
        "aliases": [],
        "role": "线索提供者",
        "stable_traits": ["谨慎", "只给必要信息"],
        "current_state": {
            "emotional": "保持距离。",
            "physical": "无明确伤病。",
            "goal": "把目击者线索交给 A。",
            "summary": "保持距离，只在关键时刻交付线索。",
        },
        "dialogue_style": {
            "cadence": "短促、留白。",
            "strategy": "不解释来龙去脉，只给线索。",
            "summary": "短促、留白，不解释来龙去脉。",
        },
        "knowledge_summary": {"witness": "known", "old_case": "partial"},
        "do_not_auto_mention": False,
        "default_visibility": "active_when_prompted",
        "relationships": [],
        "forbidden_behavior": ["不能提前解释目击者身份", "不能替 A 推理完整真相"],
        "last_active_chapter_no": 4,
        "canon_version": 12,
    },
]

MEMORY_FACTS = [
    {
        "id": "mem_001",
        "chapter_no": 3,
        "fact_type": "event",
        "time_in_story": "第 3 章中段",
        "summary": "A 已经怀疑 B 隐瞒旧案。",
        "participants": ["A", "B"],
        "location": None,
        "evidence": "第 3 章中段",
        "canon_status": "confirmed",
        "canon_version": 12,
        "metadata": {"source": "seed"},
        "created_by": "seed",
    },
    {
        "id": "mem_002",
        "chapter_no": 2,
        "fact_type": "location",
        "time_in_story": "第 2 章结尾",
        "summary": "旧码头被提及为旧案相关地点。",
        "participants": ["A"],
        "location": "旧码头",
        "evidence": "第 2 章结尾",
        "canon_status": "confirmed",
        "canon_version": 12,
        "metadata": {"source": "seed"},
        "created_by": "seed",
    },
]

KNOWLEDGE_MATRIX = [
    {
        "id": "km_001",
        "fact": "B 与旧案有关",
        "fact_title": "B 与旧案有关",
        "truth_status": "confirmed_author_only",
        "author_knowledge": "known",
        "reader_knowledge": "hinted",
        "character_knowledge": [
            {"character_id": "char_A", "character_name": "A", "state": "suspects"},
            {"character_id": "char_B", "character_name": "B", "state": "known"},
            {"character_id": "char_C", "character_name": "C", "state": "unknown"},
        ],
        "visibility": {
            "author": "known",
            "reader": "hinted",
            "char_A": "suspects",
            "char_B": "known",
            "char_C": "unknown",
        },
        "allowed_narration": {
            "mode": "limited_pov",
            "text": "A POV 只能写怀疑和观察，不能确认。",
        },
        "canon_version": 12,
    },
    {
        "id": "km_002",
        "fact": "旧案真正凶手",
        "fact_title": "旧案真正凶手",
        "truth_status": "author_only",
        "author_knowledge": "author_only",
        "reader_knowledge": "reader_unknown",
        "character_knowledge": [
            {"character_id": "char_A", "character_name": "A", "state": "unknown"},
            {"character_id": "char_B", "character_name": "B", "state": "partial"},
        ],
        "visibility": {
            "author": "author_only",
            "reader": "reader_unknown",
            "char_A": "unknown",
            "char_B": "partial",
        },
        "allowed_narration": {
            "mode": "forbidden",
            "text": "本阶段不得写出，不得通过旁白暗示过强。",
        },
        "canon_version": 12,
    },
]
