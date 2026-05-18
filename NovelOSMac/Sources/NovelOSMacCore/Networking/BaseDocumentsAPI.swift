import Foundation

public protocol BaseDocumentsAPI: Sendable {
    func getWorldBibleSections(novelID: String) async throws -> [WorldBibleSection]
    func createWorldBibleSection(_ section: WorldBibleSection, novelID: String) async throws -> WorldBibleSection
    func updateWorldBibleSection(_ section: WorldBibleSection, novelID: String) async throws -> WorldBibleSection
    func deleteWorldBibleSection(sectionID: String, novelID: String) async throws

    func getCharacterCards(novelID: String) async throws -> [CharacterCard]
    func createCharacterCard(_ card: CharacterCard, novelID: String) async throws -> CharacterCard
    func updateCharacterCard(_ card: CharacterCard, novelID: String) async throws -> CharacterCard
    func deleteCharacterCard(characterID: String, novelID: String) async throws

    func getMemoryFacts(novelID: String) async throws -> [MemoryFact]
    func createMemoryFact(_ fact: MemoryFact, novelID: String) async throws -> MemoryFact
    func updateMemoryFact(_ fact: MemoryFact, novelID: String) async throws -> MemoryFact
    func deleteMemoryFact(factID: String, novelID: String) async throws
}
