import SwiftUI

/// 保存完了の表示。
///
/// この時点で写真は保存済み。料理名や評価の入力は #12 で足す。
struct SavedConfirmationView: View {
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("保存しました")
                .font(.title2.weight(.semibold))
            Button("続けて記録する", action: onDone)
                .buttonStyle(.bordered)
        }
    }
}
