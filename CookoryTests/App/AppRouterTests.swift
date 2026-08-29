import Foundation
import Testing
@testable import Cookory

@MainActor
struct AppRouterTests {
    @Test func pushで遷移先が積まれる() {
        let router = AppRouter()
        let id = UUID()

        router.push(.mealDetail(id))

        #expect(router.path == [.mealDetail(id)])
    }

    @Test func popで1つ戻る() {
        let router = AppRouter(path: [.settings, .mealDetail(UUID())])

        router.pop()

        #expect(router.path == [.settings])
    }

    /// 戻る操作を連打してもクラッシュしない。
    @Test func 空の状態でpopしても安全() {
        let router = AppRouter()

        router.pop()

        #expect(router.path.isEmpty)
    }

    @Test func popToRootで全部戻る() {
        let router = AppRouter(path: [.settings, .dishDetail(UUID()), .mealDetail(UUID())])

        router.popToRoot()

        #expect(router.path.isEmpty)
    }

    @Test func 指定した画面まで戻る() {
        let dishID = UUID()
        let router = AppRouter(path: [.settings, .dishDetail(dishID), .mealDetail(UUID())])

        router.pop(to: .dishDetail(dishID))

        #expect(router.path == [.settings, .dishDetail(dishID)])
    }

    /// 存在しない Route で path が全消しになると、意図しない画面へ飛ぶ。
    @Test func 存在しない画面を指定しても何も起きない() {
        let original: [AppRoute] = [.settings, .mealDetail(UUID())]
        let router = AppRouter(path: original)

        router.pop(to: .dishDetail(UUID()))

        #expect(router.path == original)
    }

    @Test func 同じ画面が複数あるときは最後のものまで戻る() {
        let router = AppRouter(path: [.settings, .dishDetail(UUID()), .settings, .mealDetail(UUID())])

        router.pop(to: .settings)

        #expect(router.path.count == 3)
        #expect(router.path.last == .settings)
    }
}

struct AppRouteTests {
    /// NavigationStack の path に載せるには Hashable の一致が正しく効く必要がある。
    @Test func 同じIDのRouteは等しい() {
        let id = UUID()

        #expect(AppRoute.mealDetail(id) == AppRoute.mealDetail(id))
    }

    @Test func 種類が違えば等しくない() {
        let id = UUID()

        #expect(AppRoute.mealDetail(id) != AppRoute.dishDetail(id))
    }
}
