import Foundation

/// 設定で選ばれた言語。nil なら端末設定に従う。
///
/// `LocalizedStringResource` は解決を表示時まで遅らせるため、SwiftUI は
/// `.environment(\.locale)` に追従して自動で再描画する。String を先に組み立てると
/// 言語を変えても古い文言が残るので、UI へ渡す文言はすべてこの型で扱う。
nonisolated(unsafe) var l10nOverrideLocale: Locale?

private func t(_ key: String.LocalizationValue) -> LocalizedStringResource {
    if let locale = l10nOverrideLocale {
        return LocalizedStringResource(key, locale: locale)
    }
    return LocalizedStringResource(key)
}

/// UI 文言。原文は日本語で、訳は Localizable.xcstrings が持つ。
enum L10n {
    // タブ
    static var tabHome: LocalizedStringResource { t("tab.home") }
    static var tabCalendar: LocalizedStringResource { t("tab.calendar") }
    static var tabCookbook: LocalizedStringResource { t("tab.cookbook") }
    static var tabSearch: LocalizedStringResource { t("tab.search") }

    // ホーム
    static var homeTitle: LocalizedStringResource { t("home.title") }
    static var homeRecordButton: LocalizedStringResource { t("home.button.record") }
    static var homeRecentTitle: LocalizedStringResource { t("home.recent.title") }
    static var homeForgottenTitle: LocalizedStringResource { t("home.forgotten.title") }
    static var homeEmptyTitle: LocalizedStringResource { t("home.empty.title") }
    static var homeEmptyDescription: LocalizedStringResource { t("home.empty.description") }
    static func daysSinceLastCooked(_ days: Int) -> LocalizedStringResource {
        t("home.forgotten.days \(days)")
    }

    // 撮影
    static var captureTitle: LocalizedStringResource { t("capture.title") }
    static var captureTakePhoto: LocalizedStringResource { t("capture.button.camera") }
    static var captureChoosePhoto: LocalizedStringResource { t("capture.button.library") }
    static var captureSaving: LocalizedStringResource { t("capture.saving") }
    static var captureAddDetails: LocalizedStringResource { t("capture.button.addDetails") }
    static var captureContinue: LocalizedStringResource { t("capture.button.continue") }
    static var captureFailedTitle: LocalizedStringResource { t("capture.failed.title") }
    static var captureRetry: LocalizedStringResource { t("capture.button.retry") }
    static func capturePhotoLimit(_ limit: Int) -> LocalizedStringResource {
        t("capture.photoLimit \(limit)")
    }
    static func captureSavedCount(_ count: Int) -> LocalizedStringResource {
        t("capture.saved \(count)")
    }

    // 記録の詳細
    static var mealDetailTitle: LocalizedStringResource { t("mealDetail.title") }
    static var mealDetailDishesSection: LocalizedStringResource { t("mealDetail.section.dishes") }
    static var mealDetailAddDish: LocalizedStringResource { t("mealDetail.field.addDish") }
    static var mealDetailAdd: LocalizedStringResource { t("mealDetail.button.add") }
    static var mealDetailNoteSection: LocalizedStringResource { t("mealDetail.section.note") }
    static var mealDetailMealType: LocalizedStringResource { t("mealDetail.field.mealType") }
    static var mealDetailNote: LocalizedStringResource { t("mealDetail.field.note") }
    static var mealDetailSave: LocalizedStringResource { t("mealDetail.button.save") }
    static var mealDetailDelete: LocalizedStringResource { t("mealDetail.button.delete") }
    static var mealDetailDeleteConfirm: LocalizedStringResource { t("mealDetail.delete.confirm") }
    static var mealDetailDeleteMessage: LocalizedStringResource { t("mealDetail.delete.message") }

    // 食事の種類
    static var mealTypeUnspecified: LocalizedStringResource { t("mealType.unspecified") }
    static var mealTypeBreakfast: LocalizedStringResource { t("mealType.breakfast") }
    static var mealTypeLunch: LocalizedStringResource { t("mealType.lunch") }
    static var mealTypeDinner: LocalizedStringResource { t("mealType.dinner") }
    static var mealTypeSnack: LocalizedStringResource { t("mealType.snack") }

    // カレンダー
    static var calendarTitle: LocalizedStringResource { t("calendar.title") }
    static var calendarNoRecord: LocalizedStringResource { t("calendar.empty") }

