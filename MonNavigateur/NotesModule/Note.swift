import Foundation

// --- MODÈLES DE DONNÉES ---

public struct NoteBlock: Identifiable, Codable {
    public var id: UUID?
    public var content: String
    public var order_index: Int
    public var is_pinned: Bool
    public var is_favorite: Bool
    // ✅ La nouvelle colonne indispensable
    public var category: String
    
    // Initialiseur mis à jour
    public init(id: UUID? = nil,
                content: String,
                order_index: Int = 0,
                is_pinned: Bool = false,
                is_favorite: Bool = false,
                category: String = "À catégoriser") {
        self.id = id
        self.content = content
        self.order_index = order_index
        self.is_pinned = is_pinned
        self.is_favorite = is_favorite
        self.category = category
    }
}

// ✅ La structure pour la liste des catégories
public struct CategoryBlock: Identifiable, Codable {
    public var id: UUID
    public var name: String
}
