import Foundation

/// 料理名。空文字や過剰に長い名前を型で弾く。
struct DishName: Hashable, Sendable {
    /// 表示崩れとデータ肥大を防ぐための上限。
    static let maxLength = 100

    let value: String

    /// 前後の空白を取り除いた上で検証する。
    /// 空白のみ、または `maxLength` を超える場合は生成に失敗する。
    init?(_ rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= Self.maxLength else { return nil }
        value = trimmed
    }
}

extension DishName: CustomStringConvertible {
    var description: String { value }
}

extension DishName: Codable {
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let name = DishName(raw) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "料理名として不正な値です")
            )
        }
        self = name
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}
