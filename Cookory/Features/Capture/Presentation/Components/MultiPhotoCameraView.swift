import SwiftUI
import UIKit

/// 続けて何枚でも撮れるカメラ画面。
///
/// 撮っても閉じない。1 回の食卓に何品も並ぶため、
/// 写真ライブラリから複数枚選ぶのと同じ枚数を撮影でも残せるようにする。
struct MultiPhotoCameraView: View {
    @Environment(\.openURL) private var openURL
    @State private var session: CameraSession

    private let onFinish: ([Data]) -> Void
    private let onCancel: () -> Void

    init(limit: Int, onFinish: @escaping ([Data]) -> Void, onCancel: @escaping () -> Void) {
        _session = State(wrappedValue: CameraSession(limit: limit))
        self.onFinish = onFinish
        self.onCancel = onCancel
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
        }
        .task { await session.start() }
        // 「完了」以外の経路でも確実に止める。回したままだと
        // プライバシーインジケータが点き続け、電池も減る。
        .onDisappear { Task { await session.stop() } }
    }

    @ViewBuilder
    private var content: some View {
        switch session.status {
        case .idle:
            ProgressView().tint(.white)
        case .running:
            camera
        case .denied:
            message(L10n.cameraPermissionDenied) {
                Button(String(localized: L10n.cameraOpenSettings), action: openSettings)
                    .buttonStyle(.borderedProminent)
            }
        case .unavailable:
            message(L10n.cameraUnavailable)
        }
    }

    private var camera: some View {
        VStack(spacing: 0) {
            CameraPreviewView(session: session.session)
                .ignoresSafeArea(edges: .top)
                .overlay(alignment: .topTrailing) { counter }
            controls
        }
    }

    private var counter: some View {
        Text(L10n.cameraCount(session.captured.count, session.limit))
            .font(.footnote.weight(.semibold).monospacedDigit())
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            // 黒の半透明はプレビュー映像を潰す。Glass なら背景が透ける。
            .glassEffect(.regular, in: .capsule)
            .padding()
    }

    private var controls: some View {
        VStack(spacing: 16) {
            thumbnails
            HStack {
                Button(String(localized: L10n.cameraCancel), action: onCancel)
                    .foregroundStyle(.white)
                Spacer()
                shutter
                Spacer()
                Button(String(localized: L10n.cameraDone), action: finish)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(session.hasCaptured ? .white : .gray)
                    .disabled(!session.hasCaptured)
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 20)
        // 操作部は Functional Layer。黒ベタで塞がず映像の上に浮かせる。
        .background(.ultraThinMaterial)
    }

    private var shutter: some View {
        Button {
            Task { await session.capture() }
        } label: {
            Circle()
                .strokeBorder(.white, lineWidth: 4)
                .frame(width: 72, height: 72)
                .overlay {
                    Circle()
                        .fill(session.canCapture ? .white : .gray)
                        .frame(width: 58, height: 58)
                }
        }
        .disabled(!session.canCapture)
        .accessibilityLabel(Text(L10n.cameraShutter))
    }

    @ViewBuilder
    private var thumbnails: some View {
        if session.hasCaptured {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(session.captured) { shot in
                        Image(uiImage: shot.thumbnail)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.thumbnail, style: .continuous))
                    }

                    Button(action: session.undoLast) {
                        Label(L10n.cameraUndo, systemImage: "arrow.uturn.backward")
                            .font(.caption)
                            .labelStyle(.iconOnly)
                            .frame(width: 56, height: 56)
                            .glassEffect(.regular, in: .rect(cornerRadius: CornerRadius.thumbnail))
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel(Text(L10n.cameraUndo))
                }
                .padding(.horizontal, 24)
            }
            .frame(height: 56)
        }
    }

    private func message(
        _ text: LocalizedStringResource,
        @ViewBuilder action: () -> some View = { EmptyView() }
    ) -> some View {
        VStack(spacing: 16) {
            Text(text)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            action()
            Button(String(localized: L10n.cameraCancel), action: onCancel)
                .foregroundStyle(.white)
        }
        .padding()
    }

    private func finish() {
        onFinish(session.capturedImages)
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}
