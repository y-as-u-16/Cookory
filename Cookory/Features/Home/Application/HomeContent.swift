import Foundation

/// Home 画面が必要とするデータをまとめた読み取り専用のモデル。
///
/// View がこれ 1 つを受け取る。個別に Repository を叩かせないことで、
/// 画面の都合が Domain 側へ漏れるのを防ぐ。
struct HomeContent: Equatable, Sendable {
    var recentMeals: [MealRecord]
    var forgottenDishes: [ForgottenDish]

    var isEmpty: Bool { recentMeals.isEmpty && forgottenDishes.isEmpty }

    static let empty = HomeContent(recentMeals: [], forgottenDishes: [])
}

/// しばらく作っていない料理。
struct ForgottenDish: Equatable, Sendable, Identifiable {
    let dish: Dish
    let lastCookedAt: Date
    let daysSinceLastCooked: Int

    var id: UUID { dish.id }
}
