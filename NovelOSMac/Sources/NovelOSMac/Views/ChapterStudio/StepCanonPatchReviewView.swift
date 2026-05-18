import NovelOSMacCore
import SwiftUI

struct StepCanonPatchReviewView: View {
    @Environment(ChapterWorkflowStore.self) private var store

    var body: some View {
        CardView {
            CardHeader(
                title: "确认基础文档更新",
                subtitle: "只显示会改变 Canon 的内容。你可以逐条接受、修改或拒绝。"
            ) {
                PillView(text: ChapterStep.canonPatchReview.userActionIndex, tone: .blue)
            }
            CardBody {
                if let patch = store.canonPatch {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("目标 Canon v\(patch.targetCanonVersion)")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(AppTheme.text)
                            Spacer()
                            if store.chapter.status == .completed {
                                PillView(text: "本章已完成", tone: .green)
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(patch.items) { item in
                                patchItemView(item)
                            }
                        }
                    }
                } else {
                    EmptyStateView(text: "基础文档更新尚未准备。请先批准正文。")
                }
            }
            CardFooter {
                Button("稍后确认") {
                    Task {
                        await store.savePatchForLater()
                    }
                }
                .buttonStyle(GhostButtonStyle())
                .disabled(store.canonPatch == nil || store.chapter.status == .completed)

                Button("确认更新，完成本章") {
                    Task {
                        await store.confirmCanonPatch()
                    }
                }
                .buttonStyle(BlueButtonStyle())
                .disabled(store.canonPatch == nil || store.chapter.status == .completed)
            }
        }
    }

    private func patchItemView(_ item: CanonPatchItem) -> some View {
        let decision = patchDecisionBinding(item.id)

        return TimelineItemView(
            badge: item.target.displayName,
            title: item.title,
            subtitle: item.summary,
            tone: targetTone(item.target)
        ) {
            if decision.wrappedValue == .modify {
                SoftTextEditor(text: patchPayloadBinding(item.id), minHeight: 86, idealHeight: 120)
            }
        } trailing: {
            Picker("", selection: decision) {
                ForEach(PatchUserDecision.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 186)
        }
    }

    private func patchDecisionBinding(_ itemID: String) -> Binding<PatchUserDecision> {
        Binding {
            store.canonPatch?.items.first(where: { $0.id == itemID })?.proposedAction ?? .accept
        } set: { decision in
            store.updatePatchDecision(itemID: itemID, decision: decision)
        }
    }

    private func patchPayloadBinding(_ itemID: String) -> Binding<String> {
        Binding {
            let item = store.canonPatch?.items.first(where: { $0.id == itemID })
            return item?.editablePayload ?? item?.summary ?? ""
        } set: { payload in
            store.updatePatchPayload(itemID: itemID, payload: payload)
        }
    }

    private func targetTone(_ target: CanonPatchTarget) -> PillTone {
        switch target {
        case .memory: .blue
        case .character: .orange
        case .knowledge: .purple
        case .worldBible: .green
        }
    }
}

private extension CanonPatchTarget {
    var displayName: String {
        switch self {
        case .memory: "Memory"
        case .character: "Character"
        case .knowledge: "Knowledge"
        case .worldBible: "World Bible"
        }
    }
}
