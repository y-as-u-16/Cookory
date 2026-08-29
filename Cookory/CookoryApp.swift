import SwiftUI

@main
struct CookoryApp: App {
    @State private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .task {
                    environment.bootstrap()
                }
        }
    }
}
