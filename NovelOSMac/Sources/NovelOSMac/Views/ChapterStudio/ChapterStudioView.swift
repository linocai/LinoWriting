import NovelOSMacCore
import SwiftUI

struct ChapterStudioView: View {
    @Environment(ChapterWorkflowStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                TopBarView(kicker: "Chapter Studio · 主流程", title: "一章一个工作台，专心把这一章写出来") {
                    HStack(spacing: 10) {
                        PillView(text: "自动保存", tone: .green)
                        Button {
                            store.statusMessage = "本章导出会在接入真实版本后启用。"
                        } label: {
                            Label("导出本章", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            store.tryMove(to: store.highestUnlockedStep)
                        } label: {
                            Label("继续当前步骤", systemImage: "arrow.right.circle")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                if let message = store.statusMessage {
                    Text(message)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(AppTheme.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppTheme.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                ChapterStepperView()

                switch store.currentStep {
                case .promptInput:
                    StepPromptInputView()
                case .structuredPromptReview:
                    StepStructuredPromptReviewView()
                case .draftReview:
                    StepDraftReviewView()
                case .finalApproval:
                    StepFinalApprovalView()
                case .canonPatchReview:
                    StepCanonPatchReviewView()
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
    }
}

struct ChapterStepperView: View {
    @Environment(ChapterWorkflowStore.self) private var store

    var body: some View {
        ViewThatFits(in: .horizontal) {
            stepperRow(flexible: true)

            ScrollView(.horizontal, showsIndicators: false) {
                stepperRow(flexible: false)
                    .padding(.vertical, 2)
            }
        }
    }

    private func stepperRow(flexible: Bool) -> some View {
        HStack(spacing: 10) {
            ForEach(ChapterStep.allCases) { step in
                stepButton(for: step, flexible: flexible)
            }
        }
        .frame(maxWidth: flexible ? .infinity : nil, alignment: .leading)
    }

    private func stepButton(for step: ChapterStep, flexible: Bool) -> some View {
        Button {
            store.tryMove(to: step)
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text("\(step.rawValue)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(step == store.currentStep ? .white : numberColor(for: step))
                        .frame(width: 24, height: 24)
                        .background(numberBackground(for: step), in: Circle())
                    Text(step.title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                }
                Text(step.subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(2)
            }
            .frame(minHeight: 74, alignment: .leading)
            .frame(width: flexible ? nil : 176, alignment: .leading)
            .frame(minWidth: flexible ? 150 : nil, maxWidth: flexible ? .infinity : nil, alignment: .leading)
            .padding(12)
            .background(stepBackground(for: step), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(step == store.currentStep ? AppTheme.blue.opacity(0.65) : AppTheme.border, lineWidth: 1)
            )
            .opacity(store.canMove(to: step) ? 1 : 0.48)
        }
        .buttonStyle(.plain)
        .disabled(!store.canMove(to: step))
    }

    private func numberBackground(for step: ChapterStep) -> Color {
        if step == store.currentStep { return AppTheme.blue }
        if step.rawValue < store.currentStep.rawValue || step.rawValue < store.highestUnlockedStep.rawValue { return AppTheme.green.opacity(0.16) }
        return AppTheme.surfaceAlt
    }

    private func numberColor(for step: ChapterStep) -> Color {
        if step.rawValue < store.currentStep.rawValue || step.rawValue < store.highestUnlockedStep.rawValue { return AppTheme.green }
        return AppTheme.muted
    }

    private func stepBackground(for step: ChapterStep) -> Color {
        step == store.currentStep ? AppTheme.blue.opacity(0.08) : AppTheme.surface
    }
}
