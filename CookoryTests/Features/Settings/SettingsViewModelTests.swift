import Foundation
import Testing
@testable import Cookory

@MainActor
struct SettingsViewModelTests {
    private func make(
        meals: InMemoryMealRecordRepository = InMemoryMealRecordRepository(),
        storage: InMemoryImageStorage = InMemoryImageStorage()
    ) -> SettingsViewModel {
        SettingsViewModel(
            exportData: ExportDataUseCase(
                mealRepository: meals,
                dishRepository: InMemoryDishRepository(),
                imageStorage: storage
            )
        )
    }

    @Test func 初期状態はidle() {
        #expect(make().exportState == .idle)
    }

    @Test func 書き出すとファイルができる() async throws {
        let viewModel = make()

        await viewModel.export()

        let url = try #require(viewModel.exportedFile)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test func 記録が無くても書き出せる() async {
        let viewModel = make()

        await viewModel.export()

        #expect(viewModel.exportedFile != nil)
    }

    @Test func 書き出し後に閉じるとidleに戻る() async {
        let viewModel = make()
        await viewModel.export()

        viewModel.dismissExport()

        #expect(viewModel.exportState == .idle)
        #expect(viewModel.exportedFile == nil)
    }

    /// バージョンはビルド設定から取る。直書きすると更新のたびに直し忘れる。
    @Test func バージョンがビルド設定から取れる() {
        let viewModel = make()

        #expect(!viewModel.version.isEmpty)
        #expect(viewModel.version.contains("("))
    }

    @Test func 書き出しに失敗するとメッセージが入る() async {
        let meals = InMemoryMealRecordRepository()
        await meals.setError(.persistenceFailed)
        let viewModel = make(meals: meals)

        await viewModel.export()

        guard case .failed(let message) = viewModel.exportState else {
            Issue.record("failed になっていません")
            return
        }
        #expect(!String(localized: message).contains("DomainError"))
    }
}

@MainActor
struct AppTabTests {
    /// Memory は Phase 1.1。MVP のタブには含めない。
    @Test func MVPのタブは4つ() {
        #expect(AppTab.allCases.count == 4)
        #expect(!AppTab.allCases.map(\.rawValue).contains("memory"))
    }

    /// タブごとに独立した Router を持たないと、あるタブで開いた詳細が
    /// 別のタブにも現れる。
    @Test func タブごとに独立したRouterを持つ() {
        let routers = AppRouter.perTab()

        #expect(routers.count == AppTab.allCases.count)

        routers[.home]?.push(.settings)

        #expect(routers[.home]?.path.count == 1)
        #expect(routers[.calendar]?.path.isEmpty == true)
    }

    @Test func すべてのタブに表示名とアイコンがある() {
        for tab in AppTab.allCases {
            #expect(!String(localized: tab.title).isEmpty)
            #expect(!tab.systemImage.isEmpty)
        }
    }
}
