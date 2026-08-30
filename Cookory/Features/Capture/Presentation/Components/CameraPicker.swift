import SwiftUI
import UIKit

/// カメラで撮影する。
///
/// SwiftUI にカメラ UI は無いため UIImagePickerController を包む。
/// AVFoundation で自作すると露出・フォーカス・フラッシュまで面倒を見ることになり、
/// 「その場で 1 枚撮る」という用途には過剰。
struct CameraPicker: UIViewControllerRepresentable {
    /// 撮影された JPEG。キャンセル時は nil。
    let onCapture: (Data?) -> Void

    /// カメラが使えるか。シミュレータや権限拒否時は false。
    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onCapture: (Data?) -> Void

        init(onCapture: @escaping (Data?) -> Void) {
            self.onCapture = onCapture
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            // ImageStorage が向きを補正するため、ここでは JPEG にするだけでよい。
            let image = info[.originalImage] as? UIImage
            onCapture(image?.jpegData(compressionQuality: 0.9))
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCapture(nil)
        }
    }
}
