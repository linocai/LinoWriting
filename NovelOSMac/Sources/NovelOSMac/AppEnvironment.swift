import Foundation
import NovelOSMacCore

enum AppEnvironment {
    static var chapterWorkflowAPI: any ChapterWorkflowAPI {
        apiClientFromSettings() ?? MockChapterWorkflowAPI()
    }

    static var baseDocumentsAPI: any BaseDocumentsAPI {
        apiClientFromSettings() ?? MockBaseDocumentsAPI()
    }

    static var knowledgeMatrixAPI: any KnowledgeMatrixAPI {
        apiClientFromSettings() ?? MockKnowledgeMatrixAPI()
    }

    static var adminSettingsAPI: any AdminSettingsAPI {
        apiClientFromSettings() ?? MockAdminSettingsAPI()
    }

    static var novelLibraryAPI: any NovelLibraryAPI {
        apiClientFromSettings() ?? MockNovelLibraryAPI()
    }

    private static func apiClientFromSettings() -> APIClient? {
        if AppRuntimeSettings.useMockAPI {
            return nil
        }

        return APIClient(
            baseURLProvider: { AppRuntimeSettings.backendURL },
            ownerTokenProvider: { AppCredentials.ownerToken() }
        )
    }
}
