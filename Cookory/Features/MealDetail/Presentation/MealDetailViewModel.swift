import Foundation
import Observation

@MainActor
@Observable
final class MealDetailViewModel {
    enum State: Equatable {
        case loading
        case loaded(MealDetail)
        case failed(LocalizedStringResource)
    }

    private(set) var state: State = .loading
    private(set) var errorMessage: LocalizedStringResource?

    /// 入力中の値。保存するまで記録には反映しない。
    var noteDraft: String = ""
    var mealTypeDraft: MealType?
    var dishNameDraft: String = ""

    /// レシピ欄を開いている料理。同時に 1 品だけ開く。
    private(set) var expandedDishID: UUID?

    private var recipeDrafts: [UUID: DishRecipeDraft] = [:]

    /// 書き換え中の料理名。保存済みの名前と違うものだけを持つ。
    private var dishNameDrafts: [UUID: String] = [:]

    private let mealID: UUID
    private let getMealDetail: GetMealDetailUseCase
    private let updateMealRecord: UpdateMealRecordUseCase
    private let assignDishToMeal: AssignDishToMealUseCase
    private let deleteMealRecord: DeleteMealRecordUseCase
    private let editRecipe: EditRecipeUseCase
    private let removeDishFromMeal: RemoveDishFromMealUseCase

    init(
        mealID: UUID,
        getMealDetail: GetMealDetailUseCase,
        updateMealRecord: UpdateMealRecordUseCase,
        assignDishToMeal: AssignDishToMealUseCase,
        deleteMealRecord: DeleteMealRecordUseCase,
        editRecipe: EditRecipeUseCase,
        removeDishFromMeal: RemoveDishFromMealUseCase
    ) {
        self.mealID = mealID
        self.getMealDetail = getMealDetail
        self.updateMealRecord = updateMealRecord
        self.assignDishToMeal = assignDishToMeal
        self.deleteMealRecord = deleteMealRecord
        self.editRecipe = editRecipe
        self.removeDishFromMeal = removeDishFromMeal
    }

    var detail: MealDetail? {
        guard case .loaded(let detail) = state else { return nil }
        return detail
    }

    /// 入力欄に出す文字数の上限。Domain の制約と揃える。
    var dishNameLimit: Int { DishName.maxLength }

    var canAddDish: Bool {
        DishName(dishNameDraft) != nil
    }

    /// 保存されていない変更があるか。保存ボタンの有効・無効に使う。
    var hasUnsavedChanges: Bool {
        noteDraft != (detail?.meal.note ?? "")
            || recipeDrafts.values.contains { $0.isDirty }
            || !dishNameDrafts.isEmpty
    }

    /// 書き換え中の料理名。触っていなければ保存済みの名前をそのまま返す。
    func dishName(for dishID: UUID) -> String {
        dishNameDrafts[dishID]
            ?? detail?.dishes.first { $0.dish.id == dishID }?.dish.name.value
            ?? ""
    }

    func setDishName(_ name: String, for dishID: UUID) {
        let saved = detail?.dishes.first { $0.dish.id == dishID }?.dish.name.value
        // 元に戻したら下書きを捨てる。空の変更で保存ボタンが有効にならないように。
        if name == saved {
            dishNameDrafts.removeValue(forKey: dishID)
        } else {
            dishNameDrafts[dishID] = name
        }
    }

    /// 名前として成立しない入力のまま保存させない。
    func canSaveDishName(for dishID: UUID) -> Bool {
        dishNameDrafts[dishID].map { DishName($0) != nil } ?? true
    }

    func load() async {
        do {
            let detail = try await getMealDetail.execute(id: mealID)
            state = .loaded(detail)
            // 入力欄に現在値を出す。読み込みのたびに書きかけを消さないよう
            // 初回だけ反映する。
            if noteDraft.isEmpty { noteDraft = detail.meal.note ?? "" }
            if mealTypeDraft == nil { mealTypeDraft = detail.meal.mealType }
            errorMessage = nil
        } catch {
            state = .failed(L10n.errorLoad)
        }
    }

    /// メモと、書きかけのレシピをまとめて保存する。
    ///
    /// 保存ボタンを 1 つに絞る。料理ごとにボタンがあると、どれを押せば
    /// 何が残るのかが読み取れない。
    func saveAll() async {
        do {
            try await updateMealRecord.updateMeal(
                id: mealID, mealType: mealTypeDraft, note: noteDraft
            )
            for (dishID, name) in dishNameDrafts {
                guard let newName = DishName(name) else {
                    throw DomainError.invalidInput(reason: "料理名が入力されていません")
                }
                try await updateMealRecord.renameDish(id: dishID, to: newName)
            }
            dishNameDrafts.removeAll()
            // 開いただけの料理まで保存すると、書いていないのに更新日時が動く。
            for dishID in recipeDrafts.keys where recipeDraft(for: dishID).isDirty {
                let draft = recipeDraft(for: dishID)
                draft.apply(try await editRecipe.updateContent(
                    dishID: dishID, ingredients: draft.ingredients, steps: draft.steps
                ))
            }
            errorMessage = nil
            await load()
        } catch DomainError.invalidInput(let reason) {
            // 名前の重複や空欄は理由が言える。保存失敗で潰すと直しようがない。
            errorMessage = LocalizedStringResource(stringLiteral: reason)
        } catch {
            errorMessage = L10n.errorSave
        }
    }

