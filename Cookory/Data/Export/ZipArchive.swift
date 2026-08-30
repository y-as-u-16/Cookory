import Foundation

/// ディレクトリを ZIP にまとめる。
///
/// 外部ライブラリを入れず NSFileCoordinator の zip 変換を使う。
/// この API はディレクトリを渡すと ZIP を作り、一時的な URL を渡してくる。
enum ZipArchive {
    /// - Returns: 作成された ZIP の URL。呼び出し側が任意の場所へ移す。
    static func create(from directory: URL, fileManager: FileManager = .default) throws -> URL {
        var coordinatorError: NSError?
        var result: Result<URL, Error>?

        NSFileCoordinator().coordinate(
            readingItemAt: directory, options: [.forUploading], error: &coordinatorError
        ) { zipURL in
            // このクロージャを抜けると zipURL は消える。先に退避する。
            let destination = fileManager.temporaryDirectory
                .appendingPathComponent("CookoryArchive-\(UUID().uuidString).zip")
            do {
                try? fileManager.removeItem(at: destination)
                try fileManager.copyItem(at: zipURL, to: destination)
                result = .success(destination)
            } catch {
                result = .failure(error)
            }
        }

        if let coordinatorError { throw coordinatorError }
        guard let result else { throw DomainError.persistenceFailed }
        return try result.get()
    }
}
