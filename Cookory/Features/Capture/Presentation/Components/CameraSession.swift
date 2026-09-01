@preconcurrency import AVFoundation
import ImageIO
import Observation
import UIKit

/// 一覧のサムネイルの一辺。Retina 3x の 56pt 枠に足りる大きさ。
private nonisolated let thumbnailPixelSize = 200

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

    /// 撮影した 1 枚。
    ///
    /// サムネイルを撮影時に 1 度だけ作って持つ。表示のたびにフル解像度の
    /// JPEG を展開すると、10 枚溜まった時点でメモリを圧迫する。
    struct Shot: Identifiable {
        let id = UUID()
        let data: Data
        let thumbnail: UIImage
    }

    private(set) var status: Status = .idle

    /// 撮影済みの写真。撮った順に並ぶ。
    private(set) var captured: [Shot] = []

    private(set) var isCapturing = false

    /// 撮れる枚数の上限。写真ライブラリ選択と揃える。
    let limit: Int

    /// `AVCaptureSession` はスレッドセーフではない。設定・開始・停止・撮影を
    /// すべてこの 1 本に載せて直列化する。
    @ObservationIgnored private let queue = DispatchQueue(label: "app.cookory.camera.session")

    @ObservationIgnored nonisolated(unsafe) let session = AVCaptureSession()
    @ObservationIgnored nonisolated(unsafe) private let output = AVCapturePhotoOutput()
    @ObservationIgnored private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    @ObservationIgnored private var delegate: PhotoCaptureDelegate?

    /// カメラが使えるか。シミュレータでは false。
    /// 権限の可否はここでは分からないため、開いてから `denied` で伝える。
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

    /// 保存に渡す実体。撮った順を保つ。
    var capturedImages: [Data] { captured.map(\.data) }

    func start() async {
        guard status == .idle else { return }

        guard await Self.requestAccess() else {
            status = .denied
            return
        }

        guard let device = await configure() else {
            status = .unavailable
            return
        }

        // 端末の向きを撮影の向きに反映するため、プレビューではなく水平基準で取る。
        rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
        status = .running
        await run { $0.startRunning() }
    }

    func capture() async {
        guard canCapture else { return }
        isCapturing = true
        defer { isCapturing = false }

        applyRotation()

        let settings = AVCapturePhotoSettings()
        // 連続撮影では 1 枚あたりの待ち時間が体感に直結する。
        settings.photoQualityPrioritization = .speed

        let output = output
        guard let data = await withCheckedContinuation({ continuation in
            let delegate = PhotoCaptureDelegate { continuation.resume(returning: $0) }
            // AVCapturePhotoOutput は delegate を保持しないため、
            // 撮影が終わるまでこちらで生かしておく必要がある。
            self.delegate = delegate
            queue.async { output.capturePhoto(with: settings, delegate: delegate) }
        }) else { return }

        guard let thumbnail = await Self.makeThumbnail(from: data) else { return }
        captured.append(Shot(data: data, thumbnail: thumbnail))
    }

    /// 直前の 1 枚を取り消す。撮り直しのたびに画面を出入りさせないため。
    func undoLast() {
        guard !captured.isEmpty else { return }
        captured.removeLast()
    }

    func stop() async {
        guard status == .running else { return }
        status = .idle
        await run { $0.stopRunning() }
    }

    /// 撮影の向きを合わせる。設定しないと端末を縦に構えても横倒しで保存される。
    private func applyRotation() {
        guard let angle = rotationCoordinator?.videoRotationAngleForHorizonLevelCapture,
              let connection = output.connection(with: .video),
              connection.isVideoRotationAngleSupported(angle) else { return }
        connection.videoRotationAngle = angle
    }

    private func configure() async -> AVCaptureDevice? {
        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: .back
        ) else { return nil }

        let output = output
        let succeeded = await run { session -> Bool in
            session.beginConfiguration()
            defer { session.commitConfiguration() }

            session.sessionPreset = .photo

            guard let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input),
                  session.canAddOutput(output) else { return false }

            session.addInput(input)
            session.addOutput(output)
            return true
        }

        return succeeded ? device : nil
    }

    /// セッションへの操作を専用キューへ載せる。メインスレッドを止めないため。
    private func run<T: Sendable>(_ work: @escaping @Sendable (AVCaptureSession) -> T) async -> T {
        let session = session
        return await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: work(session)) }
        }
    }

    /// 撮影直後の 1 枚を一覧用に縮める。デコードは重いのでメインスレッドから外す。
    private static func makeThumbnail(from data: Data) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: thumbnailPixelSize,
            ]
            guard let image = CGImageSourceCreateThumbnailAtIndex(
                source, 0, options as CFDictionary
            ) else { return nil }
            return UIImage(cgImage: image)
        }.value
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
///
/// 撮影が中断されると `didFinishProcessingPhoto` は呼ばれず
/// `didFinishCaptureFor` だけが届く。どちらから来ても必ず一度だけ返す。
private nonisolated final class PhotoCaptureDelegate: NSObject, @unchecked Sendable, AVCapturePhotoCaptureDelegate {
    /// AVFoundation は隔離を知らない任意のスレッドから delegate を呼ぶ。
    private let lock = NSLock()
    private var onFinish: (@Sendable (Data?) -> Void)?

    init(onFinish: @escaping @Sendable (Data?) -> Void) {
        self.onFinish = onFinish
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        // ImageStorage が向きを補正するため、ここでは JPEG にするだけでよい。
        finish(error == nil ? photo.fileDataRepresentation() : nil)
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: Error?
    ) {
        finish(nil)
    }

    /// continuation の二重 resume はクラッシュになる。必ず一度で止める。
    private func finish(_ data: Data?) {
        lock.lock()
        let callback = onFinish
        onFinish = nil
        lock.unlock()

        callback?(data)
    }
}
