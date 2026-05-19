import Foundation

public actor MockNovelLibraryAPI: NovelLibraryAPI {
    private var novels: [Novel]
    private var chaptersByNovelID: [String: [Chapter]]
    private var bootstrapImports: [String: BootstrapImportRequest] = [:]

    public init(
        novels: [Novel] = [MockData.novel],
        chaptersByNovelID: [String: [Chapter]] = [MockData.novel.id: MockData.chapters]
    ) {
        self.novels = novels
        self.chaptersByNovelID = chaptersByNovelID
    }

    public func listNovels() async throws -> [Novel] {
        novels.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    public func createNovel(_ request: NovelCreateRequest) async throws -> Novel {
        let trimmedTitle = request.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw APIError.transport("书名不能为空。")
        }

        let id = "novel_\(UUID().uuidString.prefix(8))"
        let novel = Novel(
            id: id,
            title: trimmedTitle,
            genre: request.genre?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            currentChapterNo: nil,
            currentCanonVersion: nil,
            bootstrapStatus: .notStarted
        )
        novels.append(novel)
        chaptersByNovelID[id] = []
        return novel
    }

    public func listChapters(novelID: String) async throws -> [Chapter] {
        chaptersByNovelID[novelID] ?? []
    }

    public func createChapter(novelID: String, request: ChapterCreateRequest) async throws -> Chapter {
        guard novels.contains(where: { $0.id == novelID }) else {
            throw APIError.missingResource("novel \(novelID)")
        }
        var chapters = chaptersByNovelID[novelID] ?? []
        if chapters.contains(where: { $0.chapterNo == request.chapterNo }) {
            throw APIError.transport("章节已存在。")
        }
        let chapter = Chapter(
            id: "\(novelID)_chapter_\(String(format: "%03d", request.chapterNo))",
            novelId: novelID,
            chapterNo: request.chapterNo,
            title: request.title,
            status: .draftInput,
            targetWordCount: request.targetWordCount,
            approvedVersionId: nil,
            currentVersionId: nil,
            canonVersionUsed: nil
        )
        chapters.append(chapter)
        chaptersByNovelID[novelID] = chapters
        if let index = novels.firstIndex(where: { $0.id == novelID }) {
            novels[index].currentChapterNo = max(novels[index].currentChapterNo ?? 0, request.chapterNo)
        }
        return chapter
    }

    public func importFirstThreeChapters(novelID: String, request: BootstrapImportRequest) async throws -> NovelBootstrapStatus {
        guard novels.contains(where: { $0.id == novelID }) else {
            throw APIError.missingResource("novel \(novelID)")
        }
        let chapterNumbers = request.chapters.map(\.chapterNo).sorted()
        guard chapterNumbers == [1, 2, 3] else {
            throw APIError.transport("必须导入第 1、2、3 章。")
        }

        bootstrapImports[novelID] = request
        let chapters = request.chapters.map { input in
            Chapter(
                id: "\(novelID)_chapter_\(String(format: "%03d", input.chapterNo))",
                novelId: novelID,
                chapterNo: input.chapterNo,
                title: input.title,
                status: .completed,
                targetWordCount: max(3000, input.text.count),
                approvedVersionId: "\(novelID)_chapter_\(String(format: "%03d", input.chapterNo))_import_v1",
                currentVersionId: "\(novelID)_chapter_\(String(format: "%03d", input.chapterNo))_import_v1",
                canonVersionUsed: 1
            )
        }
        chaptersByNovelID[novelID] = chapters
        if let index = novels.firstIndex(where: { $0.id == novelID }) {
            novels[index].bootstrapStatus = .imported
            novels[index].currentChapterNo = 3
            novels[index].currentCanonVersion = 1
        }
        return NovelBootstrapStatus(
            novelId: novelID,
            status: .imported,
            importId: "mock_import_\(novelID)",
            importedChapterCount: 3,
            analysisReady: false,
            updatedAt: Date()
        )
    }

    public func getBootstrapStatus(novelID: String) async throws -> NovelBootstrapStatus {
        guard let novel = novels.first(where: { $0.id == novelID }) else {
            throw APIError.missingResource("novel \(novelID)")
        }
        return NovelBootstrapStatus(
            novelId: novelID,
            status: novel.bootstrapStatus,
            importId: bootstrapImports[novelID] == nil ? nil : "mock_import_\(novelID)",
            importedChapterCount: chaptersByNovelID[novelID]?.filter { $0.chapterNo <= 3 }.count ?? 0,
            analysisReady: novel.bootstrapStatus == .analyzed || novel.bootstrapStatus == .completed,
            updatedAt: Date()
        )
    }

    public func analyzeBootstrap(novelID: String) async throws -> BootstrapAnalyzeResult {
        guard bootstrapImports[novelID] != nil else {
            throw APIError.transport("请先导入前三章。")
        }
        if let index = novels.firstIndex(where: { $0.id == novelID }) {
            novels[index].bootstrapStatus = .analyzed
            novels[index].currentChapterNo = 3
            novels[index].currentCanonVersion = 1
        }
        return BootstrapAnalyzeResult(
            novelId: novelID,
            status: .analyzed,
            importId: "mock_import_\(novelID)",
            analysis: [
                "chapter_count": .int(3),
                "detected_status": .string("ready_for_chapter_4")
            ]
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
