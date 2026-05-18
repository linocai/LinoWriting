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
                        Button("保存修改") {
                            Task {
                                await store.saveChanges()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(store.isSaving)
                    }
                }

                if let message = store.statusMessage {
                    Text(message)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(AppTheme.green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppTheme.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                if store.isLoading || store.isSaving || store.isIndexing {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(store.isIndexing ? "后台 reindex 中" : "同步基础文件中")
                            .font(.callout)
                            .foregroundStyle(AppTheme.muted)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.surfaceAlt.opacity(0.5), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(BaseDocumentKind.allCases) { kind in
                            Button {
                                store.selectedBaseDocument = kind
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(kind.title)
                                        .font(.headline)
                                    Text(kind.summary)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.muted)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    store.selectedBaseDocument == kind ? AppTheme.blue.opacity(0.1) : AppTheme.surface,
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                )
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(store.selectedBaseDocument == kind ? AppTheme.blue.opacity(0.55) : AppTheme.border))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(width: 240)

                    selectedDocumentView
                }
            }
            .padding(22)
        }
        .background(AppTheme.background)
        .task {
            await store.loadDocuments()
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
                    ContentBlock(section.title.isEmpty ? "未命名 Section" : section.title) {
                        HStack {
                            Spacer()
                            Button(role: .destructive) {
                                Task {
                                    await store.deleteWorldBibleSection(id: section.id)
                                }
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                        TextField("Section 标题", text: $section.title)
                            .textFieldStyle(.roundedBorder)
                        TextEditor(text: $section.content)
                            .frame(minHeight: 110)
                            .padding(8)
                            .background(AppTheme.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border))
                        HStack {
                            Picker("重要性", selection: $section.importance) {
                                ForEach(ImportanceLevel.allCases) { level in
                                    Text(level.rawValue).tag(level)
                                }
                            }
                            Picker("激活策略", selection: $section.activationPolicy) {
                                ForEach(ActivationPolicy.allCases) { policy in
                                    Text(policy.rawValue).tag(policy)
                                }
                            }
                        }
                        TextField("Tags，用逗号分隔", text: tagsBinding(for: $section))
                            .textFieldStyle(.roundedBorder)
                    }
                }

                ContentBlock("不要让用户管理向量") {
                    Text("保存 Section 时后台自动 reindex；第一轮 Mock 只显示“已保存 / 已索引”的状态。")
                        .font(.callout)
                        .foregroundStyle(AppTheme.muted)
                }
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
            }
            CardBody {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12, alignment: .top)], alignment: .leading, spacing: 12) {
                    ForEach($store.characterCards) { $card in
                        ContentBlock(card.name) {
                            TextField("姓名", text: $card.name)
                                .textFieldStyle(.roundedBorder)
                            TextField("角色", text: $card.role)
                                .textFieldStyle(.roundedBorder)
                            Text("稳定人格")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.muted)
                            TextEditor(text: stringArrayBinding($card.stableTraits))
                                .frame(minHeight: 68)
                            Text("当前状态")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.muted)
                            TextEditor(text: $card.currentState)
                                .frame(minHeight: 68)
                            Text("人物关系")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.muted)
                            ForEach($card.relationships) { $relation in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        TextField("关联人物", text: $relation.targetCharacterName)
                                            .textFieldStyle(.roundedBorder)
                                        TextField("紧张关系", text: Binding {
                                            relation.currentTension ?? ""
                                        } set: { relation.currentTension = $0.isEmpty ? nil : $0 })
                                        .textFieldStyle(.roundedBorder)
                                    }
                                    TextEditor(text: $relation.relationshipSummary)
                                        .frame(minHeight: 54)
                                        .padding(6)
                                        .background(AppTheme.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border))
                                }
                            }
                            Button {
                                store.addRelationship(to: card.id)
                            } label: {
                                Label("新增关系", systemImage: "plus")
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
            }
            CardBody {
                HStack {
                    TextField("按章节号筛选", text: $store.memoryChapterFilter)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 180)
                    Text("当前显示 \(store.filteredMemoryFacts.count) 条")
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                    Spacer()
                }
                ForEach($store.memoryFacts) { $fact in
                    if memoryFactVisible(fact) {
                        ContentBlock("第 \(fact.chapterNo) 章 · \(fact.factType)") {
                            HStack {
                                Spacer()
                                Button(role: .destructive) {
                                    Task {
                                        await store.deleteMemoryFact(id: fact.id)
                                    }
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                            HStack {
                                Stepper("第 \(fact.chapterNo) 章", value: $fact.chapterNo, in: 1...999)
                                TextField("类型", text: $fact.factType)
                                    .textFieldStyle(.roundedBorder)
                                TextField("地点", text: Binding {
                                    fact.location ?? ""
                                } set: { fact.location = $0.isEmpty ? nil : $0 })
                                .textFieldStyle(.roundedBorder)
                            }
                            TextEditor(text: $fact.summary)
                                .frame(minHeight: 82)
                                .padding(8)
                                .background(AppTheme.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border))
                            HStack {
                                TextField("参与人物，用逗号分隔", text: stringArrayCommaBinding($fact.participants))
                                    .textFieldStyle(.roundedBorder)
                                TextField("证据", text: $fact.evidence)
                                    .textFieldStyle(.roundedBorder)
                                TextField("状态", text: $fact.canonStatus)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                    }
                }
            }
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
}
