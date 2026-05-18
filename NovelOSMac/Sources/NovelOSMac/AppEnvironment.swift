import Foundation
import NovelOSMacCore

enum AppEnvironment {
    static var chapterWorkflowAPI: any ChapterWorkflowAPI {
        let key = "NOVEL_OS_API_BASE_URL"
        let rawValue = ProcessInfo.processInfo.environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let rawValue, !rawValue.isEmpty else {
            return MockChapterWorkflowAPI()
        }

        guard
            let url = URL(string: rawValue),
            url.scheme != nil,
            url.host != nil
        else {
            return MockChapterWorkflowAPI()
        }

        return APIClient(baseURL: url)
    }
}
