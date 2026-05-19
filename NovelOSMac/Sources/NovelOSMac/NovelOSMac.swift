import NovelOSMacCore
import SwiftUI

@main
struct NovelOSMacApp: App {
    @State private var appStore = AppStore()
    @State private var chapterStore = ChapterWorkflowStore(api: AppEnvironment.chapterWorkflowAPI)
    @State private var baseDocumentsStore = BaseDocumentsStore(api: AppEnvironment.baseDocumentsAPI)
    @State private var knowledgeStore = KnowledgeMatrixStore(api: AppEnvironment.knowledgeMatrixAPI)
    @State private var settingsStore = ApplicationSettingsStore(api: AppEnvironment.adminSettingsAPI)

    var body: some Scene {
        WindowGroup("NovelOSMac") {
            RootShellView()
                .environment(appStore)
                .environment(chapterStore)
                .environment(baseDocumentsStore)
                .environment(knowledgeStore)
                .environment(settingsStore)
                .preferredColorScheme(.light)
                .frame(
                    minWidth: 900,
                    idealWidth: 1440,
                    maxWidth: .infinity,
                    minHeight: 760,
                    idealHeight: 900,
                    maxHeight: .infinity
                )
        }
        .defaultSize(width: 1440, height: 900)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .saveItem) {
                Button("保存") {
                    routeSaveAction()
                }
                .keyboardShortcut("s", modifiers: .command)

                Button("显示/隐藏 Inspector") {
                    appStore.isInspectorVisible.toggle()
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
            }
        }
    }

    private func routeSaveAction() {
        switch appStore.selectedWorkspace {
        case .chapterStudio:
            chapterStore.saveCurrentDraftVersion()
        case .baseFiles:
            Task {
                await baseDocumentsStore.saveChanges()
            }
        case .knowledgeMatrix:
            Task {
                await knowledgeStore.saveMatrix()
            }
        case .versionsDebug, .chaptersList, .writingSettings:
            appStore.toast = ToastState(id: UUID().uuidString, message: "当前页面没有需要保存的内容。", kind: .info)
        }
    }
}
