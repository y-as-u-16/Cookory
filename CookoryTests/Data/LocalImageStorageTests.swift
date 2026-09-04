import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Cookory

struct LocalImageStorageTests {
    /// テストごとに独立した一時ディレクトリを使い、実ファイルシステムを汚さない。
    private func makeStorage() throws -> (LocalImageStorage, URL) {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("CookoryTests-\(UUID().uuidString)", isDirectory: true)
        let storage = try LocalImageStorage(
            originalsDirectory: root.appendingPathComponent("originals"),
            thumbnailsDirectory: root.appendingPathComponent("thumbnails")
        )
        return (storage, root)
    }

    /// 指定サイズの JPEG を作る。orientation を渡すと EXIF に回転情報を埋める。
    private func makeJPEG(width: Int, height: Int, orientation: Int? = nil) throws -> Data {
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )!
        context.setFillColor(CGColor(red: 0.9, green: 0.5, blue: 0.3, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = context.makeImage()!

        let output = NSMutableData()
        let destination = CGImageDestinationCreateWithData(
            output, UTType.jpeg.identifier as CFString, 1, nil
        )!
        var properties: [CFString: Any] = [:]
        if let orientation {
            properties[kCGImagePropertyOrientation] = orientation
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        CGImageDestinationFinalize(destination)
        return output as Data
    }

    private func dimensions(of data: Data) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return (w, h)
    }

    @Test func 保存した画像を読み出せる() async throws {
        let (storage, root) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        let asset = try await storage.save(makeJPEG(width: 800, height: 600))
        let loaded = try await storage.load(id: asset.id)

        #expect(!loaded.isEmpty)
        #expect(asset.width == 800)
        #expect(asset.height == 600)
    }

    @Test func 長辺が上限を超える画像は縮小される() async throws {
        let (storage, root) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        let asset = try await storage.save(makeJPEG(width: 4032, height: 3024))

        #expect(asset.width == 2048, "長辺が 2048 に収まること")
        #expect(asset.height == 1536, "縦横比が保たれること")
    }

    @Test func 上限以下の画像は拡大されない() async throws {
        let (storage, root) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        let asset = try await storage.save(makeJPEG(width: 640, height: 480))

        #expect(asset.width == 640)
    }

    @Test func EXIFの回転情報が適用される() async throws {
        let (storage, root) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        // orientation 6 = 時計回りに 90 度回転して表示すべき画像。
        // 補正すると幅と高さが入れ替わる。
        let asset = try await storage.save(makeJPEG(width: 800, height: 600, orientation: 6))

        #expect(asset.width == 600, "回転を適用すると幅と高さが入れ替わる")
        #expect(asset.height == 800)
    }

    @Test func サムネイルが生成される() async throws {
        let (storage, root) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        let asset = try await storage.save(makeJPEG(width: 2000, height: 1500))
        let thumbnail = try await storage.loadThumbnail(id: asset.id)

        let size = try #require(dimensions(of: thumbnail))
        #expect(size.width <= 400)
        #expect(size.height <= 400)
    }

    @Test func サムネイルが消えても原本から作り直される() async throws {
        let (storage, root) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        let asset = try await storage.save(makeJPEG(width: 1000, height: 1000))

        // Caches は OS がいつでも破棄できる。その状況を再現する。
        let thumbnailDir = root
            .appendingPathComponent("thumbnails")
            .appendingPathComponent(asset.id.uuidString)
        try FileManager.default.removeItem(at: thumbnailDir)

        let thumbnail = try await storage.loadThumbnail(id: asset.id)

        #expect(!thumbnail.isEmpty)
    }

    @Test func 削除すると原本もサムネイルも消える() async throws {
        let (storage, root) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        let asset = try await storage.save(makeJPEG(width: 800, height: 600))
        try await storage.delete(id: asset.id)

        await #expect(throws: DomainError.notFound(id: asset.id)) {
            _ = try await storage.load(id: asset.id)
        }
        await #expect(throws: (any Error).self) {
            _ = try await storage.loadThumbnail(id: asset.id)
        }
    }

    @Test func 存在しないIDの削除は失敗しない() async throws {
        let (storage, root) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        try await storage.delete(id: UUID())
    }

    @Test func 存在しないIDの読み出しはnotFoundになる() async throws {
        let (storage, root) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        let id = UUID()
        await #expect(throws: DomainError.notFound(id: id)) {
            _ = try await storage.load(id: id)
        }
    }

    @Test func 画像として不正なデータは保存に失敗する() async throws {
        let (storage, root) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        await #expect(throws: DomainError.imageStorageFailed) {
            _ = try await storage.save(Data("これは画像ではない".utf8))
        }
    }

    @Test func 保存ごとに別のIDが割り当てられる() async throws {
        let (storage, root) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        let data = try makeJPEG(width: 400, height: 400)
        let first = try await storage.save(data)
        let second = try await storage.save(data)

        #expect(first.id != second.id)
    }
}

