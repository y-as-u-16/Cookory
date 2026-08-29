import Foundation

extension MealRecordModel {
    func toDomain() -> MealRecord {
        MealRecord(
            id: id,
            occurredAt: occurredAt,
            mealType: mealTypeRawValue.flatMap(MealType.init(rawValue:)),
            note: note,
            photoIDs: photoIDs,
            dishLogIDs: dishLogIDs,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func update(from meal: MealRecord) {
        occurredAt = meal.occurredAt
        mealTypeRawValue = meal.mealType?.rawValue
        note = meal.note
        photoIDs = meal.photoIDs
        dishLogIDs = meal.dishLogIDs
        updatedAt = meal.updatedAt
    }

    convenience init(from meal: MealRecord) {
        self.init(
            id: meal.id,
            occurredAt: meal.occurredAt,
            mealTypeRawValue: meal.mealType?.rawValue,
            note: meal.note,
            photoIDs: meal.photoIDs,
            dishLogIDs: meal.dishLogIDs,
            createdAt: meal.createdAt,
            updatedAt: meal.updatedAt
        )
    }
}
