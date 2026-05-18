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
                            addCurrentKind()
                        } label: {
                            Label(addButtonTitle, systemImage: "plus")
                        }
                        Button("保存修改") {
                            store.saveChanges()
                        }
                        .buttonStyle(.borderedProminent)
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
                    store.addCharacter()
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
                            ForEach(card.relationships) { relation in
                                Text("\(relation.targetCharacterName)：\(relation.relationshipSummary)")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.muted)
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
                    store.addMemoryFact()
                }
            }
            CardBody {
                ForEach($store.memoryFacts) { $fact in
                    ContentBlock("第 \(fact.chapterNo) 章 · \(fact.factType)") {
                        HStack {
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

    private var addButtonTitle: String {
        switch store.selectedBaseDocument {
        case .worldBible: "新增 Section"
        case .characterCards: "新增人物"
        case .memory: "新增事实"
        }
    }

    private func addCurrentKind() {
        switch store.selectedBaseDocument {
        case .worldBible: store.addWorldBibleSection()
        case .characterCards: store.addCharacter()
        case .memory: store.addMemoryFact()
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
}
