import Foundation
import Testing
@testable import Cookory

struct ExportDataUseCaseTests {
    private func make() -> (ExportDataUseCase, InMemoryMealRecordRepository, InMemoryDishRepository, InMemoryImageStorage) {
        let meals = InMemoryMealRecordRepository()
        let dishes = InMemoryDishRepository()
        let storage = InMemoryImageStorage()
        return (
            ExportDataUseCase(
                mealRepository: meals, dishRepository: dishes, imageStorage: storage
            ),
            meals, dishes, storage
        )
    }

    private func name(_ raw: String) throws -> DishName {
        try #require(DishName(raw))
    }

    /// ZIP にまとめる前のディレクトリを検証する。iOS では Process が使えず
    /// テスト内で展開できないため、中身は payload を直接見る。
    private func payload(of useCase: ExportDataUseCase) async throws -> URL {
        try await useCase.buildPayload()
    }

    private func decode<T: Decodable>(_ type: T.Type, at url: URL) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: try Data(contentsOf: url))
    }

    @Test func ZIPが生成される() async throws {
        let (useCase, meals, _, _) = make()
        try await meals.save(MealRecord(occurredAt: Date()))

        let archive = try await useCase.execute()

        #expect(FileManager.default.fileExists(atPath: archive.path))
        #expect(archive.pathExtension == "zip")
    }

    /// 記録が無くてもエラーにしない。初回起動直後でも書き出せる。
    @Test func 記録0件でもエラーにならない() async throws {
        let (useCase, _, _, _) = make()

        let root = try await payload(of: useCase)
        let manifest = try decode(
            ExportManifest.self, at: root.appendingPathComponent("manifest.json")
        )

        #expect(manifest.mealCount == 0)
        #expect(manifest.dishCount == 0)
    }

    @Test func JSONが仕様通りの構造になる() async throws {
        let (useCase, meals, dishes, _) = make()
        let meal = MealRecord(occurredAt: Date(), mealType: .dinner, note: "美味しかった")
        try await meals.save(meal)
        let dish = Dish(name: try name("唐揚げ"))
        try await dishes.save(dish)
        try await dishes.save(DishLog(
            dishID: dish.id, mealRecordID: meal.id,
            rating: DishRating(5), note: "片栗粉多め", cookedAt: Date()
        ))

        let root = try await payload(of: useCase)

        let exportedMeals = try decode(
            [ExportedMeal].self, at: root.appendingPathComponent("meals.json")
        )
        #expect(exportedMeals.count == 1)
        #expect(exportedMeals.first?.mealType == "dinner")
        #expect(exportedMeals.first?.note == "美味しかった")

        let exportedDishes = try decode(
            [ExportedDish].self, at: root.appendingPathComponent("dishes.json")
        )
        #expect(exportedDishes.first?.name == "唐揚げ")

        let exportedLogs = try decode(
            [ExportedDishLog].self, at: root.appendingPathComponent("dish_logs.json")
        )
        #expect(exportedLogs.first?.rating == 5)
        #expect(exportedLogs.first?.note == "片栗粉多め")
    }

    @Test func manifestにスキーマバージョンが入る() async throws {
        let (useCase, _, _, _) = make()

        let root = try await payload(of: useCase)
        let manifest = try decode(
            ExportManifest.self, at: root.appendingPathComponent("manifest.json")
        )

        #expect(manifest.schemaVersion == ExportDataUseCase.schemaVersion)
    }

    @Test func 画像が全て含まれる() async throws {
        let (useCase, meals, _, storage) = make()
        var meal = MealRecord(occurredAt: Date())
        for _ in 0..<3 {
            let asset = try await storage.save(Data("photo".utf8))
            meal = meal.addingPhoto(asset.id)
        }
        try await meals.save(meal)

        let root = try await payload(of: useCase)
        let images = try FileManager.default.contentsOfDirectory(
            at: root.appendingPathComponent("images"), includingPropertiesForKeys: nil
        )

        #expect(images.count == 3)
    }

    @Test func 件数がmanifestに反映される() async throws {
        let (useCase, meals, dishes, _) = make()
        for _ in 0..<5 {
            try await meals.save(MealRecord(occurredAt: Date()))
        }
        let dish = Dish(name: try name("唐揚げ"))
        try await dishes.save(dish)
        for _ in 0..<2 {
            try await dishes.save(
                DishLog(dishID: dish.id, mealRecordID: UUID(), cookedAt: Date())
            )
        }

        let root = try await payload(of: useCase)
        let manifest = try decode(
            ExportManifest.self, at: root.appendingPathComponent("manifest.json")
        )

        #expect(manifest.mealCount == 5)
        #expect(manifest.dishCount == 1)
        #expect(manifest.dishLogCount == 2)
    }

    /// ページ境界をまたいでも全件が出る。ここを間違えると静かにデータが欠ける。
    @Test func ページサイズを超える件数でも全件書き出せる() async throws {
        let (useCase, meals, _, _) = make()
        let total = ExportDataUseCase.pageSize + 37
        for index in 0..<total {
            try await meals.save(
                MealRecord(occurredAt: Date(timeIntervalSince1970: Double(index) * 3600))
            )
        }

        let root = try await payload(of: useCase)
        let exported = try decode(
            [ExportedMeal].self, at: root.appendingPathComponent("meals.json")
        )

        #expect(exported.count == total)
        #expect(Set(exported.map(\.id)).count == total)
    }

    @Test func 進捗が最後に1になる() async throws {
        let (useCase, meals, _, _) = make()
        try await meals.save(MealRecord(occurredAt: Date()))
        let recorder = ProgressRecorder()

        _ = try await useCase.execute { recorder.record($0) }

        #expect(await recorder.last == 1.0)
        #expect(await recorder.isMonotonic)
    }

    /// 写真 1 枚の失敗で書き出し全体を止めない。記録本体を救うほうが損失が小さい。
    @Test func 画像の読み出しに失敗しても記録は書き出される() async throws {
        let (useCase, meals, _, storage) = make()
        try await meals.save(MealRecord(occurredAt: Date()).addingPhoto(UUID()))
        await storage.setError(.imageStorageFailed)

        let root = try await payload(of: useCase)
        let exported = try decode(
            [ExportedMeal].self, at: root.appendingPathComponent("meals.json")
        )

        #expect(exported.count == 1)
    }
}

/// 進捗の記録用。順序が単調であることを確認する。
private actor ProgressRecorderStorage {
    var values: [Double] = []
    func append(_ value: Double) { values.append(value) }
}

private final class ProgressRecorder: @unchecked Sendable {
    private let storage = ProgressRecorderStorage()

    func record(_ value: Double) {
        Task { await storage.append(value) }
    }

    var last: Double? {
        get async {
            // Task の完了を待つ。
            try? await Task.sleep(for: .milliseconds(50))
            return await storage.values.last
        }
    }

    var isMonotonic: Bool {
        get async {
            let values = await storage.values
            return zip(values, values.dropFirst()).allSatisfy { $0 <= $1 }
        }
    }
}
