import Foundation
import Observation

@MainActor
@Observable
final class MealDetailViewModel {
    enum State: Equatable {
        case loading
        case loaded(MealDetail)
        case failed(String)
    }

    private(set) var state: State = .loading
    private(set) var errorMessage: String?

    /// 入力中の値。保存するまで記録には反映しない。
    var noteDraft: String = ""
    var mealTypeDraft: MealType?
    var dishNameDraft: String = ""

    private let mealID: UUID
    private let getMealDetail: GetMealDetailUseCase
    private let updateMealRecord: UpdateMealRecordUseCase
    private let assignDishToMeal: AssignDishToMealUseCase
    private let deleteMealRecord: DeleteMealRecordUseCase

    init(
        mealID: UUID,
        getMealDetail: GetMealDetailUseCase,
        updateMealRecord: UpdateMealRecordUseCase,
        assignDishToMeal: AssignDishToMealUseCase,
        deleteMealRecord: DeleteMealRecordUseCase
    ) {
        self.mealID = mealID
        self.getMealDetail = getMealDetail
        self.updateMealRecord = updateMealRecord
        self.assignDishToMeal = assignDishToMeal
        self.deleteMealRecord = deleteMealRecord
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
            state = .failed("読み込めませんでした。もう一度お試しください。")
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
            errorMessage = "保存できませんでした。もう一度お試しください。"
        }
    }

    /// 料理名を追加する。同じ名前なら既存の料理に紐づく。
    func addDish() async {
        guard let name = DishName(dishNameDraft) else {
            errorMessage = "料理名を入力してください。"
            return
        }

        do {
            try await assignDishToMeal.execute(mealRecordID: mealID, dishName: name)
            dishNameDraft = ""
            errorMessage = nil
            await load()
        } catch {
            errorMessage = "追加できませんでした。もう一度お試しください。"
        }
    }

    /// 記録ごと削除する。写真と調理履歴も消える。
    func deleteMeal() async -> Bool {
        do {
            try await deleteMealRecord.execute(id: mealID)
            return true
        } catch {
            errorMessage = "削除できませんでした。もう一度お試しください。"
            return false
        }
    }
}
