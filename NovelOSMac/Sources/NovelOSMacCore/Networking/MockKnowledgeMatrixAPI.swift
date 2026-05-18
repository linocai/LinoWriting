import Foundation

public actor MockKnowledgeMatrixAPI: KnowledgeMatrixAPI {
    private var entries: [KnowledgeMatrixEntry]

    public init(entries: [KnowledgeMatrixEntry] = MockData.knowledgeEntries) {
        self.entries = entries
    }

    public func getKnowledgeMatrixEntries(novelID: String) async throws -> [KnowledgeMatrixEntry] {
        try validate(novelID)
        return entries
    }

    public func createKnowledgeMatrixEntry(_ entry: KnowledgeMatrixEntry, novelID: String) async throws -> KnowledgeMatrixEntry {
        try validate(novelID)
        entries.append(entry)
        return entry
    }

    public func updateKnowledgeMatrixEntry(_ entry: KnowledgeMatrixEntry, novelID: String) async throws -> KnowledgeMatrixEntry {
        try validate(novelID)
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else {
            throw APIError.missingResource("knowledge matrix entry \(entry.id)")
        }
        entries[index] = entry
        return entry
    }

    public func deleteKnowledgeMatrixEntry(entryID: String, novelID: String) async throws {
        try validate(novelID)
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else {
            throw APIError.missingResource("knowledge matrix entry \(entryID)")
        }
        entries.remove(at: index)
    }

    private func validate(_ novelID: String) throws {
        guard novelID == MockData.novel.id else {
            throw APIError.missingResource("novel \(novelID)")
        }
    }
}
