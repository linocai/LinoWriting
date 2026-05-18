import NovelOSMacCore
import SwiftUI

struct KnowledgeMatrixView: View {
    @Environment(KnowledgeMatrixStore.self) private var store

    var body: some View {
        @Bindable var store = store

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                TopBarView(kicker: "Knowledge Matrix · 核心防穿帮模块", title: "谁知道什么，比发生过什么更重要") {
                    HStack(spacing: 10) {
                        Button {
                            store.addEntry()
                        } label: {
                            Label("新增知识条目", systemImage: "plus")
                        }
                        Button("保存 Matrix") {
                            store.saveMatrix()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                HStack(spacing: 12) {
                    TextField("筛选事实、限制或 truth status", text: $store.filterText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 360)
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

                CardView {
                    CardHeader(
                        title: "知识矩阵",
                        subtitle: "写作 Agent 只能根据本章视角使用允许的信息；Audit Agent 用完整矩阵检查越界。"
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
                                            Text(entry.truthStatus)
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.muted)
                                        }
                                        statePill(entry.authorKnowledge)
                                        statePill(entry.readerKnowledge)
                                        ForEach(store.visibleCharacters, id: \.self) { name in
                                            statePill(characterState(entry, name: name))
                                        }
                                        TextField("允许叙述", text: allowedNarrationBinding(entry.id), axis: .vertical)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: 320)
                                    }
                                    Divider()
                                        .gridCellColumns(6 + store.visibleCharacters.count)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                HStack(alignment: .top, spacing: 12) {
                    ContentBlock("施工意见 1") {
                        Text("Matrix 适合表格视图，不适合纯文本编辑。它本质是状态机，不是备注。")
                            .font(.callout)
                            .foregroundStyle(AppTheme.muted)
                    }
                    ContentBlock("施工意见 2") {
                        Text("每章结构化 Prompt 只展示相关限制，不展示全矩阵，避免信息过载。")
                            .font(.callout)
                            .foregroundStyle(AppTheme.muted)
                    }
                    ContentBlock("施工意见 3") {
                        Text("允许按角色和状态筛选：只看 A 知道什么、B 隐瞒什么、读者已经知道什么。")
                            .font(.callout)
                            .foregroundStyle(AppTheme.muted)
                    }
                }
            }
            .padding(22)
        }
        .background(AppTheme.background)
    }

    private func matrixHeader(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(AppTheme.muted)
            .frame(width: width, alignment: .leading)
    }

    private func statePill(_ state: KnowledgeState) -> some View {
        PillView(text: state.rawValue, tone: tone(for: state))
            .frame(width: 120, alignment: .leading)
    }

    private func characterState(_ entry: KnowledgeMatrixEntry, name: String) -> KnowledgeState {
        entry.characterKnowledge.first(where: { $0.characterName == name })?.state ?? .unknown
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

    private func allowedNarrationBinding(_ id: String) -> Binding<String> {
        Binding {
            store.entries.first(where: { $0.id == id })?.allowedNarration ?? ""
        } set: { value in
            guard let index = store.entries.firstIndex(where: { $0.id == id }) else { return }
            store.entries[index].allowedNarration = value
        }
    }
}
