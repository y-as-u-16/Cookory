import Foundation
@testable import Cookory

/// テスト用の ImageStorage。実ファイルシステムを触らない。
actor InMemoryImageStorage: ImageStorage {
    private var originals: [UUID: Data] = [:]
    private var thumbnails: [UUID: Data] = [:]

    var errorToThrow: DomainError?

    /// 設定されている間、save はここで待たされる。
    private var gate: AsyncGate?

    /// 保存時に返す寸法。実際のデコードはしないので固定値を返す。
    private let width: Int
    private let height: Int

    init(width: Int = 1024, height: Int = 768) {
        self.width = width
        self.height = height
    }

    func save(_ data: Data) async throws -> PhotoAsset {
        if let gate {
            await gate.wait()
        }
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

    func loadDisplayImage(id: UUID, maxDimension: Int) async throws -> Data {
        try throwIfNeeded()
        guard let data = originals[id] else { throw DomainError.notFound(id: id) }
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

// MARK: - Blocking

/// 保存を任意の時点まで止められるようにする。
/// 二重送信の検証には、処理中の状態を観測できる必要がある。
extension InMemoryImageStorage {
    func setGate(_ gate: AsyncGate?) {
        self.gate = gate
    }
}

/// 明示的に開くまで待たせる同期プリミティブ。
actor AsyncGate {
    private var continuations: [CheckedContinuation<Void, Never>] = []
    private var isOpen = false

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuations.append($0) }
    }

    func open() {
        isOpen = true
        let pending = continuations
        continuations.removeAll()
        for continuation in pending {
            continuation.resume()
        }
    }
}
