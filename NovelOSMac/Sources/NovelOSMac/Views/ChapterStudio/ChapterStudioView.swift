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
                        .buttonStyle(GhostButtonStyle())
                        Button {
                            store.tryMove(to: store.highestUnlockedStep)
                        } label: {
                            Label("继续当前步骤", systemImage: "arrow.right.circle")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                }

                if let message = store.statusMessage {
                    StatusBanner(message: message, tone: .blue)
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
            .padding(AppTheme.pagePadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppBackgroundView())
    }
}

struct ChapterStepperView: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            stepperPanel(flexible: true)

            ScrollView(.horizontal, showsIndicators: false) {
                stepperPanel(flexible: false)
                    .padding(.vertical, 2)
            }
        }
    }

    private func stepperPanel(flexible: Bool) -> some View {
        HStack(spacing: 8) {
            ForEach(ChapterStep.allCases) { step in
                ChapterStepCell(step: step, flexible: flexible)
            }
        }
        .padding(10)
        .frame(maxWidth: flexible ? .infinity : nil, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.radiusXL, style: .continuous))
        .background(Color.white.opacity(0.66), in: RoundedRectangle(cornerRadius: AppTheme.radiusXL, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusXL, style: .continuous)
                .stroke(Color.white.opacity(0.80), lineWidth: 1)
        )
        .shadow(color: AppTheme.shadow, radius: 22, x: 0, y: 12)
    }
}

private struct ChapterStepCell: View {
    @Environment(ChapterWorkflowStore.self) private var store

    let step: ChapterStep
    let flexible: Bool

    @State private var isHovered = false

    var body: some View {
        Button {
            store.tryMove(to: step)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("\(step.rawValue)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(step == store.currentStep ? .white : numberColor)
                        .frame(width: 24, height: 24)
                        .background(numberBackground, in: Circle())
                    Text(step.title)
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)
                        .foregroundStyle(AppTheme.text)
                }
                Text(step.subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(2)
            }
            .frame(minHeight: 86, alignment: .leading)
            .frame(width: flexible ? nil : 184, alignment: .leading)
            .frame(minWidth: flexible ? 150 : nil, maxWidth: flexible ? .infinity : nil, alignment: .leading)
            .padding(12)
            .background(stepBackground, in: RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous)
                    .stroke(stepBorder, lineWidth: 1)
            )
            .shadow(color: step == store.currentStep ? AppTheme.blue.opacity(0.16) : .clear, radius: 14, x: 0, y: 8)
            .opacity(store.canMove(to: step) ? 1 : 0.48)
        }
        .buttonStyle(.plain)
        .disabled(!store.canMove(to: step))
        .onHover { isHovered = $0 }
    }

    private var isDone: Bool {
        step.rawValue < store.currentStep.rawValue || step.rawValue < store.highestUnlockedStep.rawValue
    }

    private var numberBackground: Color {
        if step == store.currentStep { return AppTheme.blue }
        if isDone { return AppTheme.green.opacity(0.16) }
        return Color.black.opacity(0.05)
    }

    private var numberColor: Color {
        isDone ? AppTheme.green : AppTheme.muted
    }

    private var stepBackground: Color {
        if step == store.currentStep { return Color.white.opacity(0.94) }
        if isDone { return AppTheme.green.opacity(0.08) }
        if isHovered { return Color.white.opacity(0.60) }
        return Color.clear
    }

    private var stepBorder: Color {
        if step == store.currentStep { return AppTheme.blue.opacity(0.58) }
        if isDone { return AppTheme.green.opacity(0.24) }
        return Color.white.opacity(isHovered ? 0.72 : 0.0)
    }
}
