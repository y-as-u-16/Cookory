import Foundation

/// タブ。Memory は Phase 1.1 のため MVP では出さない。
enum AppTab: String, CaseIterable, Hashable, Sendable {
    case home
    case calendar
    case cookbook
    case search
}
