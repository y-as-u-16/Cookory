import Foundation
import Testing
@testable import Cookory

struct SwiftDataCookbookQueryTests {
    private func make() throws -> (SwiftDataCookbookQuery, SwiftDataDishRepository, SwiftDataMealRecordRepository) {
        let store = try SwiftDataStore.makeInMemory()
        return (
            SwiftDataCookbookQuery(store: store),
            SwiftDataDishRepository(store: store),
            SwiftDataMealRecordRepository(store: store)
        )
    }

    private func name(_ raw: String) throws -> DishName {
        try #require(DishName(raw))
    }

    private var base: Date { Date(timeIntervalSince1970: 1_700_000_000) }

    private func daysAgo(_ days: Int) -> Date {
        base.addingTimeInterval(-Double(days) * 86_400)
    }

    /// 料理を1件と、指定回数の履歴を作る。
    @discardableResult
    private func seed(
        _ dishes: SwiftDataDishRepository,
        name dishName: String,
        cookedAt dates: [Date],
        isFavorite: Bool = false
    ) async throws -> Dish {
        var dish = Dish(name: try name(dishName))
        if isFavorite { dish = dish.favoriteToggled() }
        try await dishes.save(dish)
        for date in dates {
            try await dishes.save(
                DishLog(dishID: dish.id, mealRecordID: UUID(), cookedAt: date)
            )
        }
        return dish
    }

    @Test func 作った料理だけが並ぶ() async throws {
        let (query, dishes, _) = try make()
        try await seed(dishes, name: "唐揚げ", cookedAt: [daysAgo(1)])
        try await dishes.save(Dish(name: try name("未調理")))

        let items = try await query.items(sort: .name, limit: 50, offset: 0)

        #expect(items.count == 1)
        #expect(items.first?.dish.name.value == "唐揚げ")
    }

    @Test func 調理回数が正確() async throws {
        let (query, dishes, _) = try make()
        try await seed(dishes, name: "唐揚げ", cookedAt: [daysAgo(1), daysAgo(10), daysAgo(30)])

        let items = try await query.items(sort: .name, limit: 50, offset: 0)

        #expect(items.first?.cookCount == 3)
    }

    @Test func 最終調理日が正しい() async throws {
        let (query, dishes, _) = try make()
        try await seed(dishes, name: "カレー", cookedAt: [daysAgo(30), daysAgo(2), daysAgo(10)])

        let items = try await query.items(sort: .name, limit: 50, offset: 0)

        #expect(items.first?.lastCookedAt == daysAgo(2))
    }

    @Test func よく作る順に並ぶ() async throws {
        let (query, dishes, _) = try make()
        try await seed(dishes, name: "A", cookedAt: [daysAgo(1)])
        try await seed(dishes, name: "B", cookedAt: [daysAgo(1), daysAgo(2), daysAgo(3)])
        try await seed(dishes, name: "C", cookedAt: [daysAgo(1), daysAgo(2)])

        let items = try await query.items(sort: .mostCooked, limit: 50, offset: 0)

        #expect(items.map(\.dish.name.value) == ["B", "C", "A"])
    }

    /// 回数が同じなら名前順。並びが実行ごとに変わると探しにくい。
    @Test func 回数が同じなら名前順になる() async throws {
        let (query, dishes, _) = try make()
        try await seed(dishes, name: "ぶり大根", cookedAt: [daysAgo(1)])
        try await seed(dishes, name: "あさり酒蒸し", cookedAt: [daysAgo(2)])

        let items = try await query.items(sort: .mostCooked, limit: 50, offset: 0)

        #expect(items.map(\.dish.name.value) == ["あさり酒蒸し", "ぶり大根"])
    }

    @Test func 最近作った順に並ぶ() async throws {
        let (query, dishes, _) = try make()
        try await seed(dishes, name: "A", cookedAt: [daysAgo(30)])
        try await seed(dishes, name: "B", cookedAt: [daysAgo(1)])

        let items = try await query.items(sort: .recentlyCooked, limit: 50, offset: 0)

        #expect(items.map(\.dish.name.value) == ["B", "A"])
    }

    @Test func 最近作っていない順に並ぶ() async throws {
        let (query, dishes, _) = try make()
        try await seed(dishes, name: "A", cookedAt: [daysAgo(30)])
        try await seed(dishes, name: "B", cookedAt: [daysAgo(1)])

        let items = try await query.items(sort: .notCookedRecently, limit: 50, offset: 0)

        #expect(items.map(\.dish.name.value) == ["A", "B"])
    }

    @Test func お気に入りが先に並ぶ() async throws {
        let (query, dishes, _) = try make()
        try await seed(dishes, name: "A", cookedAt: [daysAgo(1)])
        try await seed(dishes, name: "B", cookedAt: [daysAgo(2)], isFavorite: true)

        let items = try await query.items(sort: .favorite, limit: 50, offset: 0)

        #expect(items.map(\.dish.name.value) == ["B", "A"])
    }

    @Test func 名前順に並ぶ() async throws {
        let (query, dishes, _) = try make()
        try await seed(dishes, name: "Z", cookedAt: [daysAgo(1)])
        try await seed(dishes, name: "A", cookedAt: [daysAgo(2)])

        let items = try await query.items(sort: .name, limit: 50, offset: 0)

        #expect(items.map(\.dish.name.value) == ["A", "Z"])
    }

