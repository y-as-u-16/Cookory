import Foundation
import Testing
@testable import Cookory

struct DishTests {
    private let name = DishName("唐揚げ")!

    @Test func 初期状態はお気に入りではない() {
        #expect(Dish(name: name).isFavorite == false)
    }

    @Test func 生成直後はcreatedAtとupdatedAtが一致する() {
        let created = Date(timeIntervalSince1970: 1_000)
        let dish = Dish(name: name, createdAt: created)

        #expect(dish.createdAt == dish.updatedAt)
    }

    @Test func 改名してもcreatedAtは変わらない() {
        let created = Date(timeIntervalSince1970: 1_000)
        let renamedAt = Date(timeIntervalSince1970: 2_000)
        let dish = Dish(name: name, createdAt: created)
            .renamed(to: DishName("鶏の唐揚げ")!, at: renamedAt)

        #expect(dish.createdAt == created)
        #expect(dish.updatedAt == renamedAt)
        #expect(dish.name.value == "鶏の唐揚げ")
    }

    @Test func お気に入りは切り替えられる() {
        let dish = Dish(name: name).favoriteToggled()

        #expect(dish.isFavorite)
        #expect(dish.favoriteToggled().isFavorite == false)
    }
}
