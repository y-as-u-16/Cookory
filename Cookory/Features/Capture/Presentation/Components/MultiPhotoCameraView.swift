import SwiftUI

/// 続けて何枚でも撮れるカメラ画面。
///
/// 撮っても閉じない。1 回の食卓に何品も並ぶため、
/// 写真ライブラリから複数枚選ぶのと同じ枚数を撮影でも残せるようにする。
struct MultiPhotoCameraView: View {
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
    }

    @ViewBuilder
    private var content: some View {
        switch session.status {
        case .idle:
            ProgressView().tint(.white)
        case .running:
            camera
        case .denied:
            message(L10n.cameraPermissionDenied)
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
            .background(.black.opacity(0.5), in: Capsule())
            .padding()
    }

    private var controls: some View {
        VStack(spacing: 16) {
            thumbnails
            HStack {
                Button(String(localized: L10n.cameraCancel), action: cancel)
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
        .background(.black)
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
                    ForEach(Array(session.captured.enumerated()), id: \.offset) { _, data in
                        if let image = UIImage(data: data) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }

                    Button(action: session.undoLast) {
                        Label(L10n.cameraUndo, systemImage: "arrow.uturn.backward")
                            .font(.caption)
                            .labelStyle(.iconOnly)
                            .frame(width: 56, height: 56)
                            .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel(Text(L10n.cameraUndo))
                }
                .padding(.horizontal, 24)
            }
            .frame(height: 56)
        }
    }

    private func message(_ text: LocalizedStringResource) -> some View {
        VStack(spacing: 16) {
            Text(text)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Button(String(localized: L10n.cameraCancel), action: cancel)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func finish() {
        let images = session.captured
        Task {
            await session.stop()
            onFinish(images)
        }
    }

    private func cancel() {
        Task {
            await session.stop()
            onCancel()
        }
    }
}
