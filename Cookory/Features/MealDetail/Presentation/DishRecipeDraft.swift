import Foundation
import Observation

/// 記録画面で 1 品ぶんのレシピを書きかけのまま保持する。
///
/// 画面ではなく料理ごとに状態を持つのは、1 回の食卓に複数の料理を
/// 続けて入力するため。折りたたんでも書きかけを失わない。
@MainActor
@Observable
final class DishRecipeDraft {
    var ingredients: String = ""
    var steps: String = ""
    var linkURL: String = ""
    var linkTitle: String = ""

    private(set) var links: [RecipeLink] = []

    /// 保存済みの内容を反映済みか。書きかけを上書きしないための番人。
    private(set) var isLoaded = false

    var canAddLink: Bool {
        RecipeLink(rawURL: linkURL) != nil
    }

    /// 保存された内容を取り込む。書きかけがあるときは本文に触れない。
    func apply(_ recipe: Recipe) {
        links = recipe.links
        guard !isLoaded else { return }
        ingredients = recipe.ingredients ?? ""
        steps = recipe.steps ?? ""
        isLoaded = true
    }

    func clearLinkInput() {
        linkURL = ""
        linkTitle = ""
    }
}
