import Foundation

/// リンクの保存形。RecipeLink をそのまま Codable にすると、
/// 検証ルールを変えたときに既存データが読めなくなる。
private struct StoredLink: Codable {
    let id: UUID
    let url: String
    let title: String?
}

/// 要素ごとの失敗を配列全体に波及させないための包み。配列を
/// `[T]` として一度に decode すると、1 件の不正で全件が失われる。
private struct DecodedElement<T: Decodable>: Decodable {
    let value: T?

    init(from decoder: Decoder) throws {
        value = try? decoder.singleValueContainer().decode(T.self)
    }
}

extension RecipeModel {
    /// 壊れたリンクは捨てて残りを読む。1 件の不正でレシピ全体を
    /// 読めなくするより、読める範囲を見せるほうが損失が小さい。
    func toDomain() -> Recipe {
        Recipe(
            id: id,
            dishID: dishID,
            ingredients: ingredients,
            steps: steps,
            links: Self.decodeLinks(linksJSON),
            photoIDs: Self.decodeIDs(photoIDsJSON),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func update(from recipe: Recipe) {
        ingredients = recipe.ingredients
        steps = recipe.steps
        linksJSON = Self.encodeLinks(recipe.links)
        photoIDsJSON = Self.encodeIDs(recipe.photoIDs)
        updatedAt = recipe.updatedAt
    }

    convenience init(from recipe: Recipe) {
        self.init(
            id: recipe.id,
            dishID: recipe.dishID,
            ingredients: recipe.ingredients,
            steps: recipe.steps,
            linksJSON: Self.encodeLinks(recipe.links),
            photoIDsJSON: Self.encodeIDs(recipe.photoIDs),
            createdAt: recipe.createdAt,
            updatedAt: recipe.updatedAt
        )
    }

    static func decodeLinks(_ json: String?) -> [RecipeLink] {
        decodeElements(json, as: StoredLink.self)
            .compactMap { RecipeLink(id: $0.id, rawURL: $0.url, title: $0.title) }
    }

    static func decodeIDs(_ json: String?) -> [UUID] {
        decodeElements(json, as: UUID.self)
    }

    private static func decodeElements<T: Decodable>(_ json: String?, as type: T.Type) -> [T] {
        guard let json, let data = json.data(using: .utf8),
              let elements = try? JSONDecoder().decode([DecodedElement<T>].self, from: data) else {
            return []
        }
        return elements.compactMap(\.value)
    }

    static func encodeIDs(_ ids: [UUID]) -> String? {
        guard !ids.isEmpty, let data = try? JSONEncoder().encode(ids) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func encodeLinks(_ links: [RecipeLink]) -> String? {
        guard !links.isEmpty else { return nil }
        let stored = links.map {
            StoredLink(id: $0.id, url: $0.url.absoluteString, title: $0.title)
        }
        guard let data = try? JSONEncoder().encode(stored) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
