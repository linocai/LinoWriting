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
                        .buttonStyle(GhostButtonStyle())
                        Button("保存矩阵") {
                            Task {
                                await store.saveMatrix()
                            }
                        }
                        .buttonStyle(BlueButtonStyle())
                        SaveStatusBadge(isSaving: store.isSaving, lastSavedAt: store.lastSavedAt)
                    }
                }

                summaryStrip

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        SoftTextField("筛选事实、限制或真相状态", text: $store.filterText)
                            .frame(maxWidth: 360)
                        SoftPicker("角色", selection: $store.selectedCharacterName) {
                            Text("全部角色").tag(String?.none)
                            ForEach(store.characterFilterOptions, id: \.self) { name in
                                Text(name).tag(String?.some(name))
                            }
                        }
                        .frame(width: 190)
                        SoftPicker("状态", selection: $store.selectedState) {
                            Text("全部状态").tag(KnowledgeState?.none)
                            ForEach(KnowledgeState.allCases) { state in
                                Text(state.displayName).tag(KnowledgeState?.some(state))
                            }
                        }
                        .frame(width: 220)
                        Spacer()
                        PillView(text: "防止开天眼", tone: .red)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SoftTextField("筛选事实、限制或真相状态", text: $store.filterText)
                        HStack(spacing: 10) {
                            SoftPicker("角色", selection: $store.selectedCharacterName) {
                                Text("全部角色").tag(String?.none)
                                ForEach(store.characterFilterOptions, id: \.self) { name in
                                    Text(name).tag(String?.some(name))
                                }
                            }
                            SoftPicker("状态", selection: $store.selectedState) {
                                Text("全部状态").tag(KnowledgeState?.none)
                                ForEach(KnowledgeState.allCases) { state in
                                    Text(state.displayName).tag(KnowledgeState?.some(state))
                                }
                            }
                        }
                    }
                }

                if let message = store.statusMessage {
                    StatusBanner(message: message, tone: .green)
                }

                if store.isLoading || store.isSaving {
                    StatusBanner(message: store.isLoading ? "加载知识矩阵中" : "保存知识矩阵中", tone: .blue)
                }

                CardView {
                    CardHeader(
                        title: "知识矩阵",
                        subtitle: "按作者、读者和角色分别记录可知信息，避免正文提前泄露真相。"
                    )
                    CardBody {
                        if store.characterFilterOptions.count > 4 {
                            columnPinControls
                        }
                        ScrollView(.horizontal) {
                            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                                GridRow {
                                    matrixHeader("事实 / 秘密", width: 240)
                                    matrixHeader("作者", width: 126)
                                    matrixHeader("读者", width: 126)
                                    ForEach(store.displayedCharacters, id: \.self) { name in
                                        matrixHeader(name, width: 126)
                                    }
                                    matrixHeader("允许叙述", width: 320)
                                    matrixHeader("", width: 44)
                                }

                                ForEach(Array(store.filteredEntries.enumerated()), id: \.element.id) { index, entry in
                                    GridRow(alignment: .top) {
                                        factCell(entry.id, isEven: index.isMultiple(of: 2))
                                        stateCell(authorKnowledgeBinding(entry.id), isEven: index.isMultiple(of: 2))
                                        stateCell(readerKnowledgeBinding(entry.id), isEven: index.isMultiple(of: 2))
                                        ForEach(store.displayedCharacters, id: \.self) { name in
                                            stateCell(characterStateBinding(entry.id, characterName: name), isEven: index.isMultiple(of: 2))
                                        }
                                        narrationCell(entry.id, isEven: index.isMultiple(of: 2))
                                        deleteCell(entry.id, isEven: index.isMultiple(of: 2))
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 12, alignment: .top)], alignment: .leading, spacing: 12) {
                    SideNoteView(title: "使用方式", text: "用矩阵记录每条事实对作者、读者和角色的可见状态，方便检查叙事视角。")
                    SideNoteView(title: "章节写作", text: "每章只会带入相关限制，当前页面负责维护完整矩阵。")
                    SideNoteView(title: "筛选建议", text: "允许按角色和状态筛选：只看 A 知道什么、B 隐瞒什么、读者已经知道什么。")
                }
            }
            .padding(AppTheme.pagePadding)
        }
        .scrollIndicators(.visible)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppBackgroundView())
        .task {
            await store.loadIfNeeded()
        }
    }

    private var summaryStrip: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12, alignment: .top)], alignment: .leading, spacing: 12) {
            MatrixSummaryCard(title: "总秘密", value: "\(store.entries.count)", tone: .purple)
            MatrixSummaryCard(title: "本章可见性变化", value: "\(visibilityChangeCount)", tone: .blue)
            MatrixSummaryCard(title: "Auditor 状态", value: possibleLeakCount > 0 ? "待检查" : "通过", tone: possibleLeakCount > 0 ? .orange : .green)
        }
    }

    private var visibilityChangeCount: Int {
        store.entries.filter { !$0.characterVisibility.isEmpty }.count
    }

    private var possibleLeakCount: Int {
        store.entries.filter { entry in
            entry.allowedNarration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || (entry.authorKnowledge == .authorOnly && entry.readerKnowledge == .readerKnown)
        }.count
    }

    private func matrixHeader(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(AppTheme.muted)
            .frame(width: width, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(AppTheme.panelSubtle, in: RoundedRectangle(cornerRadius: AppTheme.radiusMD, style: .continuous))
    }

    private func factCell(_ id: String, isEven: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SoftTextField(title: "事实", text: factTitleBinding(id), axis: .vertical)
            SoftTextField(title: "真相状态", text: truthStatusBinding(id), axis: .vertical)
        }
        .frame(width: 240)
        .padding(8)
        .background(rowBackground(isEven), in: RoundedRectangle(cornerRadius: AppTheme.radiusMD, style: .continuous))
    }

    private func stateCell(_ selection: Binding<KnowledgeState>, isEven: Bool) -> some View {
        KnowledgeStatePillPicker(state: selection)
            .frame(width: 126)
            .padding(8)
            .background(rowBackground(isEven), in: RoundedRectangle(cornerRadius: AppTheme.radiusMD, style: .continuous))
    }

    private func narrationCell(_ id: String, isEven: Bool) -> some View {
        SoftTextEditor(text: allowedNarrationBinding(id), minHeight: 44, idealHeight: 64)
            .frame(width: 320)
            .padding(8)
            .background(rowBackground(isEven), in: RoundedRectangle(cornerRadius: AppTheme.radiusMD, style: .continuous))
    }

    private func deleteCell(_ id: String, isEven: Bool) -> some View {
        Button(role: .destructive) {
            Task {
                await store.deleteEntry(id: id)
            }
        } label: {
            Image(systemName: "trash")
        }
        .buttonStyle(DangerButtonStyle())
        .frame(width: 44)
        .padding(8)
        .background(rowBackground(isEven), in: RoundedRectangle(cornerRadius: AppTheme.radiusMD, style: .continuous))
    }

    private func rowBackground(_ isEven: Bool) -> Color {
        isEven ? Color.white.opacity(0.56) : AppTheme.panelSubtle
    }

    private var columnPinControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(store.pinnedColumns.isEmpty ? "默认显示前 4 个最活跃角色列" : "已固定 \(store.pinnedColumns.count) 列")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.muted)
                Spacer()
                if !store.pinnedColumns.isEmpty {
                    Button {
                        store.clearColumnPins()
                    } label: {
                        Label("重置为默认", systemImage: "arrow.uturn.backward")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.blue)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(store.characterFilterOptions, id: \.self) { name in
                        let isPinned = store.pinnedColumns.contains(name)
                        Button {
                            store.toggleColumnPin(name)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: isPinned ? "pin.fill" : "pin")
                                    .font(.system(size: 10, weight: .semibold))
                                Text(name).font(.caption.weight(.semibold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                isPinned ? AppTheme.blue.opacity(0.18) : Color.white.opacity(0.66),
                                in: RoundedRectangle(cornerRadius: 999, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 999, style: .continuous)
                                    .stroke(isPinned ? AppTheme.blue.opacity(0.5) : AppTheme.line, lineWidth: 1)
                            )
                            .foregroundStyle(isPinned ? AppTheme.blue : AppTheme.text)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.bottom, 6)
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
                let state = entry.visibility[characterName]
            else {
                return .unknown
            }
            return state
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

private struct MatrixSummaryCard: View {
    let title: String
    let value: String
    var tone: PillTone

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.muted)
                Text(value)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(tone.palette.foreground)
            }
            Spacer()
        }
        .padding(14)
        .background(tone.palette.background, in: RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous)
                .stroke(tone.palette.border, lineWidth: 1)
        )
    }
}
