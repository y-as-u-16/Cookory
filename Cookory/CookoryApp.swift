import SwiftUI

@main
struct CookoryApp: App {
    @State private var environment = AppEnvironment()
    @State private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .environment(settings)
                // テーマと言語を明示的に上書きする。端末設定に従う場合は nil。
                .preferredColorScheme(settings.theme.colorScheme)
                .environment(\.locale, settings.language.locale ?? Locale.current)
                .task {
                    await environment.start()
                }
        }
    }
}
