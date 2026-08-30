import Foundation

/// レシピの参考リンク。YouTube や Web ページを想定する。
///
/// 文字列ではなく型で持つのは、表示のたびに検証し直さないため。
/// 保存時に一度だけ検証する。
struct RecipeLink: Hashable, Sendable, Identifiable {
    /// 受け付けるスキーム。`javascript:` などを弾くために許可制にする。
    static let allowedSchemes: Set<String> = ["http", "https"]

    let id: UUID
    let url: URL

    /// 利用者が付けた名前。無ければ URL のホスト名を見せる。
    let title: String?

    /// http / https 以外、または URL として解釈できない文字列は弾く。
    init?(id: UUID = UUID(), rawURL: String, title: String? = nil) {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              Self.allowedSchemes.contains(scheme),
              url.host != nil else { return nil }

        self.id = id
        self.url = url
        self.title = title?.normalizedOrNil
    }

    /// 一覧に出す表示名。
    var displayName: String {
        title ?? url.host ?? url.absoluteString
    }
}
