import SwiftUI

/// 起動時に出すスプラッシュ。
///
/// マークは画像ではなく図形で描く。アイコン画像を別途持つと、
/// アイコンを変えたときに片方だけ古いまま残る。
struct SplashView: View {
    @State private var isVisible = false

    /// 現れる速さ。速すぎると点滅に見え、遅すぎると待たされた感が出る。
    private static let appearDuration: Duration = .milliseconds(600)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.96, green: 0.85, blue: 0.72),
                         Color(red: 0.85, green: 0.60, blue: 0.38)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                SplashMark()
                    .frame(width: 120, height: 120)

                Text(verbatim: "Cookory")
                    .font(.title.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.9)
        }
        .onAppear {
            withAnimation(.smooth(duration: 0.6)) { isVisible = true }
        }
        // 画面全体が 1 つの要素として読まれれば足りる。
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "Cookory"))
    }
}

/// アプリアイコンと同じ「本の上の皿」。
private struct SplashMark: View {
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)

            ZStack {
                RoundedRectangle(cornerRadius: side * 0.16, style: .continuous)
                    .fill(.white.opacity(0.95))
                    .shadow(color: .black.opacity(0.2), radius: side * 0.08, y: side * 0.04)

                // 本の綴じ目。
                RoundedRectangle(cornerRadius: side * 0.01)
                    .fill(Color(red: 0.85, green: 0.60, blue: 0.38).opacity(0.35))
                    .frame(width: side * 0.02, height: side * 0.62)

                Circle()
                    .fill(Color(red: 0.97, green: 0.95, blue: 0.92))
                    .frame(width: side * 0.46, height: side * 0.46)
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.06), lineWidth: side * 0.008)
                            .padding(side * 0.05)
                    )

                Image(systemName: "fork.knife")
                    .font(.system(size: side * 0.2, weight: .medium))
                    .foregroundStyle(Color(red: 0.72, green: 0.45, blue: 0.24))
            }
            .frame(width: side, height: side)
        }
    }
}
