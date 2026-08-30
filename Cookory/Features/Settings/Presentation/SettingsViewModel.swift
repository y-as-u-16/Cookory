import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    enum ExportState: Equatable {
        case idle
        case exporting(Double)
        case ready(URL)
        case failed(LocalizedStringResource)
    }

    private(set) var exportState: ExportState = .idle

    private let exportData: ExportDataUseCase
    private let bundle: Bundle

    init(exportData: ExportDataUseCase, bundle: Bundle = .main) {
        self.exportData = exportData
        self.bundle = bundle
    }

    /// ビルド設定から取る。ここに直書きすると更新のたびに直し忘れる。
    var version: String {
        let short = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        let build = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "-"
        return "\(short) (\(build))"
    }

    var isExporting: Bool {
        if case .exporting = exportState { return true }
        return false
    }

    var exportedFile: URL? {
        guard case .ready(let url) = exportState else { return nil }
        return url
    }

    func export() async {
        // 二重実行を防ぐ。書き出しは重く、並行して走らせる意味がない。
        guard !isExporting else { return }

        exportState = .exporting(0)
        do {
            let url = try await exportData.execute { [weak self] progress in
                Task { @MainActor in
                    guard let self, self.isExporting else { return }
                    self.exportState = .exporting(progress)
                }
            }
            exportState = .ready(url)
        } catch {
            exportState = .failed(L10n.errorExport)
        }
    }

    func dismissExport() {
        exportState = .idle
    }
}
