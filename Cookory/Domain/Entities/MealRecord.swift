import Foundation

/// 1 回の食卓の記録。写真 1 枚から成立し、料理名や評価は後から足せる。
///
/// 「記録するときは極限までシンプルに」という原則により、写真以外はすべて任意。
struct MealRecord: Identifiable, Hashable, Sendable {
    let id: UUID
    var occurredAt: Date
    var mealType: MealType?
    var note: String?
    private(set) var photoIDs: [UUID]
    private(set) var dishLogIDs: [UUID]
    let createdAt: Date
    private(set) var updatedAt: Date

    init(
        id: UUID = UUID(),
        occurredAt: Date,
        mealType: MealType? = nil,
        note: String? = nil,
        photoIDs: [UUID] = [],
        dishLogIDs: [UUID] = [],
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.occurredAt = occurredAt
        self.mealType = mealType
        self.note = note?.normalizedOrNil
        self.photoIDs = photoIDs
        self.dishLogIDs = dishLogIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    func addingPhoto(_ photoID: UUID, at date: Date = Date()) -> MealRecord {
        guard !photoIDs.contains(photoID) else { return self }
        var copy = self
        copy.photoIDs.append(photoID)
        copy.updatedAt = date
        return copy
    }

    func removingPhoto(_ photoID: UUID, at date: Date = Date()) -> MealRecord {
        guard photoIDs.contains(photoID) else { return self }
        var copy = self
        copy.photoIDs.removeAll { $0 == photoID }
        copy.updatedAt = date
        return copy
    }

    func addingDishLog(_ dishLogID: UUID, at date: Date = Date()) -> MealRecord {
        guard !dishLogIDs.contains(dishLogID) else { return self }
        var copy = self
        copy.dishLogIDs.append(dishLogID)
        copy.updatedAt = date
        return copy
    }

    func removingDishLog(_ dishLogID: UUID, at date: Date = Date()) -> MealRecord {
        guard dishLogIDs.contains(dishLogID) else { return self }
        var copy = self
        copy.dishLogIDs.removeAll { $0 == dishLogID }
        copy.updatedAt = date
        return copy
    }

    func edited(mealType: MealType?, note: String?, at date: Date = Date()) -> MealRecord {
        var copy = self
        copy.mealType = mealType
        copy.note = note?.normalizedOrNil
        copy.updatedAt = date
        return copy
    }
}
