import NovelOSMacCore
import SwiftUI

@main
struct NovelOSMacApp: App {
    @State private var appStore = AppStore()
    @State private var chapterStore = ChapterWorkflowStore()
    @State private var baseDocumentsStore = BaseDocumentsStore()
    @State private var knowledgeStore = KnowledgeMatrixStore()

    var body: some Scene {
        WindowGroup {
            RootShellView()
                .environment(appStore)
                .environment(chapterStore)
                .environment(baseDocumentsStore)
                .environment(knowledgeStore)
                .frame(minWidth: 1180, minHeight: 760)
        }
        .commands {
            CommandGroup(after: .saveItem) {
                Button("保存") {
                    routeSaveAction()
                }
                .keyboardShortcut("s", modifiers: .command)
            }
        }
    }

    private func routeSaveAction() {
        switch appStore.selectedWorkspace {
        case .chapterStudio:
            chapterStore.saveCurrentDraftVersion()
        case .baseFiles:
            baseDocumentsStore.saveChanges()
        case .knowledgeMatrix:
            knowledgeStore.saveMatrix()
        case .versionsDebug, .chaptersList, .writingSettings:
            appStore.toast = ToastState(id: UUID().uuidString, message: "当前页面没有需要保存的内容。", kind: .info)
        }
    }
}
