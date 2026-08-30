import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Cookory

struct DependencyContainerTests {
    @Test func テスト構成が組み立てられる() throws {
        _ = try DependencyContainer.inMemory()
    }

    /// 組み立てた依存が実際に繋がっているか。型が合うだけでは不十分。
    @Test func テスト構成で記録を保存して取り出せる() async throws {
        let container = try DependencyContainer.inMemory()
        let meal = MealRecord(occurredAt: Date())

        try await container.mealRepository.save(meal)

        #expect(try await container.mealRepository.find(id: meal.id) == meal)
    }

    @Test func テスト構成は毎回独立している() async throws {
        let first = try DependencyContainer.inMemory()
        let second = try DependencyContainer.inMemory()
        let meal = MealRecord(occurredAt: Date())

        try await first.mealRepository.save(meal)

        #expect(try await second.mealRepository.find(id: meal.id) == nil)
    }

    /// UseCase が Container の依存を使って組み立てられているか。
    @Test func UseCaseが依存を共有している() async throws {
        let container = try DependencyContainer.inMemory()

        let meal = try await container.createMealRecord.execute(
            images: [makeJPEG()], occurredAt: Date()
        )

        #expect(try await container.mealRepository.find(id: meal.id) != nil)
    }

    /// 2 つの Repository が同じ Store を共有しているか。別々の Store を渡すと、
    /// 料理に紐づけた履歴が食事記録側から見えなくなる。
    @Test func ふたつのRepositoryは同じ保存先を見る() async throws {
        let container = try DependencyContainer.inMemory()
        let dish = Dish(name: try #require(DishName("唐揚げ")))
        let log = DishLog(dishID: dish.id, mealRecordID: UUID(), cookedAt: Date())

        try await container.dishRepository.save(dish)
        try await container.dishRepository.save(log)

        #expect(try await container.dishRepository.fetchLogs(dishID: dish.id).count == 1)
    }

    private func makeJPEG() -> Data {
        let context = CGContext(
            data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )!
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        let output = NSMutableData()
        let destination = CGImageDestinationCreateWithData(
            output, UTType.jpeg.identifier as CFString, 1, nil
        )!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        CGImageDestinationFinalize(destination)
        return output as Data
    }
}
