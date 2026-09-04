import Foundation

/// 図鑑の 1 行。調理回数と最終調理日を含む。
struct CookbookItem: Equatable, Sendable, Identifiable {
    let dish: Dish
    let cookCount: Int
    let lastCookedAt: Date?
    let latestPhotoID: UUID?

    var id: UUID { dish.id }
}

/// 並び順。
enum CookbookSort: String, CaseIterable, Sendable {
    case recentlyCooked
    case mostCooked
    case notCookedRecently
    case favorite
    case name
}
