import Foundation

public protocol NovelLibraryAPI: Sendable {
    func listNovels() async throws -> [Novel]
    func createNovel(_ request: NovelCreateRequest) async throws -> Novel
    func listChapters(novelID: String) async throws -> [Chapter]
    func createChapter(novelID: String, request: ChapterCreateRequest) async throws -> Chapter
    func importFirstThreeChapters(novelID: String, request: BootstrapImportRequest) async throws -> NovelBootstrapStatus
    func getBootstrapStatus(novelID: String) async throws -> NovelBootstrapStatus
    func analyzeBootstrap(novelID: String) async throws -> BootstrapAnalyzeResult
}
