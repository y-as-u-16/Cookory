import Foundation
@testable import Cookory

/// テスト用の ImageStorage。実ファイルシステムを触らない。
actor InMemoryImageStorage: ImageStorage {
    private var originals: [UUID: Data] = [:]
    private var thumbnails: [UUID: Data] = [:]

    var errorToThrow: DomainError?

    /// 保存時に返す寸法。実際のデコードはしないので固定値を返す。
    private let width: Int
    private let height: Int

    init(width: Int = 1024, height: Int = 768) {
        self.width = width
        self.height = height
    }

    func save(_ data: Data) async throws -> PhotoAsset {
        try throwIfNeeded()
        let id = UUID()
        originals[id] = data
        thumbnails[id] = data
        return PhotoAsset(id: id, filename: "original.jpg", width: width, height: height)
    }

    func load(id: UUID) async throws -> Data {
        try throwIfNeeded()
        guard let data = originals[id] else { throw DomainError.notFound(id: id) }
        return data
    }

    func loadThumbnail(id: UUID) async throws -> Data {
        try throwIfNeeded()
        guard let data = thumbnails[id] else { throw DomainError.notFound(id: id) }
        return data
    }

    func delete(id: UUID) async throws {
        try throwIfNeeded()
        originals.removeValue(forKey: id)
        thumbnails.removeValue(forKey: id)
    }

    // MARK: - Test helpers

    var savedCount: Int { originals.count }

    func contains(id: UUID) -> Bool { originals[id] != nil }

    func setError(_ error: DomainError?) {
        errorToThrow = error
    }

    private func throwIfNeeded() throws {
        if let errorToThrow {
            throw errorToThrow
        }
    }
}
