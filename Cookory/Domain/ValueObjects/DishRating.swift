import Foundation

/// 料理の評価。1〜5 の範囲外を型で弾く。
struct DishRating: Hashable, Sendable {
    static let range = 1...5

    let value: Int

    init?(_ rawValue: Int) {
        guard Self.range.contains(rawValue) else { return nil }
        value = rawValue
    }
}

extension DishRating: Comparable {
    static func < (lhs: DishRating, rhs: DishRating) -> Bool {
        lhs.value < rhs.value
    }
}

extension DishRating: Codable {
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(Int.self)
        guard let rating = DishRating(raw) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "評価は \(Self.range) の範囲です")
            )
        }
        self = rating
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}
