import NovelOSMacCore
import SwiftUI

struct KnowledgeMatrixView: View {
    @Environment(KnowledgeMatrixStore.self) private var store

    var body: some View {
        @Bindable var store = store

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                TopBarView(kicker: "知识矩阵 · 防穿帮", title: "谁知道什么，比发生过什么更重要") {
                    HStack(spacing: 10) {
                        Button {
                            Task {
                                await store.addEntry()
                            }
                        } label: {
                            Label("新增知识条目", systemImage: "plus")
                        }
                        Button("保存矩阵") {
                            Task {
                                await store.saveMatrix()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(store.isSaving)
                    }
                }

                HStack(spacing: 12) {
                    TextField("筛选事实、限制或真相状态", text: $store.filterText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 360)
                    Picker("角色", selection: $store.selectedCharacterName) {
                        Text("全部角色").tag(String?.none)
                        ForEach(store.characterFilterOptions, id: \.self) { name in
                            Text(name).tag(String?.some(name))
                        }
                    }
                    .frame(width: 180)
                    Picker("状态", selection: $store.selectedState) {
                        Text("全部状态").tag(KnowledgeState?.none)
                        ForEach(KnowledgeState.allCases) { state in
                            Text(state.rawValue).tag(KnowledgeState?.some(state))
                        }
                    }
                    .frame(width: 220)
                    Spacer()
                    PillView(text: "防止开天眼", tone: .red)
                }

                if let message = store.statusMessage {
                    Text(message)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(AppTheme.green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppTheme.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                if store.isLoading || store.isSaving {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(store.isLoading ? "加载知识矩阵中" : "保存知识矩阵中")
                            .font(.callout)
                            .foregroundStyle(AppTheme.muted)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.surfaceAlt.opacity(0.5), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                CardView {
                    CardHeader(
                        title: "知识矩阵",
                        subtitle: "按作者、读者和角色分别记录可知信息，避免正文提前泄露真相。"
                    )
                    CardBody {
                        ScrollView(.horizontal) {
                            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
                                GridRow {
                                    matrixHeader("事实 / 秘密", width: 220)
                                    matrixHeader("作者", width: 110)
                                    matrixHeader("读者", width: 120)
                                    ForEach(store.visibleCharacters, id: \.self) { name in
                                        matrixHeader(name, width: 110)
                                    }
                                    matrixHeader("允许叙述", width: 320)
                                }
                                Divider()
                                    .gridCellColumns(6 + store.visibleCharacters.count)

                                ForEach(store.filteredEntries) { entry in
                                    GridRow(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            TextField("事实", text: factTitleBinding(entry.id))
                                                .textFieldStyle(.roundedBorder)
                                                .frame(width: 220)
                                            TextField("真相状态", text: truthStatusBinding(entry.id))
                                                .textFieldStyle(.roundedBorder)
                                                .frame(width: 220)
                                        }
                                        statePicker(authorKnowledgeBinding(entry.id), width: 130)
                                        statePicker(readerKnowledgeBinding(entry.id), width: 130)
                                        ForEach(store.visibleCharacters, id: \.self) { name in
                                            statePicker(characterStateBinding(entry.id, characterName: name), width: 130)
                                        }
                                        HStack(alignment: .top, spacing: 8) {
                                            TextField("允许叙述", text: allowedNarrationBinding(entry.id), axis: .vertical)
                                                .textFieldStyle(.roundedBorder)
                                                .frame(width: 320)
                                            Button(role: .destructive) {
                                                Task {
                                                    await store.deleteEntry(id: entry.id)
                                                }
                                            } label: {
                                                Image(systemName: "trash")
                                            }
                                            .buttonStyle(.borderless)
                                        }
                                    }
                                    Divider().gridCellColumns(6 + store.visibleCharacters.count)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 12, alignment: .top)], alignment: .leading, spacing: 12) {
                    ContentBlock("使用方式") {
                        Text("用表格记录每条事实对作者、读者和角色的可见状态，方便检查叙事视角。")
                            .font(.callout)
                            .foregroundStyle(AppTheme.muted)
                    }
                    ContentBlock("章节写作") {
                        Text("每章只会带入相关限制，当前页面负责维护完整矩阵。")
                            .font(.callout)
                            .foregroundStyle(AppTheme.muted)
                    }
                    ContentBlock("筛选建议") {
                        Text("允许按角色和状态筛选：只看 A 知道什么、B 隐瞒什么、读者已经知道什么。")
                            .font(.callout)
                            .foregroundStyle(AppTheme.muted)
                    }
                }
            }
            .padding(22)
        }
        .background(AppTheme.background)
        .task {
            await store.loadEntries()
        }
    }

    private func matrixHeader(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(AppTheme.muted)
            .frame(width: width, alignment: .leading)
    }

    private func statePicker(_ selection: Binding<KnowledgeState>, width: CGFloat) -> some View {
        Picker("", selection: selection) {
            ForEach(KnowledgeState.allCases) { state in
                Text(state.rawValue).tag(state)
            }
        }
        .labelsHidden()
        .frame(width: width)
        .background(tone(for: selection.wrappedValue).color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func tone(for state: KnowledgeState) -> PillTone {
        switch state {
        case .known, .readerKnown, .stronglySuspects: .green
        case .suspects, .hinted, .partial, .mayKnow: .orange
        case .authorOnly: .purple
        case .unknown, .readerUnknown: .neutral
        }
    }

    private func factTitleBinding(_ id: String) -> Binding<String> {
        Binding {
            store.entries.first(where: { $0.id == id })?.factTitle ?? ""
        } set: { value in
            guard let index = store.entries.firstIndex(where: { $0.id == id }) else { return }
            store.entries[index].factTitle = value
        }
    }

    private func truthStatusBinding(_ id: String) -> Binding<String> {
        Binding {
            store.entries.first(where: { $0.id == id })?.truthStatus ?? ""
        } set: { value in
            guard let index = store.entries.firstIndex(where: { $0.id == id }) else { return }
            store.entries[index].truthStatus = value
        }
    }

    private func authorKnowledgeBinding(_ id: String) -> Binding<KnowledgeState> {
        Binding {
            store.entries.first(where: { $0.id == id })?.authorKnowledge ?? .unknown
        } set: { value in
            guard let index = store.entries.firstIndex(where: { $0.id == id }) else { return }
            store.entries[index].authorKnowledge = value
        }
    }

    private func readerKnowledgeBinding(_ id: String) -> Binding<KnowledgeState> {
        Binding {
            store.entries.first(where: { $0.id == id })?.readerKnowledge ?? .readerUnknown
        } set: { value in
            guard let index = store.entries.firstIndex(where: { $0.id == id }) else { return }
            store.entries[index].readerKnowledge = value
        }
    }

    private func characterStateBinding(_ id: String, characterName: String) -> Binding<KnowledgeState> {
        Binding {
            guard
                let entry = store.entries.first(where: { $0.id == id }),
                let knowledge = entry.characterKnowledge.first(where: { $0.characterName == characterName })
            else {
                return .unknown
            }
            return knowledge.state
        } set: { value in
            store.updateCharacterState(entryID: id, characterName: characterName, state: value)
        }
    }

    private func allowedNarrationBinding(_ id: String) -> Binding<String> {
        Binding {
            store.entries.first(where: { $0.id == id })?.allowedNarration ?? ""
        } set: { value in
            guard let index = store.entries.firstIndex(where: { $0.id == id }) else { return }
            store.entries[index].allowedNarration = value
        }
    }
}