    // 図鑑
    static var cookbookTitle: LocalizedStringResource { t("cookbook.title") }
    static var cookbookEmptyTitle: LocalizedStringResource { t("cookbook.empty.title") }
    static var cookbookEmptyDescription: LocalizedStringResource { t("cookbook.empty.description") }
    static func cookCount(_ count: Int) -> LocalizedStringResource { t("cookbook.count \(count)") }
    static var sortRecentlyCooked: LocalizedStringResource { t("cookbook.sort.recent") }
    static var sortMostCooked: LocalizedStringResource { t("cookbook.sort.most") }
    static var sortNotCookedRecently: LocalizedStringResource { t("cookbook.sort.notRecent") }
    static var sortFavorite: LocalizedStringResource { t("cookbook.sort.favorite") }
    static var sortName: LocalizedStringResource { t("cookbook.sort.name") }

    // 料理の詳細
    static func dishCookCount(_ count: Int) -> LocalizedStringResource {
        t("dishDetail.cookCount \(count)")
    }
    static func dishLastCooked(_ date: String) -> LocalizedStringResource {
        t("dishDetail.lastCooked \(date)")
    }
    static var dishHistoryTitle: LocalizedStringResource { t("dishDetail.history.title") }
    static var dishOpenRecipe: LocalizedStringResource { t("dishDetail.button.recipe") }
    static var dishAddFavorite: LocalizedStringResource { t("dishDetail.a11y.addFavorite") }
    static var dishRemoveFavorite: LocalizedStringResource { t("dishDetail.a11y.removeFavorite") }
    static var dishShare: LocalizedStringResource { t("dishDetail.button.share") }

    // レシピ
    static var recipeTitle: LocalizedStringResource { t("recipe.title") }
    static var recipeIngredients: LocalizedStringResource { t("recipe.section.ingredients") }
    static var recipeSteps: LocalizedStringResource { t("recipe.section.steps") }
    static var recipeLinks: LocalizedStringResource { t("recipe.section.links") }
    static var recipeAddLink: LocalizedStringResource { t("recipe.button.addLink") }
    static var recipeLinkName: LocalizedStringResource { t("recipe.field.linkName") }
    static var recipeSave: LocalizedStringResource { t("recipe.button.save") }

    // 検索
    static var searchTitle: LocalizedStringResource { t("search.title") }
    static var searchPrompt: LocalizedStringResource { t("search.prompt") }
    static var searchDishesSection: LocalizedStringResource { t("search.section.dishes") }
    static var searchNotesSection: LocalizedStringResource { t("search.section.notes") }

    // 設定
    static var settingsTitle: LocalizedStringResource { t("settings.title") }
    static var settingsDataSection: LocalizedStringResource { t("settings.section.data") }
    static var settingsExport: LocalizedStringResource { t("settings.button.export") }
    static var settingsExporting: LocalizedStringResource { t("settings.exporting") }
    static var settingsShareExport: LocalizedStringResource { t("settings.button.shareExport") }
    static var settingsAppearanceSection: LocalizedStringResource { t("settings.section.appearance") }
    static var settingsTheme: LocalizedStringResource { t("settings.field.theme") }
    static var settingsLanguage: LocalizedStringResource { t("settings.field.language") }
    static var settingsAboutSection: LocalizedStringResource { t("settings.section.about") }
    static var settingsVersion: LocalizedStringResource { t("settings.field.version") }
    static var settingsLicense: LocalizedStringResource { t("settings.field.license") }
    static var settingsPrivacy: LocalizedStringResource { t("settings.field.privacy") }

    static var followSystem: LocalizedStringResource { t("settings.followSystem") }
    static var themeLight: LocalizedStringResource { t("settings.theme.light") }
    static var themeDark: LocalizedStringResource { t("settings.theme.dark") }

    // 共通
    static var errorGeneric: LocalizedStringResource { t("error.generic") }
    static var errorLoad: LocalizedStringResource { t("error.load") }
    static var errorSave: LocalizedStringResource { t("error.save") }
    static var errorImageStorage: LocalizedStringResource { t("error.imageStorage") }
    static var errorInvalidLink: LocalizedStringResource { t("error.invalidLink") }
    static var errorDishNameRequired: LocalizedStringResource { t("error.dishNameRequired") }
    static var errorNoPhoto: LocalizedStringResource { t("error.noPhoto") }
    static var errorNotFound: LocalizedStringResource { t("error.notFound") }
    static var loadFailedTitle: LocalizedStringResource { t("error.load.title") }
    static var loadFailedDescription: LocalizedStringResource { t("error.load.description") }
}
