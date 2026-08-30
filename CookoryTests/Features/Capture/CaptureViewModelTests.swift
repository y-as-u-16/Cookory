import Foundation
import Testing
@testable import Cookory

@MainActor
struct CaptureViewModelTests {
    private func makeViewModel(
        repository: InMemoryMealRecordRepository = InMemoryMealRecordRepository(),
        storage: InMemoryImageStorage = InMemoryImageStorage()
    ) -> CaptureViewModel {
        CaptureViewModel(
            createMealRecord: CreateMealRecordUseCase(
                mealRepository: repository, imageStorage: storage
            )
        )
    }

    private var image: Data { Data("dummy".utf8) }

    @Test func 初期状態はidle() {
        #expect(makeViewModel().state == .idle)
    }

    @Test func 保存に成功するとsavedになる() async {
        let viewModel = makeViewModel()

        await viewModel.save(images: [image])

        #expect(viewModel.savedRecord != nil)
    }

    @Test func 保存した記録が取り出せる() async {
        let repository = InMemoryMealRecordRepository()
        let viewModel = makeViewModel(repository: repository)
        let occurredAt = Date(timeIntervalSince1970: 1_700_000_000)

        await viewModel.save(images: [image], occurredAt: occurredAt)

        #expect(viewModel.savedRecord?.occurredAt == occurredAt)
        #expect(await repository.count == 1)
    }

    @Test func 画像の保存に失敗するとfailedになる() async {
        let storage = InMemoryImageStorage()
        await storage.setError(.imageStorageFailed)
        let viewModel = makeViewModel(storage: storage)

        await viewModel.save(images: [image])

        #expect(viewModel.state == .failed("写真を保存できませんでした。空き容量をご確認ください。"))
    }

    @Test func 記録の保存に失敗するとfailedになる() async {
        let repository = InMemoryMealRecordRepository()
        await repository.setError(.persistenceFailed)
        let viewModel = makeViewModel(repository: repository)

        await viewModel.save(images: [image])

        #expect(viewModel.state == .failed("記録を保存できませんでした。もう一度お試しください。"))
    }

    /// 内部表現をそのまま見せない。利用者が読んで行動できる文言にする。
    @Test func エラー文言に内部表現が出ない() async {
        let storage = InMemoryImageStorage()
        await storage.setError(.imageStorageFailed)
        let viewModel = makeViewModel(storage: storage)

        await viewModel.save(images: [image])

        guard case .failed(let message) = viewModel.state else {
            Issue.record("failed になっていません")
            return
        }
        #expect(!message.contains("DomainError"))
        #expect(!message.contains("imageStorageFailed"))
    }

    @Test func resetでidleに戻る() async {
        let viewModel = makeViewModel()
        await viewModel.save(images: [image])

        viewModel.reset()

        #expect(viewModel.state == .idle)
    }

    @Test func 失敗後にやり直せる() async {
        let storage = InMemoryImageStorage()
        await storage.setError(.imageStorageFailed)
        let viewModel = makeViewModel(storage: storage)
        await viewModel.save(images: [image])

        viewModel.reset()
        await storage.setError(nil)
        await viewModel.save(images: [image])

        #expect(viewModel.savedRecord != nil)
    }
}

/// 二重送信の検証。保存を途中で止めて、処理中の状態を観測する。
@MainActor
struct CaptureDoubleSubmitTests {
    @Test func 保存中はsavingになる() async {
        let gate = AsyncGate()
        let storage = InMemoryImageStorage()
        await storage.setGate(gate)
        let viewModel = CaptureViewModel(
            createMealRecord: CreateMealRecordUseCase(
                mealRepository: InMemoryMealRecordRepository(), imageStorage: storage
            )
        )

        let task = Task { await viewModel.save(images: [Data("a".utf8)]) }
        await Task.yield()

        #expect(viewModel.isSaving)

        await gate.open()
        await task.value
        #expect(viewModel.savedRecord != nil)
    }

    /// 連打で記録が 2 件できると、利用者は重複に気づかないまま片方だけを編集する。
    @Test func 保存中に二重送信できない() async {
        let gate = AsyncGate()
        let repository = InMemoryMealRecordRepository()
        let storage = InMemoryImageStorage()
        await storage.setGate(gate)
        let viewModel = CaptureViewModel(
            createMealRecord: CreateMealRecordUseCase(
                mealRepository: repository, imageStorage: storage
            )
        )

        let first = Task { await viewModel.save(images: [Data("a".utf8)]) }
        await Task.yield()

        // 保存中に届いた 2 回目。ガードが無いと gate で止まったまま返らないため、
        // 待ち続けずにタスクとして投げて完了を待たない。
        let second = Task { await viewModel.save(images: [Data("b".utf8)]) }
        await Task.yield()

        await gate.open()
        await first.value
        await second.value

        #expect(await repository.count == 1)
        #expect(await storage.savedCount == 1)
    }
}
