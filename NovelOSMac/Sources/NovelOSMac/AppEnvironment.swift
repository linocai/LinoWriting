import Foundation
import NovelOSMacCore

enum AppEnvironment {
    static var chapterWorkflowAPI: any ChapterWorkflowAPI {
        apiClientFromEnvironment() ?? MockChapterWorkflowAPI()
    }

    static var baseDocumentsAPI: any BaseDocumentsAPI {
        apiClientFromEnvironment() ?? MockBaseDocumentsAPI()
    }

    private static func apiClientFromEnvironment() -> APIClient? {
        let key = "NOVEL_OS_API_BASE_URL"
        let rawValue = ProcessInfo.processInfo.environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let rawValue, !rawValue.isEmpty else {
            return nil
        }

        guard
            let url = URL(string: rawValue),
            url.scheme != nil,
            url.host != nil
        else {
            return nil
        }

        return APIClient(baseURL: url)
    }
}
