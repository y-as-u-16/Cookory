import Testing
@testable import Cookory

struct DishNameTests {
    @Test func 空文字は生成に失敗する() {
        #expect(DishName("") == nil)
    }

    @Test func 空白のみは生成に失敗する() {
        #expect(DishName("   ") == nil)
        #expect(DishName("\n\t ") == nil)
    }

    @Test func 前後の空白は取り除かれる() {
        #expect(DishName("  唐揚げ  ")?.value == "唐揚げ")
    }

    @Test func 上限ちょうどは生成できる() {
        let name = String(repeating: "あ", count: DishName.maxLength)
        #expect(DishName(name)?.value == name)
    }

    @Test func 上限を超えると生成に失敗する() {
        #expect(DishName(String(repeating: "あ", count: DishName.maxLength + 1)) == nil)
    }

    @Test func 同じ名前は等価になる() {
        #expect(DishName("唐揚げ") == DishName(" 唐揚げ "))
    }
}