    /// 料理は年単位で増え続ける。全件をメモリに載せない。
    @Test func limitで件数が制限される() async throws {
        let (query, dishes, _) = try make()
        for index in 0..<5 {
            try await seed(dishes, name: "料理\(index)", cookedAt: [daysAgo(index + 1)])
        }

        #expect(try await query.items(sort: .name, limit: 2, offset: 0).count == 2)
    }

    @Test func offsetで続きを読める() async throws {
        let (query, dishes, _) = try make()
        for index in 0..<5 {
            try await seed(dishes, name: "料理\(index)", cookedAt: [daysAgo(index + 1)])
        }

        let first = try await query.items(sort: .name, limit: 2, offset: 0)
        let second = try await query.items(sort: .name, limit: 2, offset: 2)

        #expect(Set(first.map(\.id)).isDisjoint(with: Set(second.map(\.id))))
        #expect(second.count == 2)
    }

    @Test func limitが0以下なら空を返す() async throws {
        let (query, dishes, _) = try make()
        try await seed(dishes, name: "唐揚げ", cookedAt: [daysAgo(1)])

        #expect(try await query.items(sort: .name, limit: 0, offset: 0).isEmpty)
    }

    @Test func 最新の写真IDが入る() async throws {
        let (query, dishes, meals) = try make()
        let photoID = UUID()
        let meal = MealRecord(occurredAt: daysAgo(1)).addingPhoto(photoID)
        try await meals.save(meal)
        let dish = Dish(name: try name("唐揚げ"))
        try await dishes.save(dish)
        try await dishes.save(
            DishLog(dishID: dish.id, mealRecordID: meal.id, cookedAt: daysAgo(1))
        )

        let items = try await query.items(sort: .name, limit: 50, offset: 0)

        #expect(items.first?.latestPhotoID == photoID)
    }
}

/// レシピの永続化。
struct SwiftDataRecipeTests {
    private func make() throws -> SwiftDataDishRepository {
        SwiftDataDishRepository(store: try SwiftDataStore.makeInMemory())
    }

    @Test func レシピを保存して取り出せる() async throws {
        let dishes = try make()
        let dishID = UUID()
        let link = try #require(RecipeLink(rawURL: "https://example.com", title: "参考"))
        let recipe = Recipe(
            dishID: dishID, ingredients: "鶏もも肉 300g", steps: "1. 下味", links: [link]
        )

        try await dishes.save(recipe)
        let loaded = try #require(try await dishes.findRecipe(dishID: dishID))

        #expect(loaded.ingredients == "鶏もも肉 300g")
        #expect(loaded.steps == "1. 下味")
        #expect(loaded.links.count == 1)
        #expect(loaded.links.first?.title == "参考")
    }

    @Test func 未登録ならnilを返す() async throws {
        let dishes = try make()

        #expect(try await dishes.findRecipe(dishID: UUID()) == nil)
    }

    @Test func 同じ料理に二度保存しても重複しない() async throws {
        let dishes = try make()
        let dishID = UUID()
        try await dishes.save(Recipe(dishID: dishID, ingredients: "初版"))

        try await dishes.save(Recipe(dishID: dishID, ingredients: "改訂版"))

        #expect(try await dishes.findRecipe(dishID: dishID)?.ingredients == "改訂版")
    }

    @Test func レシピを削除できる() async throws {
        let dishes = try make()
        let dishID = UUID()
        try await dishes.save(Recipe(dishID: dishID, ingredients: "材料"))

        try await dishes.deleteRecipe(dishID: dishID)

        #expect(try await dishes.findRecipe(dishID: dishID) == nil)
    }

    /// 料理を消したらレシピも消える。残すと参照されないデータが溜まる。
    @Test func 料理を削除するとレシピも消える() async throws {
        let dishes = try make()
        let dish = Dish(name: try #require(DishName("唐揚げ")))
        try await dishes.save(dish)
        try await dishes.save(Recipe(dishID: dish.id, ingredients: "材料"))

        try await dishes.delete(id: dish.id)

        #expect(try await dishes.findRecipe(dishID: dish.id) == nil)
    }

    @Test func リンクが往復で保たれる() async throws {
        let dishes = try make()
        let dishID = UUID()
        let links = [
            try #require(RecipeLink(rawURL: "https://a.example.com", title: "A")),
            try #require(RecipeLink(rawURL: "https://b.example.com")),
        ]

        try await dishes.save(Recipe(dishID: dishID, links: links))
        let loaded = try #require(try await dishes.findRecipe(dishID: dishID))

        #expect(loaded.links.map(\.url) == links.map(\.url))
        #expect(loaded.links.first?.title == "A")
        #expect(loaded.links.last?.title == nil)
    }

    /// 保存された文字列が壊れていても、読める範囲を返す。
    @Test func 壊れたリンクJSONは空として読む() {
        #expect(RecipeModel.decodeLinks("not json").isEmpty)
        #expect(RecipeModel.decodeLinks(nil).isEmpty)
    }
}
