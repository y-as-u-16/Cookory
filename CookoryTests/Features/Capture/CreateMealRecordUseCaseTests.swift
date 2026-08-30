import Foundation
import Testing
@testable import Cookory

struct CreateMealRecordUseCaseTests {
    private func makeUseCase() -> (CreateMealRecordUseCase, InMemoryMealRecordRepository, InMemoryImageStorage) {
        let repository = InMemoryMealRecordRepository()
        let storage = InMemoryImageStorage()
        let useCase = CreateMealRecordUseCase(mealRepository: repository, imageStorage: storage)
        return (useCase, repository, storage)
    }

    private var image: Data { Data("dummy".utf8) }

    @Test func 保存すると写真IDが記録に入る() async throws {
        let (useCase, repository, storage) = makeUseCase()

        let meal = try await useCase.execute(images: [image], occurredAt: Date())

        let photoID = try #require(meal.photoIDs.first)
        #expect(meal.photoIDs.count == 1)
        #expect(await storage.contains(id: photoID))
        #expect(try await repository.find(id: meal.id) != nil)
    }

    @Test func 指定した日時が反映される() async throws {
        let (useCase, _, _) = makeUseCase()
        let occurredAt = Date(timeIntervalSince1970: 1_700_000_000)

        let meal = try await useCase.execute(images: [image], occurredAt: occurredAt)

        #expect(meal.occurredAt == occurredAt)
    }

    /// 写真だけで記録が成立する、という原則の検証。
    @Test func 料理名や評価を渡さなくても成功する() async throws {
        let (useCase, _, _) = makeUseCase()

        let meal = try await useCase.execute(images: [image], occurredAt: Date())

        #expect(meal.mealType == nil)
        #expect(meal.note == nil)
        #expect(meal.dishLogIDs.isEmpty)
    }

    @Test func 画像の保存に失敗したら記録は作られない() async throws {
        let (useCase, repository, storage) = makeUseCase()
        await storage.setError(.imageStorageFailed)

        await #expect(throws: DomainError.imageStorageFailed) {
            try await useCase.execute(images: [image], occurredAt: Date())
        }

        #expect(await repository.count == 0)
    }

    /// 記録が残らないなら、その写真を参照する術がない。孤児として残さない。
    @Test func 記録の保存に失敗したら画像も残さない() async throws {
        let (useCase, repository, storage) = makeUseCase()
        await repository.setError(.persistenceFailed)

        await #expect(throws: DomainError.persistenceFailed) {
            try await useCase.execute(images: [image], occurredAt: Date())
        }

        #expect(await repository.count == 0)
        #expect(await storage.savedCount == 0)
    }

    @Test func 保存した記録はIDで取り出せる() async throws {
        let (useCase, repository, _) = makeUseCase()

        let meal = try await useCase.execute(images: [image], occurredAt: Date())

        #expect(try await repository.find(id: meal.id) == meal)
    }

    @Test func 連続して作成しても記録は独立している() async throws {
        let (useCase, repository, storage) = makeUseCase()

        let first = try await useCase.execute(images: [image], occurredAt: Date())
        let second = try await useCase.execute(images: [image], occurredAt: Date())

        #expect(first.id != second.id)
        #expect(first.photoIDs != second.photoIDs)
        #expect(await repository.count == 2)
        #expect(await storage.savedCount == 2)
    }

    @Test func createdAtに渡した時刻が入る() async throws {
        let (useCase, _, _) = makeUseCase()
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let meal = try await useCase.execute(images: [image], occurredAt: Date(), now: now)

        #expect(meal.createdAt == now)
        #expect(meal.updatedAt == now)
    }
}

/// 複数枚の記録。1 回の食卓に何枚も残せる。
struct CreateMealRecordMultiPhotoTests {
    private func make() -> (CreateMealRecordUseCase, InMemoryMealRecordRepository, InMemoryImageStorage) {
        let repository = InMemoryMealRecordRepository()
        let storage = InMemoryImageStorage()
        return (
            CreateMealRecordUseCase(mealRepository: repository, imageStorage: storage),
            repository, storage
        )
    }

    private func images(_ count: Int) -> [Data] {
        (0..<count).map { Data("photo\($0)".utf8) }
    }

    @Test func 複数枚を1件の記録として保存できる() async throws {
        let (useCase, repository, storage) = make()

        let meal = try await useCase.execute(images: images(3), occurredAt: Date())

        #expect(meal.photoIDs.count == 3)
        #expect(await repository.count == 1)
        #expect(await storage.savedCount == 3)
    }

    @Test func 写真IDは重複しない() async throws {
        let (useCase, _, _) = make()

        let meal = try await useCase.execute(images: images(4), occurredAt: Date())

        #expect(Set(meal.photoIDs).count == 4)
    }

    @Test func 写真が0枚なら失敗する() async throws {
        let (useCase, repository, _) = make()

        await #expect(throws: DomainError.invalidInput(reason: "写真が選択されていません")) {
            try await useCase.execute(images: [], occurredAt: Date())
        }

        #expect(await repository.count == 0)
    }

    /// 途中で失敗したら、それまでに保存した分も取り消す。
    @Test func 記録の保存に失敗したら全ての画像を消す() async throws {
        let (useCase, repository, storage) = make()
        await repository.setError(.persistenceFailed)

        await #expect(throws: DomainError.persistenceFailed) {
            try await useCase.execute(images: self.images(3), occurredAt: Date())
        }

        #expect(await storage.savedCount == 0)
    }
}
