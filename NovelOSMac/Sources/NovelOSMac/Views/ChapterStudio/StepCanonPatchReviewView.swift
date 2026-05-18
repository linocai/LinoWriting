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
                                .font(.headline)
                            Spacer()
                            if store.chapter.status == .completed {
                                PillView(text: "本章已完成", tone: .green)
                            }
                        }

                        ForEach(patch.items) { item in
                            patchItemView(item)
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
                .disabled(store.canonPatch == nil || store.chapter.status == .completed)

                Button("确认更新，完成本章") {
                    Task {
                        await store.confirmCanonPatch()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.canonPatch == nil || store.chapter.status == .completed)
            }
        }
    }

    private func patchItemView(_ item: CanonPatchItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                PillView(text: item.target.rawValue, tone: targetTone(item.target))
                    .frame(width: 92, alignment: .leading)
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.title)
                        .font(.headline)
                    Text(item.summary)
                        .font(.callout)
                        .foregroundStyle(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                Picker("", selection: patchDecisionBinding(item.id)) {
                    ForEach(PatchUserDecision.allCases) { decision in
                        Text(decision.label).tag(decision)
                    }
                }
                .frame(width: 108)
            }

            if item.proposedAction == .modify {
                TextEditor(text: patchPayloadBinding(item.id))
                    .frame(minHeight: 86)
                    .padding(8)
                    .background(AppTheme.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border))
            }
        }
        .padding(12)
        .background(AppTheme.surfaceAlt.opacity(0.45), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
