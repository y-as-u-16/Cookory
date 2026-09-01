import Foundation
import ImageIO
import UniformTypeIdentifiers

/// 写真をファイルシステムへ保存する。
///
/// 原本は Application Support（バックアップ対象）、サムネイルは Caches
/// （OS がいつでも破棄できる）に分ける。SwiftData に Binary を入れないのは
/// DB の肥大化を避け、将来 Cloud Storage へ移しやすくするため。
actor LocalImageStorage: ImageStorage {
    /// 長辺の上限。元画像が大きくてもこのサイズに収める。
    private static let maxDimension: CGFloat = 2048
    private static let thumbnailDimension: CGFloat = 400
    private static let compressionQuality: CGFloat = 0.85

    private nonisolated let originalsDirectory: URL
    private nonisolated let thumbnailsDirectory: URL
    private nonisolated let fileManager: FileManager

    init(
        originalsDirectory: URL? = nil,
        thumbnailsDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) throws {
        self.fileManager = fileManager
        self.originalsDirectory = try originalsDirectory ?? Self.defaultDirectory(
            for: .applicationSupportDirectory, fileManager: fileManager
        )
        self.thumbnailsDirectory = try thumbnailsDirectory ?? Self.defaultDirectory(
            for: .cachesDirectory, fileManager: fileManager
        )
    }

    private static func defaultDirectory(
        for directory: FileManager.SearchPathDirectory,
        fileManager: FileManager
    ) throws -> URL {
        try fileManager
            .url(for: directory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Images", isDirectory: true)
    }

    nonisolated func save(_ data: Data) async throws -> PhotoAsset {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw DomainError.imageStorageFailed
        }

        // kCGImageSourceCreateThumbnailWithTransform が EXIF の回転を適用する。
        // これを外すと iPhone で撮った写真が横倒しのまま保存される。
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Self.maxDimension,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw DomainError.imageStorageFailed
        }

        let id = UUID()
        let filename = "original.jpg"
        try write(image, to: originalURL(for: id, filename: filename))
        try writeThumbnail(from: source, id: id)

        return PhotoAsset(
            id: id,
            filename: filename,
            width: image.width,
            height: image.height,
            createdAt: Date()
        )
    }

    func load(id: UUID) async throws -> Data {
        let url = originalURL(for: id, filename: "original.jpg")
        guard let data = fileManager.contents(atPath: url.path) else {
            throw DomainError.notFound(id: id)
        }
        return data
    }

    func loadThumbnail(id: UUID) async throws -> Data {
        let url = thumbnailURL(for: id)
        if let data = fileManager.contents(atPath: url.path) {
            return data
        }

        // Caches は OS に破棄されうる。原本が残っていれば作り直す。
        let originalData = try await load(id: id)
        guard let source = CGImageSourceCreateWithData(originalData as CFData, nil) else {
            throw DomainError.imageStorageFailed
        }
        try writeThumbnail(from: source, id: id)

        guard let data = fileManager.contents(atPath: url.path) else {
            throw DomainError.imageStorageFailed
        }
        return data
    }

    /// 表示サイズは都度作る。原本は 2048px までなので十分な解像度が得られる。
    /// ファイルとして持たないのは、サイズごとに増やすと Caches が膨らむため。
    func loadDisplayImage(id: UUID, maxDimension: Int) async throws -> Data {
        let originalData = try await load(id: id)
        guard let source = CGImageSourceCreateWithData(originalData as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: maxDimension,
              ] as CFDictionary) else {
            throw DomainError.imageStorageFailed
        }
        return try encodeJPEG(image)
    }

    func delete(id: UUID) async throws {
        for url in [originalDirectory(for: id), thumbnailDirectory(for: id)] {
            guard fileManager.fileExists(atPath: url.path) else { continue }
            try fileManager.removeItem(at: url)
        }
    }

    // MARK: - Paths

    private nonisolated func originalDirectory(for id: UUID) -> URL {
        originalsDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    private nonisolated func thumbnailDirectory(for id: UUID) -> URL {
        thumbnailsDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    private nonisolated func originalURL(for id: UUID, filename: String) -> URL {
        originalDirectory(for: id).appendingPathComponent(filename)
    }

    private nonisolated func thumbnailURL(for id: UUID) -> URL {
        thumbnailDirectory(for: id).appendingPathComponent("thumbnail.jpg")
    }

    // MARK: - Writing

    private nonisolated func writeThumbnail(from source: CGImageSource, id: UUID) throws {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Self.thumbnailDimension,
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw DomainError.imageStorageFailed
        }
        try write(thumbnail, to: thumbnailURL(for: id))
    }

    /// メモリ上で JPEG にする。ファイルに残さない用途で使う。
    private nonisolated func encodeJPEG(_ image: CGImage) throws -> Data {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, UTType.jpeg.identifier as CFString, 1, nil
        ) else {
            throw DomainError.imageStorageFailed
        }
        CGImageDestinationAddImage(destination, image, [
            kCGImageDestinationLossyCompressionQuality: Self.compressionQuality,
        ] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw DomainError.imageStorageFailed
        }
        return output as Data
    }

    private nonisolated func write(_ image: CGImage, to url: URL) throws {
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )

        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.jpeg.identifier as CFString, 1, nil
        ) else {
            throw DomainError.imageStorageFailed
        }

        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: Self.compressionQuality
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw DomainError.imageStorageFailed
        }
    }
}
