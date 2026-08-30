import Foundation

/// 料理の記録を SNS 共有用の画像にする。
///
/// 数字をそのまま出さず、物語として見せる。「12」ではなく
/// 「12回作りました」、「3日前」ではなく「最後に作ったのは3日前」。
struct ShareDishUseCase: Sendable {
    private let getDishHistory: GetDishHistoryUseCase
    private let imageStorage: ImageStorage
    private let renderer: ShareImageRenderer

    init(
        getDishHistory: GetDishHistoryUseCase,
        imageStorage: ImageStorage,
        renderer: ShareImageRenderer = ShareImageRenderer()
    ) {
        self.getDishHistory = getDishHistory
        self.imageStorage = imageStorage
        self.renderer = renderer
    }

    /// - Returns: 共有シートへ渡す PNG。
    func execute(dishID: UUID) async throws -> Data {
        let history = try await getDishHistory.execute(dishID: dishID)

        // 写真が読めなくても共有はできる。文字だけの画像になる。
        let photo = await history.latestPhotoID.flatMap { id in
            try? await imageStorage.load(id: id)
        }

        return try renderer.render(ShareImageRenderer.Content(
            dishName: history.dish.name.value,
            headline: Self.headline(for: history),
            subline: Self.subline(for: history),
            photo: photo
        ))
    }

    /// 回数を物語にする。1 回目は「はじめて作った」と伝えるほうが自然。
    static func headline(for history: DishHistory) -> String {
        switch history.cookCount {
        case 0: "これから作ります"
        case 1: "はじめて作りました"
        default: "\(history.cookCount)回 作りました"
        }
    }

    /// 最新の評価とメモがあれば添える。無ければ日付だけ。
    static func subline(for history: DishHistory) -> String? {
        guard let entry = history.entries.first else { return nil }

        var parts: [String] = []
        if let rating = entry.log.rating {
            parts.append(String(repeating: "★", count: rating.value))
        }
        if let note = entry.log.note {
            parts.append(note)
        }

        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: "  ")
    }
}

private extension Optional {
    /// Optional に対して async な変換をかける。
    func flatMap<T>(_ transform: (Wrapped) async -> T?) async -> T? {
        guard let self else { return nil }
        return await transform(self)
    }
}
