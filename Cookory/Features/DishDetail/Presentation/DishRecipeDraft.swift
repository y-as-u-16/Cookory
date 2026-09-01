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

    /// 貼り付けたスクリーンショット。
    private(set) var photoIDs: [UUID] = []

    /// 最後に取り込んだ保存済みの値。書きかけかどうかの判定に使う。
    private var appliedIngredients = ""
    private var appliedSteps = ""

    var canAddLink: Bool {
        RecipeLink(rawURL: linkURL) != nil
    }

    /// 保存されていない書きかけがあるか。
    var isDirty: Bool {
        ingredients != appliedIngredients || steps != appliedSteps
    }

    /// 折りたたんだ行に「書いてある」ことを示すために使う。
    var hasContent: Bool {
        !ingredients.isEmpty || !steps.isEmpty || !links.isEmpty || !photoIDs.isEmpty
    }

    /// 保存された内容を取り込む。
    ///
    /// 触っていない欄だけ最新値に追従させる。取り込み済みかどうかで判定すると、
    /// 料理図鑑側で書き換えた内容を古い下書きで上書きしてしまう。
    func apply(_ recipe: Recipe) {
        links = recipe.links
        photoIDs = recipe.photoIDs

        let latestIngredients = recipe.ingredients ?? ""
        let latestSteps = recipe.steps ?? ""

        if ingredients == appliedIngredients { ingredients = latestIngredients }
        if steps == appliedSteps { steps = latestSteps }

        appliedIngredients = latestIngredients
        appliedSteps = latestSteps
    }

    func clearLinkInput() {
        linkURL = ""
        linkTitle = ""
    }
}
