import NovelOSMacCore
import SwiftUI

struct BaseFilesView: View {
    @Environment(BaseDocumentsStore.self) private var store
    @Environment(ChapterWorkflowStore.self) private var chapterStore

    var body: some View {
        @Bindable var store = store

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                TopBarView(kicker: "基础文件 · 可手动编辑", title: "World Bible、人物卡、Memory 是可编辑资产") {
                    HStack(spacing: 10) {
                        Button {
                            Task {
                                await addCurrentKind()
                            }
                        } label: {
                            Label(addButtonTitle, systemImage: "plus")
                        }
                        .buttonStyle(GhostButtonStyle())
                        Button("保存修改") {
                            Task {
                                await store.saveChanges()
                            }
                        }
                        .buttonStyle(BlueButtonStyle())
                        .disabled(store.isSaving)
                    }
                }

                if let message = store.statusMessage {
                    StatusBanner(message: message, tone: .green)
                }

                if store.isLoading || store.isSaving || store.isIndexing {
                    StatusBanner(message: store.isIndexing ? "正在更新索引" : "同步基础文件中", tone: .blue)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        baseDocumentSelector
                            .frame(width: 280)
                        selectedDocumentView
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        baseDocumentSelector
                        selectedDocumentView
                    }
                }
            }
            .padding(AppTheme.pagePadding)
        }
        .background(AppBackgroundView())
        .task {
            await store.loadDocuments()
        }
    }

    private var baseDocumentSelector: some View {
        @Bindable var store = store

        return CardView {
            CardBody {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(BaseDocumentKind.allCases) { kind in
                        BaseDocumentNavItem(
                            kind: kind,
                            isSelected: store.selectedBaseDocument == kind
                        ) {
                            store.selectedBaseDocument = kind
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var selectedDocumentView: some View {
        switch store.selectedBaseDocument {
        case .worldBible:
            worldBibleEditor
        case .characterCards:
            characterCardsEditor
        case .memory:
            memoryEditor
        }
    }

    private var worldBibleEditor: some View {
        @Bindable var store = store

        return CardView {
            CardHeader(
                title: "World Bible 编辑器",
                subtitle: "不是纯世界观规则，而是整本书的总 Bible。Style 内容也放在这里。"
            ) {
                PillView(text: "Canon v\(chapterStore.novel.currentCanonVersion ?? 12)", tone: .purple)
            }
            CardBody {
                ForEach($store.worldBibleSections) { $section in
                    PromptCard(title: section.title.isEmpty ? "未命名 Section" : section.title, badge: section.importance.displayName, tone: importanceTone(section.importance)) {
                        HStack {
                            Spacer()
                            Button(role: .destructive) {
                                Task {
                                    await store.deleteWorldBibleSection(id: section.id)
                                }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(DangerButtonStyle())
                        }
                        LabeledField("Section 标题") {
                            SoftTextField(title: "Section 标题", text: $section.title)
                        }
                        LabeledField("内容") {
                            SoftTextEditor(text: $section.content, minHeight: 120)
                        }
                        HStack(alignment: .top, spacing: 12) {
                            LabeledField("重要性") {
                                SoftPicker("重要性", selection: $section.importance) {
                                    ForEach(ImportanceLevel.allCases) { level in
                                        Text(level.displayName).tag(level)
                                    }
                                }
                            }
                            LabeledField("激活策略") {
                                SoftPicker("激活策略", selection: $section.activationPolicy) {
                                    ForEach(ActivationPolicy.allCases) { policy in
                                        Text(policy.displayName).tag(policy)
                                    }
                                }
                            }
                        }
                        LabeledField("Tags", hint: "逗号分隔，下面会预览") {
                            SoftTextField(title: "Tags，用逗号分隔", text: tagsBinding(for: $section))
                        }
                        FlowLayout {
                            ForEach(section.tags, id: \.self) { tag in
                                EntityChip(text: tag, tone: .blue)
                            }
                        }
                        HStack {
                            PillView(text: "Canon v\(section.canonVersion)", tone: .purple)
                            PillView(text: section.updatedAt.formatted(date: .abbreviated, time: .shortened), tone: .neutral)
                        }
                    }
                }

                StatusBanner(message: "保存后会自动更新检索索引；完成后显示已保存状态。", tone: .blue)
            }
        }
    }

    private var characterCardsEditor: some View {
        @Bindable var store = store

        return CardView {
            CardHeader(
                title: "人物卡编辑",
                subtitle: "人物关系合并在人物卡里，不单独做 Relationship Graph。"
            ) {
                Button("新增人物") {
                    Task {
                        await store.addCharacter()
                    }
                }
                .buttonStyle(GhostButtonStyle())
            }
            CardBody {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 360), spacing: 12, alignment: .top)], alignment: .leading, spacing: 12) {
                    ForEach($store.characterCards) { $card in
                        PromptCard(title: card.name, badge: card.role, tone: .orange) {
                            HStack {
                                PillView(text: "Canon v\(card.canonVersion)", tone: .purple)
                                if let chapterNo = card.lastActiveChapterNo {
                                    PillView(text: "上次出场：第 \(chapterNo) 章", tone: .blue)
                                }
                                Spacer()
                            }

                            LabeledField("姓名") {
                                SoftTextField(title: "姓名", text: $card.name)
                            }
                            LabeledField("别名", hint: "逗号分隔") {
                                SoftTextField(title: "别名", text: stringArrayCommaBinding($card.aliases))
                            }
                            LabeledField("角色") {
                                SoftTextField(title: "角色", text: $card.role)
                            }
                            LabeledField("稳定人格") {
                                SoftTextEditor(text: stringArrayBinding($card.stableTraits), minHeight: 74)
                            }
                            LabeledField("当前状态") {
                                SoftTextEditor(text: $card.currentState, minHeight: 74)
                            }
                            LabeledField("说话方式") {
                                SoftTextEditor(text: $card.dialogueStyle, minHeight: 74)
                            }
                            LabeledField("禁止行为") {
                                SoftTextEditor(text: stringArrayBinding($card.forbiddenBehavior), minHeight: 74)
                            }
                            LabeledField("上次出场章节") {
                                SoftTextField(title: "例如 4", text: optionalIntBinding($card.lastActiveChapterNo))
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("人物关系")
                                        .font(.headline.weight(.bold))
                                    Spacer()
                                    Button {
                                        store.addRelationship(to: card.id)
                                    } label: {
                                        Label("新增关系", systemImage: "plus")
                                    }
                                    .buttonStyle(GhostButtonStyle())
                                }

                                ForEach($card.relationships) { $relation in
                                    ContentBlock(tone: .neutral) {
                                        LabeledField("目标人物") {
                                            SoftTextField(title: "关联人物", text: $relation.targetCharacterName)
                                        }
                                        LabeledField("关系摘要") {
                                            SoftTextEditor(text: $relation.relationshipSummary, minHeight: 58)
                                        }
                                        HStack(alignment: .top, spacing: 10) {
                                            LabeledField("当前张力") {
                                                SoftTextField(title: "紧张关系", text: optionalStringBinding($relation.currentTension))
                                            }
                                            LabeledField("上次变化章节") {
                                                SoftTextField(title: "章节号", text: optionalIntBinding($relation.lastChangedChapterNo))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var memoryEditor: some View {
        @Bindable var store = store

        return CardView {
            CardHeader(
                title: "Memory / Chapter Facts",
                subtitle: "记录已经发生的故事历史，支持手动修订。"
            ) {
                Button("新增事实") {
                    Task {
                        await store.addMemoryFact()
                    }
                }
                .buttonStyle(GhostButtonStyle())
            }
            CardBody {
                HStack {
                    SoftTextField(title: "按章节号筛选", text: $store.memoryChapterFilter)
                        .frame(maxWidth: 180)
                    PillView(text: "当前显示 \(store.filteredMemoryFacts.count) 条", tone: .neutral)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 10) {
                    ForEach($store.memoryFacts) { $fact in
                        if memoryFactVisible(fact) {
                            memoryFactView($fact)
                        }
                    }
                }
            }
        }
    }

    private func memoryFactView(_ fact: Binding<MemoryFact>) -> some View {
        TimelineItemView(
            badge: "第 \(fact.wrappedValue.chapterNo) 章",
            title: fact.wrappedValue.factType,
            subtitle: fact.wrappedValue.summary.isEmpty ? "待补充事实摘要" : fact.wrappedValue.summary,
            tone: .blue
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Stepper("第 \(fact.wrappedValue.chapterNo) 章", value: fact.chapterNo, in: 1...999)
                        .font(.callout.weight(.semibold))
                    LabeledField("类型") {
                        SoftTextField(title: "类型", text: fact.factType)
                    }
                    LabeledField("地点") {
                        SoftTextField(title: "地点", text: optionalStringBinding(fact.location))
                    }
                }
                LabeledField("事实摘要") {
                    SoftTextEditor(text: fact.summary, minHeight: 82)
                }
                HStack(alignment: .top, spacing: 10) {
                    LabeledField("参与人物") {
                        SoftTextField(title: "A, B, C", text: stringArrayCommaBinding(fact.participants))
                    }
                    LabeledField("证据") {
                        SoftTextField(title: "证据", text: fact.evidence)
                    }
                    LabeledField("Canon 状态") {
                        SoftTextField(title: "confirmed", text: fact.canonStatus)
                    }
                }
                FlowLayout {
                    ForEach(fact.wrappedValue.participants, id: \.self) { name in
                        EntityChip(text: name, tone: .green)
                    }
                    if let location = fact.wrappedValue.location, !location.isEmpty {
                        EntityChip(text: location, tone: .blue)
                    }
                    EntityChip(text: fact.wrappedValue.canonStatus, tone: .purple)
                }
            }
        } trailing: {
            Button(role: .destructive) {
                Task {
                    await store.deleteMemoryFact(id: fact.wrappedValue.id)
                }
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(DangerButtonStyle())
        }
    }

    private func memoryFactVisible(_ fact: MemoryFact) -> Bool {
        let filter = store.memoryChapterFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !filter.isEmpty, let chapterNo = Int(filter) else {
            return true
        }
        return fact.chapterNo == chapterNo
    }

    private var addButtonTitle: String {
        switch store.selectedBaseDocument {
        case .worldBible: "新增 Section"
        case .characterCards: "新增人物"
        case .memory: "新增事实"
        }
    }

    private func addCurrentKind() async {
        switch store.selectedBaseDocument {
        case .worldBible:
            await store.addWorldBibleSection()
        case .characterCards:
            await store.addCharacter()
        case .memory:
            await store.addMemoryFact()
        }
    }

    private func importanceTone(_ level: ImportanceLevel) -> PillTone {
        switch level {
        case .low: .neutral
        case .medium: .blue
        case .high: .orange
        case .critical: .red
        }
    }

    private func tagsBinding(for section: Binding<WorldBibleSection>) -> Binding<String> {
        Binding {
            section.wrappedValue.tags.joined(separator: ", ")
        } set: { value in
            section.wrappedValue.tags = value
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
    }

    private func stringArrayBinding(_ values: Binding<[String]>) -> Binding<String> {
        Binding {
            values.wrappedValue.joined(separator: "\n")
        } set: { value in
            values.wrappedValue = value.linesFromEditor
        }
    }

    private func stringArrayCommaBinding(_ values: Binding<[String]>) -> Binding<String> {
        Binding {
            values.wrappedValue.joined(separator: ", ")
        } set: { value in
            values.wrappedValue = value
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
    }

    private func optionalStringBinding(_ value: Binding<String?>) -> Binding<String> {
        Binding {
            value.wrappedValue ?? ""
        } set: { newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            value.wrappedValue = trimmed.isEmpty ? nil : trimmed
        }
    }

    private func optionalIntBinding(_ value: Binding<Int?>) -> Binding<String> {
        Binding {
            value.wrappedValue.map(String.init) ?? ""
        } set: { newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            value.wrappedValue = Int(trimmed)
        }
    }
}

private struct BaseDocumentNavItem: View {
    let kind: BaseDocumentKind
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(kind.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                Text(kind.summary)
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? AppTheme.blue.opacity(0.10) : Color.white.opacity(isHovered ? 0.72 : 0.54),
                in: RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous)
                    .stroke(isSelected ? AppTheme.blue.opacity(0.50) : Color.white.opacity(0.76), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