/// 複数枚を並行に保存したあと、すべて読み出せることを確かめる。
///
/// 保存を並行化した際に、書き込み途中のファイルを読んだり
/// 取りこぼしたりしていないかを見る。
struct LocalImageStorageConcurrencyTests {
    private func makeStorage() throws -> (LocalImageStorage, URL) {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("CookoryTests-\(UUID().uuidString)", isDirectory: true)
        let storage = try LocalImageStorage(
            originalsDirectory: root.appendingPathComponent("originals"),
            thumbnailsDirectory: root.appendingPathComponent("thumbnails")
        )
        return (storage, root)
    }

    private func width(of data: Data) -> Int? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else { return nil }
        return props[kCGImagePropertyPixelWidth] as? Int
    }

    private func makeJPEG(width: Int = 64, height: Int = 64) throws -> Data {
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )!
        context.setFillColor(CGColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = context.makeImage()!

        let output = NSMutableData()
        let destination = CGImageDestinationCreateWithData(
            output, UTType.jpeg.identifier as CFString, 1, nil
        )!
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return output as Data
    }

    private func saveConcurrently(
        _ storage: LocalImageStorage, image: Data, count: Int
    ) async throws -> [PhotoAsset] {
        try await withThrowingTaskGroup(of: PhotoAsset.self) { group in
            for _ in 0..<count {
                group.addTask { try await storage.save(image) }
            }
            var saved: [PhotoAsset] = []
            for try await asset in group { saved.append(asset) }
            return saved
        }
    }

    @Test func 並行保存したすべての写真を読み出せる() async throws {
        let (storage, root) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        let assets = try await saveConcurrently(storage, image: try makeJPEG(), count: 10)

        #expect(assets.count == 10)
        for asset in assets {
            #expect(try await !storage.load(id: asset.id).isEmpty)
        }
    }

    /// 一覧はサムネイルで描画する。ここが読めないと写真が出ない。
    @Test func 並行保存したすべてのサムネイルを読み出せる() async throws {
        let (storage, root) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        let assets = try await saveConcurrently(storage, image: try makeJPEG(), count: 10)

        for asset in assets {
            #expect(try await !storage.loadThumbnail(id: asset.id).isEmpty)
        }
    }

    /// 並行に保存した画像が互いのファイルを踏まないこと。寸法を変えて保存し、
    /// 読み出した画像の寸法で取り違えを検出する。
    ///
    /// FileManager 共有による競合（PR #78）は確率的にしか起きず、このテストでは
    /// 再現しない。実装の形は check-architecture.sh が守る。
    @Test func 並行保存した画像が互いに壊し合わない() async throws {
        let (storage, root) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        // 寸法を変えて、どの保存の結果かを読み出し側から区別できるようにする。
        let sizes = (1...30).map { (width: 40 + $0 * 4, height: 60) }
        let assets = try await withThrowingTaskGroup(
            of: (PhotoAsset, Int).self
        ) { group -> [(PhotoAsset, Int)] in
            for size in sizes {
                group.addTask {
                    let jpeg = try self.makeJPEG(width: size.width, height: size.height)
                    return (try await storage.save(jpeg), size.width)
                }
            }
            var saved: [(PhotoAsset, Int)] = []
            for try await result in group { saved.append(result) }
            return saved
        }

        #expect(assets.count == sizes.count)
        #expect(Set(assets.map { $0.0.id }).count == sizes.count)

        for (asset, expectedWidth) in assets {
            let loaded = try await storage.load(id: asset.id)
            #expect(width(of: loaded) == expectedWidth)
        }
    }

    /// Caches は OS に破棄されうる。消えても原本から作り直せること。
    @Test func サムネイルが消えても原本から作り直せる() async throws {
        let (storage, root) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }
        let asset = try await storage.save(try makeJPEG())
        #expect(try await !storage.loadThumbnail(id: asset.id).isEmpty)

        // OS による Caches の破棄を模す。
        try FileManager.default.removeItem(at: root.appendingPathComponent("thumbnails"))

        #expect(try await !storage.loadThumbnail(id: asset.id).isEmpty)
    }
}
