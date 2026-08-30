import SwiftUI

struct FailureView: View {
    let message: LocalizedStringResource
    let onRetry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(L10n.captureFailedTitle, systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button(String(localized: L10n.captureRetry), action: onRetry)
                .buttonStyle(.borderedProminent)
        }
    }
}
