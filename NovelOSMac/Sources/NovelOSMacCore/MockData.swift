import Foundation

public enum MockData {
    public static let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    public static let novel = Novel(
        id: "novel_001",
        title: "雨夜旧码头",
        genre: "现实向",
        currentChapterNo: 4,
        currentCanonVersion: 12,
        bootstrapStatus: .completed
    )

    public static let chapter = Chapter(
        id: "chapter_004",
        novelId: "novel_001",
        chapterNo: 4,
        title: "旧码头",
        status: .draftInput,
        targetWordCount: 3000,
        approvedVersionId: nil,
        currentVersionId: nil,
        canonVersionUsed: 12
    )

    public static let promptDraft = "第4章：A 去旧码头调查，遇到 B，发现 B 对旧案有所隐瞒。C 在结尾出现，给 A 一个关于目击者的新线索。整体气氛冷一点，不要太快揭露真相。"

    public static let structuredPrompt = StructuredPrompt(
        id: "sp_004",
        chapterId: "chapter_004",
        chapterGoal: "让 A 对 B 的怀疑从模糊变成具体：B 不直接承认，但在旧码头的细节反应中暴露他知道旧案的关键部分。",
        mustHappen: [
            "A 独自抵达旧码头，发现入口处的门锁被换过。",
            "B 出现并试图把 A 带离码头，语气克制，不直接心虚。",
            "A 试探旧案细节，B 对一个不该知道的细节反应过快。",
            "C 在结尾短暂出现，给出“当年还有目击者”的线索。"
        ],
        mustNotHappen: [
            "不要揭露旧案完整真相。",
            "不要新增有姓名角色。",
            "不要让未激活人物出场、回忆、客串或被旁白解释。",
            "不要把旧码头历史写成百科式说明。"
        ],
        allowedNamedEntities: [
            AllowedEntity(name: "A", activation: .active, mentionBudget: nil),
            AllowedEntity(name: "B", activation: .active, mentionBudget: nil),
            AllowedEntity(name: "C", activation: .active, mentionBudget: nil),
            AllowedEntity(name: "旧码头", activation: .active, mentionBudget: nil),
            AllowedEntity(name: "旧案", activation: .active, mentionBudget: nil),
            AllowedEntity(name: "A 的母亲", activation: .mentionAllowed, mentionBudget: 1)
        ],
        narrativeStyle: "第三人称有限视角，贴近 A。冷感、克制、少解释。通过动作、停顿和对话错位制造压力。B 的异常要藏在细节里，不要写成明显心虚。",
        activationSummary: ActivationSummary(
            activeCast: ["A", "B", "C"],
            allowedNamesCount: 6,
            mentionBudgetTotal: 1,
            newNamedCharacterPolicy: "禁止，除非结构化 Prompt 明确批准"
        ),
        version: 1
    )

    public static let auditSummary = AuditSummary(
        s0Count: 0,
        s1Count: 2,
        s2Count: 1,
        illegalNamedEntityCount: 0,
        inactiveCharacterAppearanceCount: 0,
        knowledgeViolationCount: 0,
        newNamedEntityCount: 0,
        issues: [
            AuditIssue(
                id: "audit_s1_001",
                severity: .s1,
                type: "暴露略早",
                location: "第 8-10 段",
                message: "B 的回避过于直接，可能削弱悬念。",
                suggestion: "把明显的否认改为更克制的动作和停顿。"
            ),
            AuditIssue(
                id: "audit_s1_002",
                severity: .s1,
                type: "背景解释偏重",
                location: "第 14 段",
                message: "旧码头历史说明偏多。",
                suggestion: "压缩为环境细节，避免百科式解释。"
            ),
            AuditIssue(
                id: "audit_s2_001",
                severity: .s2,
                type: "句式重复",
                location: "中段",
                message: "连续短句较密，节奏略硬。",
                suggestion: "保留压迫感，同时让句长有一点变化。"
            )
        ]
    )