    /// 料理名を追加する。同じ名前なら既存の料理に紐づく。
    ///
    /// 追加した料理のレシピ欄をそのまま開く。料理名を書いた直後こそ
    /// 作り方を覚えているため、別画面に移らせない。
    func addDish() async {
        guard let name = DishName(dishNameDraft) else {
            errorMessage = L10n.errorDishNameRequired
            return
        }

        do {
            let log = try await assignDishToMeal.execute(mealRecordID: mealID, dishName: name)
            dishNameDraft = ""
            errorMessage = nil
            await load()
            await expand(dishID: log.dishID)
        } catch {
            errorMessage = L10n.errorGeneric
        }
    }

    /// 記録から料理を外す。打ち間違えたときに記録ごと消さずに済ませる。
    func removeDish(entry: MealDishEntry) async {
        do {
            try await removeDishFromMeal.execute(mealRecordID: mealID, dishLogID: entry.log.id)
            recipeDrafts.removeValue(forKey: entry.dish.id)
            if expandedDishID == entry.dish.id { expandedDishID = nil }
            errorMessage = nil
            await load()
        } catch {
            errorMessage = L10n.errorGeneric
        }
    }

    /// 記録ごと削除する。写真と調理履歴も消える。
    func deleteMeal() async -> Bool {
        do {
            try await deleteMealRecord.execute(id: mealID)
            return true
        } catch {
            errorMessage = L10n.errorGeneric
            return false
        }
    }

    // MARK: - レシピ

    func recipeDraft(for dishID: UUID) -> DishRecipeDraft {
        if let existing = recipeDrafts[dishID] { return existing }
        let draft = DishRecipeDraft()
        recipeDrafts[dishID] = draft
        return draft
    }

    func isExpanded(dishID: UUID) -> Bool {
        expandedDishID == dishID
    }

    func canAddLink(dishID: UUID) -> Bool {
        recipeDraft(for: dishID).canAddLink
    }

    func toggleExpansion(dishID: UUID) async {
        if expandedDishID == dishID {
            expandedDishID = nil
        } else {
            await expand(dishID: dishID)
        }
    }

    func saveRecipe(dishID: UUID) async {
        let draft = recipeDraft(for: dishID)
        do {
            let recipe = try await editRecipe.updateContent(
                dishID: dishID, ingredients: draft.ingredients, steps: draft.steps
            )
            draft.apply(recipe)
            errorMessage = nil
        } catch {
            errorMessage = L10n.errorSave
        }
    }

    func addLink(dishID: UUID) async {
        let draft = recipeDraft(for: dishID)
        do {
            let recipe = try await editRecipe.addLink(
                dishID: dishID, rawURL: draft.linkURL, title: draft.linkTitle
            )
            draft.apply(recipe)
            draft.clearLinkInput()
            errorMessage = nil
        } catch DomainError.invalidInput {
            // Domain の文言は利用者向けではない。表示は Presentation で決める。
            errorMessage = L10n.errorInvalidLink
        } catch {
            errorMessage = L10n.errorGeneric
        }
    }

    /// レシピにスクリーンショットを貼る。
    func addRecipePhotos(dishID: UUID, images: [Data]) async {
        guard !images.isEmpty else { return }
        do {
            recipeDraft(for: dishID).apply(
                try await editRecipe.addPhotos(dishID: dishID, images: images)
            )
            errorMessage = nil
        } catch {
            errorMessage = L10n.errorImageStorage
        }
    }

    func removeRecipePhoto(dishID: UUID, photoID: UUID) async {
        do {
            recipeDraft(for: dishID).apply(
                try await editRecipe.removePhoto(dishID: dishID, photoID: photoID)
            )
            errorMessage = nil
        } catch {
            errorMessage = L10n.errorGeneric
        }
    }

    func removeLink(dishID: UUID, linkID: UUID) async {
        let draft = recipeDraft(for: dishID)
        do {
            draft.apply(try await editRecipe.removeLink(dishID: dishID, linkID: linkID))
            errorMessage = nil
        } catch {
            errorMessage = L10n.errorGeneric
        }
    }

    private func expand(dishID: UUID) async {
        expandedDishID = dishID
        do {
            recipeDraft(for: dishID).apply(try await editRecipe.find(dishID: dishID))
        } catch {
            errorMessage = L10n.errorLoad
        }
    }
}
