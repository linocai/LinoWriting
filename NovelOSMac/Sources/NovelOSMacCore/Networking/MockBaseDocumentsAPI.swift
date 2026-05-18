import Foundation

public actor MockBaseDocumentsAPI: BaseDocumentsAPI {
    private var worldBibleSections: [WorldBibleSection]
    private var characterCards: [CharacterCard]
    private var memoryFacts: [MemoryFact]

    public init(
        worldBibleSections: [WorldBibleSection] = MockData.worldBibleSections,
        characterCards: [CharacterCard] = MockData.characterCards,
        memoryFacts: [MemoryFact] = MockData.memoryFacts
    ) {
        self.worldBibleSections = worldBibleSections
        self.characterCards = characterCards
        self.memoryFacts = memoryFacts
    }

    public func getWorldBibleSections(novelID: String) async throws -> [WorldBibleSection] {
        try validate(novelID)
        return worldBibleSections
    }

    public func createWorldBibleSection(_ section: WorldBibleSection, novelID: String) async throws -> WorldBibleSection {
        try validate(novelID)
        worldBibleSections.append(section)
        return section
    }

    public func updateWorldBibleSection(_ section: WorldBibleSection, novelID: String) async throws -> WorldBibleSection {
        try validate(novelID)
        guard let index = worldBibleSections.firstIndex(where: { $0.id == section.id }) else {
            throw APIError.missingResource("world bible section \(section.id)")
        }
        worldBibleSections[index] = section
        return section
    }

    public func deleteWorldBibleSection(sectionID: String, novelID: String) async throws {
        try validate(novelID)
        guard let index = worldBibleSections.firstIndex(where: { $0.id == sectionID }) else {
            throw APIError.missingResource("world bible section \(sectionID)")
        }
        worldBibleSections.remove(at: index)
    }

    public func getCharacterCards(novelID: String) async throws -> [CharacterCard] {
        try validate(novelID)
        return characterCards
    }

    public func createCharacterCard(_ card: CharacterCard, novelID: String) async throws -> CharacterCard {
        try validate(novelID)
        characterCards.append(card)
        return card
    }

    public func updateCharacterCard(_ card: CharacterCard, novelID: String) async throws -> CharacterCard {
        try validate(novelID)
        guard let index = characterCards.firstIndex(where: { $0.id == card.id }) else {
            throw APIError.missingResource("character \(card.id)")
        }
        characterCards[index] = card
        return card
    }

    public func deleteCharacterCard(characterID: String, novelID: String) async throws {
        try validate(novelID)
        guard let index = characterCards.firstIndex(where: { $0.id == characterID }) else {
            throw APIError.missingResource("character \(characterID)")
        }
        characterCards.remove(at: index)
    }

    public func getMemoryFacts(novelID: String) async throws -> [MemoryFact] {
        try validate(novelID)
        return memoryFacts
    }

    public func createMemoryFact(_ fact: MemoryFact, novelID: String) async throws -> MemoryFact {
        try validate(novelID)
        memoryFacts.append(fact)
        return fact
    }

    public func updateMemoryFact(_ fact: MemoryFact, novelID: String) async throws -> MemoryFact {
        try validate(novelID)
        guard let index = memoryFacts.firstIndex(where: { $0.id == fact.id }) else {
            throw APIError.missingResource("memory fact \(fact.id)")
        }
        memoryFacts[index] = fact
        return fact
    }

    public func deleteMemoryFact(factID: String, novelID: String) async throws {
        try validate(novelID)
        guard let index = memoryFacts.firstIndex(where: { $0.id == factID }) else {
            throw APIError.missingResource("memory fact \(factID)")
        }
        memoryFacts.remove(at: index)
    }

    private func validate(_ novelID: String) throws {
        guard novelID == MockData.novel.id else {
            throw APIError.missingResource("novel \(novelID)")
        }
    }
}
