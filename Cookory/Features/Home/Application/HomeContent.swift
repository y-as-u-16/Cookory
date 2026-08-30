import Foundation

/// Home 画面が必要とするデータをまとめた読み取り専用のモデル。
///
/// View がこれ 1 つを受け取る。個別に Repository を叩かせないことで、
/// 画面の都合が Domain 側へ漏れるのを防ぐ。
struct HomeContent: Equatable, Sendable {
    var recentMeals: [RecentMeal]
    var forgottenDishes: [ForgottenDish]
    var summary: CookingSummary

    var isEmpty: Bool { recentMeals.isEmpty && forgottenDishes.isEmpty }

    static let empty = HomeContent(
        recentMeals: [], forgottenDishes: [], summary: .empty
    )
}

/// 最近の記録 1 件。
///
/// 料理名を併せて持つ。日付だけの一覧では「何を作ったか」が分からず、
/// 思い出す手がかりにならない。
struct RecentMeal: Equatable, Sendable, Identifiable {
    let meal: MealRecord
    let dishNames: [DishName]

    var id: UUID { meal.id }

    /// 料理名が無ければ日付だけを見せる。名前は任意入力のため空はあり得る。
    var title: String? {
        dishNames.isEmpty ? nil : dishNames.map(\.value).joined(separator: "、")
    }
}

/// しばらく作っていない料理。
struct ForgottenDish: Equatable, Sendable, Identifiable {
    let dish: Dish
    let lastCookedAt: Date
    let daysSinceLastCooked: Int

    /// 最後に作ったときの写真。文字だけでは思い出す手がかりにならない。
    let latestPhotoID: UUID?

    var id: UUID { dish.id }
}
