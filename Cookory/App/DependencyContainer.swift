import Foundation

/// Composition Root。依存の組み立てはここに集約する。
///
/// DI フレームワークを使わないのは、依存が 3 つしかない段階では
/// 設定コストが得られるものを上回るため（ARCHITECTURE.md #36）。
struct DependencyContainer: Sendable {
    let mealRepository: MealRecordRepository
    let dishRepository: DishRepository
    let imageStorage: ImageStorage
    let calendarMealQuery: CalendarMealQuery
    let cookbookQuery: CookbookQuery
    let searchQuery: SearchQuery

    init(
        mealRepository: MealRecordRepository,
        dishRepository: DishRepository,
        imageStorage: ImageStorage,
        calendarMealQuery: CalendarMealQuery,
        cookbookQuery: CookbookQuery,
        searchQuery: SearchQuery
    ) {
        self.mealRepository = mealRepository
        self.dishRepository = dishRepository
        self.imageStorage = imageStorage
        self.calendarMealQuery = calendarMealQuery
        self.cookbookQuery = cookbookQuery
        self.searchQuery = searchQuery
    }
}

extension DependencyContainer {
    /// 本番構成。ディスクに永続化する。
    static func live() throws -> DependencyContainer {
        let store = try SwiftDataStore.makePersistent()
        return DependencyContainer(
            mealRepository: SwiftDataMealRecordRepository(store: store),
            dishRepository: SwiftDataDishRepository(store: store),
            imageStorage: try LocalImageStorage(),
            calendarMealQuery: SwiftDataCalendarMealQuery(store: store),
            cookbookQuery: SwiftDataCookbookQuery(store: store),
            searchQuery: SwiftDataSearchQuery(store: store)
        )
    }

    /// プレビューとテスト用。プロセス終了で消える。
    ///
    /// 画像だけは実ファイルを書く。SwiftUI プレビューで実際に写真を
    /// 表示できるようにするため、一時ディレクトリへ逃がしている。
    static func inMemory() throws -> DependencyContainer {
        let store = try SwiftDataStore.makeInMemory()
        let imageRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("Cookory-\(UUID().uuidString)", isDirectory: true)
        return DependencyContainer(
            mealRepository: SwiftDataMealRecordRepository(store: store),
            dishRepository: SwiftDataDishRepository(store: store),
            imageStorage: try LocalImageStorage(
                originalsDirectory: imageRoot.appendingPathComponent("originals"),
                thumbnailsDirectory: imageRoot.appendingPathComponent("thumbnails")
            ),
            calendarMealQuery: SwiftDataCalendarMealQuery(store: store),
            cookbookQuery: SwiftDataCookbookQuery(store: store),
            searchQuery: SwiftDataSearchQuery(store: store)
        )
    }
}

extension DependencyContainer {
    var createMealRecord: CreateMealRecordUseCase {
        CreateMealRecordUseCase(mealRepository: mealRepository, imageStorage: imageStorage)
    }

    var exportData: ExportDataUseCase {
        ExportDataUseCase(
            mealRepository: mealRepository,
            dishRepository: dishRepository,
            imageStorage: imageStorage
        )
    }

    var shareDish: ShareDishUseCase {
        ShareDishUseCase(getDishHistory: getDishHistory, imageStorage: imageStorage)
    }

    var getMealDetail: GetMealDetailUseCase {
        GetMealDetailUseCase(mealRepository: mealRepository, dishRepository: dishRepository)
    }

    var editRecipe: EditRecipeUseCase {
        EditRecipeUseCase(dishRepository: dishRepository)
    }

    var getDishHistory: GetDishHistoryUseCase {
        GetDishHistoryUseCase(dishRepository: dishRepository, mealRepository: mealRepository)
    }

    var getHomeContent: GetHomeContentUseCase {
        GetHomeContentUseCase(mealRepository: mealRepository, dishRepository: dishRepository)
    }

    var assignDishToMeal: AssignDishToMealUseCase {
        AssignDishToMealUseCase(mealRepository: mealRepository, dishRepository: dishRepository)
    }

    var updateMealRecord: UpdateMealRecordUseCase {
        UpdateMealRecordUseCase(mealRepository: mealRepository, dishRepository: dishRepository)
    }

    var deleteMealRecord: DeleteMealRecordUseCase {
        DeleteMealRecordUseCase(
            mealRepository: mealRepository,
            dishRepository: dishRepository,
            imageStorage: imageStorage
        )
    }
}
