import Foundation

/// 画面遷移先。
///
/// Feature から別 Feature の View を直接生成せず、この Route を経由する。
/// 遷移先の型ではなく ID だけを持つのは、Route を Hashable に保ち
/// NavigationStack の path に載せられるようにするため（ARCHITECTURE.md #39）。
enum AppRoute: Hashable, Sendable {
    case capture
    case cookbook
    case search
    case mealDetail(UUID)
    case dishDetail(UUID)
    case calendar(Date)
    case settings
}
