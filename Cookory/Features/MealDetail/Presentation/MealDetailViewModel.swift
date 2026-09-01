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

    private let mealID: UUID
    private let getMealDetail: GetMealDetailUseCase
    private let updateMealRecord: UpdateMealRecordUseCase
    private let assignDishToMeal: AssignDishToMealUseCase
    private let deleteMealRecord: DeleteMealRecordUseCase
    private let editRecipe: EditRecipeUseCase

    init(
        mealID: UUID,
        getMealDetail: GetMealDetailUseCase,
        updateMealRecord: UpdateMealRecordUseCase,
        assignDishToMeal: AssignDishToMealUseCase,
        deleteMealRecord: DeleteMealRecordUseCase,
        editRecipe: EditRecipeUseCase
    ) {
        self.mealID = mealID
        self.getMealDetail = getMealDetail
        self.updateMealRecord = updateMealRecord
        self.assignDishToMeal = assignDishToMeal
        self.deleteMealRecord = deleteMealRecord
        self.editRecipe = editRecipe
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

    /// 食事の種類とメモを保存する。
    func saveMeal() async {
        do {
            try await updateMealRecord.updateMeal(
                id: mealID, mealType: mealTypeDraft, note: noteDraft
            )
            await load()
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

    /// 料理ごとの書きかけ。無ければ作る。
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
