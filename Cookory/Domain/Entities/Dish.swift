import Foundation

/// 料理そのもの。「唐揚げ」は何度作っても 1 件のまま。
///
/// 作った回数は DishLog の件数で表す。ここに回数や最終調理日を持たせると、
/// 記録を追加するたびに Dish の更新が必要になり、集計の正しさを保てなくなる。
struct Dish: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: DishName
    var isFavorite: Bool
    let createdAt: Date
    private(set) var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: DishName,
        isFavorite: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    func renamed(to newName: DishName, at date: Date = Date()) -> Dish {
        var copy = self
        copy.name = newName
        copy.updatedAt = date
        return copy
    }

    func favoriteToggled(at date: Date = Date()) -> Dish {
        var copy = self
        copy.isFavorite.toggle()
        copy.updatedAt = date
        return copy
    }
}
