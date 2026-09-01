import AVFoundation
import SwiftUI
import UIKit

/// カメラのライブプレビュー。
///
/// `AVCaptureVideoPreviewLayer` は UIView の layer として置く必要があるため、
/// SwiftUI から直接は扱えない。
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var previewLayer: AVCaptureVideoPreviewLayer {
            // layerClass で指定しているため、この変換は必ず成功する。
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
