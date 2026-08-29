import Foundation
import Testing
@testable import Cookory

struct DishLogTests {
    private let cookedAt = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeLog(rating: DishRating? = nil, note: String? = nil) -> DishLog {
        DishLog(dishID: UUID(), mealRecordID: UUID(), rating: rating, note: note, cookedAt: cookedAt)
    }

    @Test func 評価とメモは省略できる() {
        let log = makeLog()

        #expect(log.rating == nil)
        #expect(log.note == nil)
    }

    @Test func 空白だけのメモはnilになる() {
        #expect(makeLog(note: "  \n ").note == nil)
    }

    @Test func メモの前後の空白は取り除かれる() {
        #expect(makeLog(note: "  片栗粉多め  ").note == "片栗粉多め")
    }

    @Test func 評価を後から付けられる() {
        let log = makeLog().rated(DishRating(5))

        #expect(log.rating == DishRating(5))
    }

    @Test func 評価を取り消せる() {
        let log = makeLog(rating: DishRating(3)).rated(nil)

        #expect(log.rating == nil)
    }

    @Test func 同じ料理の複数回の記録は別物として扱われる() {
        let dishID = UUID()
        let first = DishLog(dishID: dishID, mealRecordID: UUID(), cookedAt: cookedAt)
        let second = DishLog(dishID: dishID, mealRecordID: UUID(), cookedAt: cookedAt)

        #expect(first != second)
        #expect(first.dishID == second.dishID)
    }
}
