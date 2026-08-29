import Foundation

/// いつの食事か。
///
/// 表示名は持たない。ロケールごとの文言は Presentation 層の責務。
enum MealType: String, Codable, CaseIterable, Sendable {
    case breakfast
    case lunch
    case dinner
    case snack
}
