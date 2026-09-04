import Foundation

/// 書き出し形式。Domain の型をそのまま Codable にすると、
/// Domain の変更が過去の書き出しファイルと非互換になる。
struct ExportManifest: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let exportedAt: Date
    let mealCount: Int
    let dishCount: Int
    let dishLogCount: Int
    let photoCount: Int

    /// 読み出せず書き出しから漏れた写真の枚数。0 でない ZIP は不完全である
    /// ことを、開いた人が manifest だけで判断できるようにする。
    let failedPhotoCount: Int
}

struct ExportedMeal: Codable, Equatable, Sendable {
    let id: UUID
    let occurredAt: Date
    let mealType: String?
    let note: String?
    let photoIDs: [UUID]
    let dishLogIDs: [UUID]
    let createdAt: Date
    let updatedAt: Date

    init(_ meal: MealRecord) {
        id = meal.id
        occurredAt = meal.occurredAt
        mealType = meal.mealType?.rawValue
        note = meal.note
        photoIDs = meal.photoIDs
        dishLogIDs = meal.dishLogIDs
        createdAt = meal.createdAt
        updatedAt = meal.updatedAt
    }
}

struct ExportedDish: Codable, Equatable, Sendable {
    let id: UUID
    let name: String
    let isFavorite: Bool
    let createdAt: Date
    let updatedAt: Date

    init(_ dish: Dish) {
        id = dish.id
        name = dish.name.value
        isFavorite = dish.isFavorite
        createdAt = dish.createdAt
        updatedAt = dish.updatedAt
    }
}

struct ExportedDishLog: Codable, Equatable, Sendable {
    let id: UUID
    let dishID: UUID
    let mealRecordID: UUID
    let rating: Int?
    let note: String?
    let cookedAt: Date

    init(_ log: DishLog) {
        id = log.id
        dishID = log.dishID
        mealRecordID = log.mealRecordID
        rating = log.rating?.value
        note = log.note
        cookedAt = log.cookedAt
    }
}
