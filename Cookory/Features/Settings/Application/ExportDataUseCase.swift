import Foundation

/// 全データを ZIP に書き出す。
///
/// クラウド同期が無い段階では、端末の紛失でデータが失われる。
/// 利用者が自分のデータを取り出せることを保証する（APP_DESIGN.md #18）。
struct ExportDataUseCase: Sendable {
    /// 一度に読む件数。数千件あっても端末が固まらないようページで回す。
    static let pageSize = 100

    /// 書き出し形式のバージョン。将来インポートを作るとき形式を判別するために使う。
    static let schemaVersion = 1

    private let mealRepository: MealRecordRepository
    private let dishRepository: DishRepository
    private let imageStorage: ImageStorage
    private let fileManager: FileManager

    init(
        mealRepository: MealRecordRepository,
        dishRepository: DishRepository,
        imageStorage: ImageStorage,
        fileManager: FileManager = .default
    ) {
        self.mealRepository = mealRepository
        self.dishRepository = dishRepository
        self.imageStorage = imageStorage
        self.fileManager = fileManager
    }

    /// - Parameter progress: 0.0〜1.0。段階ごとに呼ばれる。
    /// - Returns: 生成された ZIP の URL。共有シートへ渡す。
    func execute(
        progress: @Sendable (Double) -> Void = { _ in }
    ) async throws -> URL {
        let payload = try await buildPayload(progress: progress)
        defer { try? fileManager.removeItem(at: payload.deletingLastPathComponent()) }

        let archive = try ZipArchive.create(from: payload, fileManager: fileManager)
        progress(1.0)

        let destination = fileManager.temporaryDirectory
            .appendingPathComponent("CookoryExport-\(UUID().uuidString).zip")
        try? fileManager.removeItem(at: destination)
        try fileManager.moveItem(at: archive, to: destination)
        return destination
    }

    /// ZIP にまとめる前のディレクトリを作る。中身の検証はここを見る。
    func buildPayload(
        progress: @Sendable (Double) -> Void = { _ in }
    ) async throws -> URL {
        // 作業用ディレクトリで組み立て、成功したときだけ最終位置へ移す。
        // 途中で失敗しても壊れた ZIP を残さない。
        let workspace = fileManager.temporaryDirectory
            .appendingPathComponent("CookoryExport-\(UUID().uuidString)", isDirectory: true)
        let payload = workspace.appendingPathComponent("CookoryExport", isDirectory: true)
        let imagesDirectory = payload.appendingPathComponent("images", isDirectory: true)

        try fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)

        let meals = try await writeMeals(to: payload, imagesDirectory: imagesDirectory, progress: progress)
        progress(0.7)

        let dishCounts = try await writeDishes(to: payload)
        progress(0.85)

        try writeManifest(
            to: payload,
            mealCount: meals.recordCount,
            photoCount: meals.photoCount,
            dishCount: dishCounts.dishes,
            dishLogCount: dishCounts.logs
        )

        progress(0.95)
        return payload
    }

    private func writeMeals(
        to directory: URL,
        imagesDirectory: URL,
        progress: @Sendable (Double) -> Void
    ) async throws -> (recordCount: Int, photoCount: Int) {
        var exported: [ExportedMeal] = []
        var photoCount = 0
        var offset = 0

        while true {
            let page = try await mealRepository.fetchPage(offset: offset, limit: Self.pageSize)
            guard !page.isEmpty else { break }

            for meal in page {
                exported.append(ExportedMeal(meal))
                for photoID in meal.photoIDs {
                    // 1 枚の失敗で書き出し全体を止めない。写真は後から回収できないが、
                    // 記録本体を救うほうが利用者の損失は小さい。
                    guard let data = try? await imageStorage.load(id: photoID) else { continue }
                    try data.write(to: imagesDirectory.appendingPathComponent("\(photoID).jpg"))
                    photoCount += 1
                }
            }

            offset += page.count
            progress(min(0.7, Double(offset) / Double(offset + Self.pageSize) * 0.7))
        }

        try Self.encode(exported, to: directory.appendingPathComponent("meals.json"))
        return (exported.count, photoCount)
    }

    private func writeDishes(to directory: URL) async throws -> (dishes: Int, logs: Int) {
        let dishes = try await dishRepository.fetchAll()
        try Self.encode(dishes.map(ExportedDish.init), to: directory.appendingPathComponent("dishes.json"))

        var logs: [ExportedDishLog] = []
        for dish in dishes {
            logs.append(contentsOf: try await dishRepository.fetchLogs(dishID: dish.id).map(ExportedDishLog.init))
        }
        try Self.encode(logs, to: directory.appendingPathComponent("dish_logs.json"))

        return (dishes.count, logs.count)
    }

    private func writeManifest(
        to directory: URL, mealCount: Int, photoCount: Int, dishCount: Int, dishLogCount: Int
    ) throws {
        try Self.encode(
            ExportManifest(
                schemaVersion: Self.schemaVersion,
                exportedAt: Date(),
                mealCount: mealCount,
                dishCount: dishCount,
                dishLogCount: dishLogCount,
                photoCount: photoCount
            ),
            to: directory.appendingPathComponent("manifest.json")
        )
    }

    private static func encode<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(value).write(to: url)
    }
}
