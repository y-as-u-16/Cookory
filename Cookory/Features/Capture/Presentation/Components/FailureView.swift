import SwiftUI

struct FailureView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("保存できませんでした", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("やり直す", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
    }
}
