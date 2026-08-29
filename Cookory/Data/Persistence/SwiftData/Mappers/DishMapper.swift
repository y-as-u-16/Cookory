import Foundation

extension DishModel {
    /// 保存済みの名前が DishName の制約を満たさない場合は失敗させる。
    /// 強制アンラップにすると、検証ルールを厳しくした瞬間に既存データでクラッシュする。
    func toDomain() throws -> Dish {
        guard let dishName = DishName(name) else {
            throw DomainError.invalidInput(reason: "保存された料理名が不正です")
        }
        return Dish(
            id: id,
            name: dishName,
            isFavorite: isFavorite,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func update(from dish: Dish) {
        name = dish.name.value
        isFavorite = dish.isFavorite
        updatedAt = dish.updatedAt
    }

    convenience init(from dish: Dish) {
        self.init(
            id: dish.id,
            name: dish.name.value,
            isFavorite: dish.isFavorite,
            createdAt: dish.createdAt,
            updatedAt: dish.updatedAt
        )
    }
}
