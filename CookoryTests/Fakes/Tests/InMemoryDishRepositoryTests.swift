import Foundation
import Testing
@testable import Cookory

struct InMemoryDishRepositoryTests {
    private let baseDate = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeDish(_ name: String) -> Dish {
        Dish(name: DishName(name)!)
    }

    private func makeLog(dishID: UUID, mealRecordID: UUID = UUID(), daysAgo: Int = 0) -> DishLog {
        DishLog(
            dishID: dishID,
            mealRecordID: mealRecordID,
            cookedAt: baseDate.addingTimeInterval(-Double(daysAgo) * 86_400)
        )
    }

    @Test func 保存した料理をIDで取得できる() async throws {
        let repository = InMemoryDishRepository()
        let dish = makeDish("唐揚げ")

        try await repository.save(dish)

        #expect(try await repository.find(id: dish.id) == dish)
    }

    @Test func 料理名で検索できる() async throws {
        let dish = makeDish("唐揚げ")
        let repository = InMemoryDishRepository(dishes: [dish, makeDish("カレー")])

        #expect(try await repository.find(name: DishName("唐揚げ")!)?.id == dish.id)
    }

    @Test func 存在しない料理名はnilを返す() async throws {
        let repository = InMemoryDishRepository(dishes: [makeDish("唐揚げ")])

        #expect(try await repository.find(name: DishName("ハンバーグ")!) == nil)
    }

    @Test func 調理履歴は新しい順に返る() async throws {
        let dish = makeDish("唐揚げ")
        let oldest = makeLog(dishID: dish.id, daysAgo: 30)
        let newest = makeLog(dishID: dish.id, daysAgo: 1)
        let middle = makeLog(dishID: dish.id, daysAgo: 10)
        let repository = InMemoryDishRepository(dishes: [dish], logs: [oldest, newest, middle])

        let logs = try await repository.fetchLogs(dishID: dish.id)

        #expect(logs.map(\.id) == [newest.id, middle.id, oldest.id])
    }

    @Test func 別の料理の履歴は混ざらない() async throws {
        let karaage = makeDish("唐揚げ")
        let curry = makeDish("カレー")
        let repository = InMemoryDishRepository(
            dishes: [karaage, curry],
            logs: [makeLog(dishID: karaage.id), makeLog(dishID: curry.id)]
        )

        #expect(try await repository.fetchLogs(dishID: karaage.id).count == 1)
    }

    @Test func 食事記録に紐づく履歴を取得できる() async throws {
        let mealRecordID = UUID()
        let dish = makeDish("唐揚げ")
        let repository = InMemoryDishRepository(
            dishes: [dish],
            logs: [
                makeLog(dishID: dish.id, mealRecordID: mealRecordID),
                makeLog(dishID: dish.id, mealRecordID: UUID()),
            ]
        )

        #expect(try await repository.fetchLogs(mealRecordID: mealRecordID).count == 1)
    }

    @Test func 料理を削除すると紐づく履歴も消える() async throws {
        let dish = makeDish("唐揚げ")
        let other = makeDish("カレー")
        let repository = InMemoryDishRepository(
            dishes: [dish, other],
            logs: [makeLog(dishID: dish.id), makeLog(dishID: other.id)]
        )

        try await repository.delete(id: dish.id)

        #expect(try await repository.fetchLogs(dishID: dish.id).isEmpty)
        #expect(await repository.logCount == 1, "他の料理の履歴まで消してはいけない")
    }

    @Test func 履歴だけを削除しても料理は残る() async throws {
        let dish = makeDish("唐揚げ")
        let log = makeLog(dishID: dish.id)
        let repository = InMemoryDishRepository(dishes: [dish], logs: [log])

        try await repository.deleteLog(id: log.id)

        #expect(try await repository.find(id: dish.id) != nil)
        #expect(await repository.logCount == 0)
    }

    @Test func エラーを注入すると取得が失敗する() async throws {
        let repository = InMemoryDishRepository()
        await repository.setError(.persistenceFailed)

        await #expect(throws: DomainError.persistenceFailed) {
            _ = try await repository.find(id: UUID())
        }
    }
}
