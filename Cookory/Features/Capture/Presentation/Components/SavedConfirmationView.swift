import SwiftUI

/// 保存完了の表示。
///
/// この時点で写真は保存済み。料理名や評価を足すかどうかは利用者が選ぶ。
struct SavedConfirmationView: View {
    let photoCount: Int
    let onAddDetails: () -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text(L10n.captureSavedCount(photoCount))
                .font(.title2.weight(.semibold))

            Button(String(localized: L10n.captureAddDetails), action: onAddDetails)
                .buttonStyle(.borderedProminent)
            Button(String(localized: L10n.captureContinue), action: onDone)
                .buttonStyle(.bordered)
        }
    }
}