    public static let draftText = """
    旧码头的铁门比 A 记忆里更窄。雨水顺着门框往下淌，积在门槛前，像一条没有流向的黑线。

    他停在门外，没有立刻伸手。

    锁被换过。

    前三天他来过这里。那时锁孔边缘还有一圈旧锈，像被人反复撬开又重新合上的痕迹。现在那圈锈不见了，新锁贴着门板，干净得突兀。

    A 把伞往肩后一压，指尖碰到冰冷的锁壳。雨声把码头另一侧的水声压得很低，低到像某种藏在墙后的呼吸。

    “你不该来这里。”

    B 的声音从身后传来，平稳得几乎没有起伏。

    A 没有回头。他看着新锁，问：“你怎么知道我会来？”

    B 走到离他三步远的位置，停下。雨水落在他的袖口，颜色慢慢变深。“这里已经封了。谁来都不合适。”

    “我问的是，你怎么知道。”

    B 没有立刻回答。他的目光落在锁上，又很快移开，像那只是一个不值得停留的细节。

    A 在那一瞬间确定，B 见过这把锁，至少知道它为什么会换。

    他把手收回，掌心留下一点铁锈没有留下的冷意。“当年那个人，是从这道门进去的？”

    B 抬眼的速度快了一点。

    太快了。

    A 低下头，像只是确认雨水没有浸湿鞋面。他没有追问，也没有把那个反应点破。旧码头后方的仓库在雨里沉着，窗洞黑得像闭上的眼。

    手机在这时震了一下。

    C 只发来一句话：当年还有一个目击者，没进档案。
    """

    public static let draft = Draft(
        id: "draft_004_v3",
        chapterId: "chapter_004",
        versionNo: 3,
        text: draftText,
        wordCount: 3120,
        auditSummary: auditSummary,
        createdAt: now
    )

    public static let revisedDraftText = """
    旧码头的铁门比 A 记忆里更窄。雨水顺着门框往下淌，积在门槛前，像一条没有流向的黑线。

    他停在门外，没有立刻伸手。

    锁被换过。

    前三天他来过这里。那时锁孔边缘还有一圈旧锈。现在那圈锈不见了，新锁贴着门板，干净得突兀。

    “你不该来这里。”

    B 的声音从身后传来，平稳得几乎没有起伏。

    A 没有回头。他看着新锁，问：“你怎么知道我会来？”

    B 走近两步，又停住。“这里已经封了。谁来都不合适。”

    “我问的是，你怎么知道。”

    B 看了一眼锁。那一眼很短，短到像是被雨声切断。A 没有追问，只把手从锁壳上收回来。

    “当年那个人，是从这道门进去的？”

    B 抬眼的速度快了一点。

    太快了。

    A 没有把那个反应点破。旧码头后方的仓库在雨里沉着，窗洞黑得像闭上的眼。

    手机在这时震了一下。

    C 只发来一句话：当年还有一个目击者，没进档案。
    """

    public static let canonPatch = CanonUpdatePatch(
        id: "patch_004",
        chapterId: "chapter_004",
        targetCanonVersion: 13,
        items: [
            CanonPatchItem(
                id: "patch_memory_001",
                target: .memory,
                title: "新增章节事实",
                summary: "A 在旧码头发现门锁被更换；B 在与旧案相关的细节上反应异常；C 给出“当年还有目击者”的线索。",
                proposedAction: .accept,
                editablePayload: "A 在旧码头发现门锁被更换；B 在与旧案相关的细节上反应异常；C 给出“当年还有目击者”的线索。"
            ),
            CanonPatchItem(
                id: "patch_character_001",
                target: .character,
                title: "更新 A 的当前状态",
                summary: "A 对 B 的怀疑从直觉转为有具体证据，但仍不知道旧案真相。",
                proposedAction: .accept,
                editablePayload: "A 对 B 的怀疑从直觉转为有具体证据，但仍不知道旧案真相。"
            ),
            CanonPatchItem(
                id: "patch_knowledge_001",
                target: .knowledge,
                title: "更新 Knowledge Matrix",
                summary: "A：suspects -> strongly_suspects；读者：hinted；B：knows。旁白仍不能确认旧案完整真相。",
                proposedAction: .accept,
                editablePayload: "A：suspects -> strongly_suspects；读者：hinted；B：knows。旁白仍不能确认旧案完整真相。"
            ),
            CanonPatchItem(
                id: "patch_world_001",
                target: .worldBible,
                title: "补充地点信息",
                summary: "旧码头入口门锁在第 4 章前被替换；该信息与旧码头状态相关。",
                proposedAction: .accept,
                editablePayload: "旧码头入口门锁在第 4 章前被替换；该信息与旧码头状态相关。"
            )
        ]
    )

