import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import Testing
import UniformTypeIdentifiers
@testable import Cookory

struct ShareDishUseCaseTests {
    private func make() -> (ShareDishUseCase, InMemoryDishRepository, InMemoryMealRecordRepository, InMemoryImageStorage) {
        let dishes = InMemoryDishRepository()
        let meals = InMemoryMealRecordRepository()
        let storage = InMemoryImageStorage()
        let history = GetDishHistoryUseCase(dishRepository: dishes, mealRepository: meals)
        return (
            ShareDishUseCase(getDishHistory: history, imageStorage: storage),
            dishes, meals, storage
        )
    }

    private func name(_ raw: String) throws -> DishName {
        try #require(DishName(raw))
    }

    /// 共有画像は 9:16。ストーリーズでトリミングされないこと。
    @Test func 生成された画像は1080x1920() async throws {
        let (useCase, dishes, _, _) = make()
        let dish = Dish(name: try name("唐揚げ"))
        try await dishes.save(dish)

        let data = try await useCase.execute(dishID: dish.id)
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))

        #expect(image.width == Int(ShareImageRenderer.width))
        #expect(image.height == Int(ShareImageRenderer.height))
    }

    @Test func 写真が無くても生成できる() async throws {
        let (useCase, dishes, _, _) = make()
        let dish = Dish(name: try name("唐揚げ"))
        try await dishes.save(dish)

        #expect(try await useCase.execute(dishID: dish.id).count > 0)
    }

    /// 写真が読めなくても共有できる。文字だけの画像になる。
    @Test func 写真の読み出しに失敗しても生成できる() async throws {
        let (useCase, dishes, meals, storage) = make()
        let dish = Dish(name: try name("唐揚げ"))
        try await dishes.save(dish)
        let meal = MealRecord(occurredAt: Date()).addingPhoto(UUID())
        try await meals.save(meal)
        try await dishes.save(
            DishLog(dishID: dish.id, mealRecordID: meal.id, cookedAt: Date())
        )
        await storage.setError(.imageStorageFailed)

        #expect(try await useCase.execute(dishID: dish.id).count > 0)
    }

    @Test func 存在しない料理は失敗する() async throws {
        let (useCase, _, _, _) = make()
        let missingID = UUID()

        await #expect(throws: DomainError.notFound(id: missingID)) {
            try await useCase.execute(dishID: missingID)
        }
    }

    // MARK: - 文言

    /// 数字をそのまま出さず物語にする。
    @Test func 初回は回数を出さない() throws {
        let dish = Dish(name: try name("唐揚げ"))
        let history = DishHistory(dish: dish, entries: [
            DishHistoryEntry(
                log: DishLog(dishID: dish.id, mealRecordID: UUID(), cookedAt: Date()),
                photoID: nil
            ),
        ])

        #expect(ShareDishUseCase.headline(for: history) == "はじめて作りました")
    }

    @Test func 複数回なら回数を出す() throws {
        let dish = Dish(name: try name("唐揚げ"))
        let entries = (0..<3).map { _ in
            DishHistoryEntry(
                log: DishLog(dishID: dish.id, mealRecordID: UUID(), cookedAt: Date()),
                photoID: nil
            )
        }

        #expect(ShareDishUseCase.headline(for: DishHistory(dish: dish, entries: entries))
            == "3回 作りました")
    }

    @Test func 履歴が無くても破綻しない() throws {
        let dish = Dish(name: try name("唐揚げ"))
        let history = DishHistory(dish: dish, entries: [])

        #expect(!ShareDishUseCase.headline(for: history).isEmpty)
        #expect(ShareDishUseCase.subline(for: history) == nil)
    }

    @Test func 評価とメモが添えられる() throws {
        let dish = Dish(name: try name("唐揚げ"))
        let history = DishHistory(dish: dish, entries: [
            DishHistoryEntry(
                log: DishLog(
                    dishID: dish.id, mealRecordID: UUID(),
                    rating: DishRating(4), note: "片栗粉多め", cookedAt: Date()
                ),
                photoID: nil
            ),
        ])

        let subline = try #require(ShareDishUseCase.subline(for: history))
        #expect(subline.contains("★★★★"))
        #expect(subline.contains("片栗粉多め"))
    }

    @Test func 評価もメモも無ければ空になる() throws {
        let dish = Dish(name: try name("唐揚げ"))
        let history = DishHistory(dish: dish, entries: [
            DishHistoryEntry(
                log: DishLog(dishID: dish.id, mealRecordID: UUID(), cookedAt: Date()),
                photoID: nil
            ),
        ])

        #expect(ShareDishUseCase.subline(for: history) == nil)
    }

    /// 写真を歪ませない。短辺を合わせて中央を切り出す。
    @Test func 写真は縦横比を保って矩形を覆う() {
        let target = CGRect(x: 0, y: 0, width: 100, height: 200)

        let wide = ShareImageRenderer.aspectFillRect(
            imageSize: CGSize(width: 400, height: 200), in: target
        )

        #expect(wide.height == 200)
        #expect(wide.width >= 100)
        #expect(abs(wide.midX - target.midX) < 0.01)
    }
}

@MainActor
struct AppSettingsTests {
    private func makeDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        return defaults
    }

    @Test func 既定は端末設定に従う() {
        let settings = AppSettings(defaults: makeDefaults())

        #expect(settings.theme == .system)
        #expect(settings.language == .system)
        #expect(settings.theme.colorScheme == nil)
        #expect(settings.language.locale == nil)
    }

    @Test func テーマが保存される() {
        let defaults = makeDefaults()
        AppSettings(defaults: defaults).theme = .dark

        #expect(AppSettings(defaults: defaults).theme == .dark)
    }

    @Test func 言語が保存される() {
        let defaults = makeDefaults()
        AppSettings(defaults: defaults).language = .english

        #expect(AppSettings(defaults: defaults).language == .english)
    }

    @Test func ダークを選ぶとcolorSchemeが返る() {
        let settings = AppSettings(defaults: makeDefaults())
        settings.theme = .dark

        #expect(settings.theme.colorScheme == .dark)
    }

    /// 言語を変えると L10n の解決先も切り替わる。
    @Test func 言語を変えるとロケールが切り替わる() {
        let settings = AppSettings(defaults: makeDefaults())

        settings.language = .english
        #expect(l10nOverrideLocale?.identifier == "en_US")

        settings.language = .system
        #expect(l10nOverrideLocale == nil)
    }

    @Test func すべてのテーマと言語に表示名がある() {
        for mode in AppThemeMode.allCases {
            #expect(!String(localized: mode.label).isEmpty)
        }
        for language in AppLanguage.allCases {
            #expect(!String(localized: language.label).isEmpty)
        }
    }
}
