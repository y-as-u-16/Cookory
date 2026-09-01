import Foundation

/// 料理の作り方。Dish に 1 つだけ紐づく。
///
/// 1 回ごと（DishLog）ではなく料理に持たせる。「唐揚げの作り方」は
/// 作るたびに変わるものではなく、変わったときに書き換えるものだから。
/// 個々の調整は DishLog のメモが受け持つ。
struct Recipe: Identifiable, Hashable, Sendable {
    let id: UUID

    /// 紐づく料理。Recipe は Dish なしでは存在しない。
    let dishID: UUID

    /// 材料。1 行 1 材料を想定するが、書き方は利用者に委ねる。
    var ingredients: String?

    /// 手順。
    var steps: String?

    /// 参考にした動画やページ。
    private(set) var links: [RecipeLink]

    /// 貼り付けたスクリーンショット。Web やアプリで見つけたレシピを
    /// 文字に起こし直さず、リンク切れにも備えて残せるようにする。
    private(set) var photoIDs: [UUID]

    let createdAt: Date
    private(set) var updatedAt: Date

    init(
        id: UUID = UUID(),
        dishID: UUID,
        ingredients: String? = nil,
        steps: String? = nil,
        links: [RecipeLink] = [],
        photoIDs: [UUID] = [],
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.dishID = dishID
        self.ingredients = ingredients?.normalizedOrNil
        self.steps = steps?.normalizedOrNil
        self.links = links
        self.photoIDs = photoIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    /// 何も書かれていない状態。空のレシピを保存し続けないための判定に使う。
    var isEmpty: Bool {
        ingredients == nil && steps == nil && links.isEmpty && photoIDs.isEmpty
    }

    func edited(ingredients: String?, steps: String?, at date: Date = Date()) -> Recipe {
        var copy = self
        copy.ingredients = ingredients?.normalizedOrNil
        copy.steps = steps?.normalizedOrNil
        copy.updatedAt = date
        return copy
    }

    func addingLink(_ link: RecipeLink, at date: Date = Date()) -> Recipe {
        guard !links.contains(where: { $0.url == link.url }) else { return self }
        var copy = self
        copy.links.append(link)
        copy.updatedAt = date
        return copy
    }

    func removingLink(id linkID: UUID, at date: Date = Date()) -> Recipe {
        guard links.contains(where: { $0.id == linkID }) else { return self }
        var copy = self
        copy.links.removeAll { $0.id == linkID }
        copy.updatedAt = date
        return copy
    }

    func addingPhotos(_ ids: [UUID], at date: Date = Date()) -> Recipe {
        let additions = ids.filter { !photoIDs.contains($0) }
        guard !additions.isEmpty else { return self }
        var copy = self
        copy.photoIDs.append(contentsOf: additions)
        copy.updatedAt = date
        return copy
    }

    func removingPhoto(id photoID: UUID, at date: Date = Date()) -> Recipe {
        guard photoIDs.contains(photoID) else { return self }
        var copy = self
        copy.photoIDs.removeAll { $0 == photoID }
        copy.updatedAt = date
        return copy
    }
}