    public static let worldBibleSections: [WorldBibleSection] = [
        WorldBibleSection(
            id: "wb_style",
            title: "叙事基调与文风",
            content: "整体冷静、克制，避免夸张情绪宣泄。环境描写服务于人物心理和现实压力，不做纯景物铺陈。对话要留白，角色不直接说出真实心理。",
            tags: ["style", "tone"],
            importance: .high,
            activationPolicy: .alwaysInContextBrief,
            canonVersion: 12,
            updatedAt: now
        ),
        WorldBibleSection(
            id: "wb_logic",
            title: "现实逻辑",
            content: "故事发生在当代城市。人物调查、报警、出入封锁地点都必须符合现实社会规则，不能像游戏任务一样随意推进。",
            tags: ["realism", "rules"],
            importance: .critical,
            activationPolicy: .alwaysConsidered,
            canonVersion: 12,
            updatedAt: now
        ),
        WorldBibleSection(
            id: "wb_misc",
            title: "不知道放哪但很重要",
            content: "旧码头不是超自然地点，它的压迫感来自过往事件、封闭空间和人物隐瞒。不要把它写成神秘学场景。",
            tags: ["old-dock"],
            importance: .medium,
            activationPolicy: .tagMatched,
            canonVersion: 12,
            updatedAt: now
        )
    ]

    public static let characterCards: [CharacterCard] = [
        CharacterCard(
            id: "char_A",
            name: "A",
            aliases: [],
            role: "主角",
            stableTraits: ["克制", "不轻易承认恐惧"],
            currentState: "对 B 的怀疑加深，左肩受伤未愈。",
            dialogueStyle: "短句，少解释，避免主动袒露脆弱。",
            relationships: [
                CharacterRelationship(id: "rel_A_B", targetCharacterName: "B", relationshipSummary: "信任破裂但仍有依赖。", currentTension: "A 开始主动试探 B。", lastChangedChapterNo: 3)
            ],
            forbiddenBehavior: ["不能突然全知旧案真相", "不能用长篇独白解释心理"],
            lastActiveChapterNo: 4,
            canonVersion: 12
        ),
        CharacterCard(
            id: "char_B",
            name: "B",
            aliases: [],
            role: "关键人物",
            stableTraits: ["善于转移话题", "控制情绪"],
            currentState: "回避旧案追问，试图阻止 A 深查旧码头。",
            dialogueStyle: "平稳、克制，习惯把核心问题转成现实阻碍。",
            relationships: [
                CharacterRelationship(id: "rel_B_A", targetCharacterName: "A", relationshipSummary: "对 A 有隐瞒，不愿完全切断联系。", currentTension: "越阻止越暴露自己知道更多。", lastChangedChapterNo: 3)
            ],
            forbiddenBehavior: ["不能直接承认旧案真相", "不能表现成明显心虚"],
            lastActiveChapterNo: 4,
            canonVersion: 12
        ),
        CharacterCard(
            id: "char_C",
            name: "C",
            aliases: [],
            role: "配角",
            stableTraits: ["直接", "只关心结果"],
            currentState: "掌握目击者线索。",
            dialogueStyle: "信息密度高，少寒暄。",
            relationships: [
                CharacterRelationship(id: "rel_C_A", targetCharacterName: "A", relationshipSummary: "暂时合作，不展开背景。", currentTension: nil, lastChangedChapterNo: 4)
            ],
            forbiddenBehavior: ["不能在第 4 章展开个人支线"],
            lastActiveChapterNo: 4,
            canonVersion: 12
        )
    ]

    public static let memoryFacts: [MemoryFact] = [
        MemoryFact(
            id: "mem_001",
            chapterNo: 3,
            factType: "event",
            summary: "A 已经怀疑 B 隐瞒旧案。",
            participants: ["A", "B"],
            location: nil,
            evidence: "第 3 章中段",
            canonStatus: "confirmed",
            canonVersion: 12
        ),
        MemoryFact(
            id: "mem_002",
            chapterNo: 2,
            factType: "location",
            summary: "旧码头被提及为旧案相关地点。",
            participants: ["A"],
            location: "旧码头",
            evidence: "第 2 章结尾",
            canonStatus: "confirmed",
            canonVersion: 12
        )
    ]

