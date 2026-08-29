import Testing
@testable import Cookory

struct DishRatingTests {
    @Test func 範囲内の値は生成できる() {
        #expect(DishRating(1)?.value == 1)
        #expect(DishRating(5)?.value == 5)
    }

    @Test(arguments: [0, 6, -1, 100])
    func 範囲外は生成に失敗する(_ invalid: Int) {
        #expect(DishRating(invalid) == nil)
    }

    @Test func 評価は大小を比較できる() {
        #expect(DishRating(2)! < DishRating(4)!)
    }
}
