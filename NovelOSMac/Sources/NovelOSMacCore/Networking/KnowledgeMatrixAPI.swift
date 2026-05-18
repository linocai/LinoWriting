import Foundation

public protocol KnowledgeMatrixAPI: Sendable {
    func getKnowledgeMatrixEntries(novelID: String) async throws -> [KnowledgeMatrixEntry]
    func createKnowledgeMatrixEntry(_ entry: KnowledgeMatrixEntry, novelID: String) async throws -> KnowledgeMatrixEntry
    func updateKnowledgeMatrixEntry(_ entry: KnowledgeMatrixEntry, novelID: String) async throws -> KnowledgeMatrixEntry
    func deleteKnowledgeMatrixEntry(entryID: String, novelID: String) async throws
}