    public static let knowledgeEntries: [KnowledgeMatrixEntry] = [
        KnowledgeMatrixEntry(
            id: "km_001",
            factTitle: "B 与旧案有关",
            truthStatus: "confirmed_author_only",
            authorKnowledge: .known,
            readerKnowledge: .hinted,
            characterKnowledge: [
                CharacterKnowledge(characterId: "char_A", characterName: "A", state: .suspects),
                CharacterKnowledge(characterId: "char_B", characterName: "B", state: .known),
                CharacterKnowledge(characterId: "char_C", characterName: "C", state: .unknown)
            ],
            allowedNarration: "A POV 只能写怀疑和观察，不能确认。",
            canonVersion: 12
        ),
        KnowledgeMatrixEntry(
            id: "km_002",
            factTitle: "旧案真正凶手",
            truthStatus: "author_only",
            authorKnowledge: .authorOnly,
            readerKnowledge: .readerUnknown,
            characterKnowledge: [
                CharacterKnowledge(characterId: "char_A", characterName: "A", state: .unknown),
                CharacterKnowledge(characterId: "char_B", characterName: "B", state: .partial),
                CharacterKnowledge(characterId: "char_C", characterName: "C", state: .unknown)
            ],
            allowedNarration: "本阶段不得写出，不得通过旁白暗示过强。",
            canonVersion: 12
        ),
        KnowledgeMatrixEntry(
            id: "km_003",
            factTitle: "当年还有一个目击者",
            truthStatus: "chapter_4_reveal",
            authorKnowledge: .known,
            readerKnowledge: .readerKnown,
            characterKnowledge: [
                CharacterKnowledge(characterId: "char_A", characterName: "A", state: .known),
                CharacterKnowledge(characterId: "char_B", characterName: "B", state: .mayKnow),
                CharacterKnowledge(characterId: "char_C", characterName: "C", state: .known)
            ],
            allowedNarration: "第 5 章可以作为调查方向，但不能直接给身份。",
            canonVersion: 12
        )
    ]

    public static let contextPackJSON = """
    {
      "chapter_no": 4,
      "allowed_named_entities": ["A", "B", "C", "旧码头", "旧案", "A 的母亲"],
      "active_entities": ["A", "B", "C"],
      "mention_allowed_entities": [
        { "name": "A 的母亲", "budget": 1, "form": "brief_memory" }
      ],
      "new_entity_policy": "allow_minor_unnamed_only",
      "knowledge_limits": [
        "A cannot know the full truth of the old case",
        "Narration cannot confirm B's full involvement"
      ]
    }
    """

    public static let agentRuns: [AgentRun] = [
        AgentRun(id: "run_001", agentName: "章节意图识别", summary: "识别 A/B/C、旧码头、旧案、冷感基调。", status: "pass", timestampLabel: "12:01"),
        AgentRun(id: "run_002", agentName: "上下文整理", summary: "整理本章可用专名，排除无关人物。", status: "pass", timestampLabel: "12:02"),
        AgentRun(id: "run_003", agentName: "章节指令整理", summary: "生成结构化 Prompt。", status: "user approved", timestampLabel: "12:04"),
        AgentRun(id: "run_004", agentName: "正文检查", summary: "S0=0，S1=2，S2=1。", status: "suggest", timestampLabel: "12:10")
    ]

    public static let chapterVersions: [ChapterVersionSnapshot] = [
        ChapterVersionSnapshot(
            id: "version_draft_001",
            chapterId: "chapter_004",
            versionNo: 1,
            kind: "draft",
            status: "archived",
            wordCount: 3280,
            auditSummary: AuditSummary(
                s0Count: 0,
                s1Count: 3,
                s2Count: 2,
                illegalNamedEntityCount: 0,
                inactiveCharacterAppearanceCount: 0,
                knowledgeViolationCount: 0,
                newNamedEntityCount: 0,
                issues: []
            ),
            note: "初稿，旧码头背景解释偏多。",
            createdAtLabel: "12:08"
        ),
        ChapterVersionSnapshot(
            id: "version_draft_002",
            chapterId: "chapter_004",
            versionNo: 2,
            kind: "mock revision",
            status: "archived",
            wordCount: 3180,
            auditSummary: AuditSummary(
                s0Count: 0,
                s1Count: 2,
                s2Count: 1,
                illegalNamedEntityCount: 0,
                inactiveCharacterAppearanceCount: 0,
                knowledgeViolationCount: 0,
                newNamedEntityCount: 0,
                issues: []
            ),
            note: "按意见压缩背景，保留 B 的异常反应。",
            createdAtLabel: "12:13"
        ),
        ChapterVersionSnapshot(
            id: "version_final_003",
            chapterId: "chapter_004",
            versionNo: 3,
            kind: "final",
            status: "approved_final",
            wordCount: 3120,
            auditSummary: auditSummary,
            note: "当前批准候选版本，Canon Patch 待确认。",
            createdAtLabel: "12:18"
        )
    ]

    public static func debugExportPayload(
        chapter: Chapter = MockData.chapter,
        exportedAt: Date = MockData.now
    ) -> DebugExportPayload {
        DebugExportPayload(
            exportedAt: exportedAt,
            novel: novel,
            chapter: chapter,
            contextPackJSON: contextPackJSON,
            agentRuns: agentRuns,
            chapterVersions: chapterVersions
        )
    }
}
