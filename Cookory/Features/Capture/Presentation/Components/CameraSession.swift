import AVFoundation
import Observation
import UIKit

/// 連続撮影のためのカメラセッション。
///
/// `UIImagePickerController` は 1 枚撮ると必ず閉じるため使えない。
/// 1 回の食卓で何品も並ぶことは珍しくなく、そのたびにカメラを開き直すのは
/// 「記録するときは極限までシンプルに」に反する。
@MainActor
@Observable
final class CameraSession {
    enum Status: Equatable {
        case idle
        case running
        case denied
        case unavailable
    }

    private(set) var status: Status = .idle

    /// 撮影済みの JPEG。撮った順に並ぶ。
    private(set) var captured: [Data] = []

    private(set) var isCapturing = false

    /// 撮れる枚数の上限。写真ライブラリ選択と揃える。
    let limit: Int

    @ObservationIgnored let session = AVCaptureSession()
    @ObservationIgnored private let output = AVCapturePhotoOutput()
    @ObservationIgnored private var delegate: PhotoCaptureDelegate?

    /// カメラが使えるか。シミュレータでは false。
    static var isAvailable: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
    }

    init(limit: Int) {
        self.limit = limit
    }

    var canCapture: Bool {
        status == .running && !isCapturing && captured.count < limit
    }

    var hasCaptured: Bool { !captured.isEmpty }

    func start() async {
        guard status == .idle else { return }

        guard await Self.requestAccess() else {
            status = .denied
            return
        }

        guard configure() else {
            status = .unavailable
            return
        }

        status = .running
        await resume()
    }

    /// 撮影する。上限に達していれば何もしない。
    func capture() async {
        guard canCapture else { return }
        isCapturing = true
        defer { isCapturing = false }

        let settings = AVCapturePhotoSettings()
        // 連続撮影では 1 枚あたりの待ち時間が体感に直結する。
        settings.photoQualityPrioritization = .speed

        guard let data = await withCheckedContinuation({ continuation in
            let delegate = PhotoCaptureDelegate { continuation.resume(returning: $0) }
            // AVCapturePhotoOutput は delegate を保持しないため、
            // 撮影が終わるまでこちらで生かしておく必要がある。
            self.delegate = delegate
            output.capturePhoto(with: settings, delegate: delegate)
        }) else { return }

        captured.append(data)
    }

    /// 直前の 1 枚を取り消す。撮り直しのたびに画面を出入りさせないため。
    func undoLast() {
        guard !captured.isEmpty else { return }
        captured.removeLast()
    }

    func stop() async {
        let session = session
        await Task.detached { session.stopRunning() }.value
    }

    /// セッションの開始はメインスレッドを止めるため、別スレッドへ逃がす。
    private func resume() async {
        let session = session
        await Task.detached { session.startRunning() }.value
    }

    private func configure() -> Bool {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: .back
        ),
        let input = try? AVCaptureDeviceInput(device: device),
        session.canAddInput(input),
        session.canAddOutput(output) else { return false }

        session.addInput(input)
        session.addOutput(output)
        return true
    }

    private static func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }
}

/// 1 回ぶんの撮影完了を待つ。
private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let onFinish: @Sendable (Data?) -> Void

    init(onFinish: @escaping @Sendable (Data?) -> Void) {
        self.onFinish = onFinish
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        // ImageStorage が向きを補正するため、ここでは JPEG にするだけでよい。
        onFinish(error == nil ? photo.fileDataRepresentation() : nil)
    }
}
