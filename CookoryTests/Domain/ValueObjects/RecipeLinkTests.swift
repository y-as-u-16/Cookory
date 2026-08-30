import Foundation
import Testing
@testable import Cookory

struct RecipeLinkTests {
    @Test func httpsのURLを受け付ける() throws {
        let link = try #require(RecipeLink(rawURL: "https://www.youtube.com/watch?v=abc"))

        #expect(link.url.host == "www.youtube.com")
    }

    @Test func httpのURLを受け付ける() {
        #expect(RecipeLink(rawURL: "http://example.com/recipe") != nil)
    }

    /// javascript: などを弾く。利用者が貼った文字列をそのまま開かない。
    @Test(arguments: [
        "javascript:alert(1)",
        "file:///etc/passwd",
        "ftp://example.com",
        "data:text/html,<script>",
    ])
    func 許可していないスキームは弾く(raw: String) {
        #expect(RecipeLink(rawURL: raw) == nil)
    }

    @Test(arguments: ["", "   ", "not a url", "https://"])
    func URLとして読めない文字列は弾く(raw: String) {
        #expect(RecipeLink(rawURL: raw) == nil)
    }

    @Test func 前後の空白は取り除かれる() {
        #expect(RecipeLink(rawURL: "  https://example.com  ") != nil)
    }

    @Test func 名前が無ければホスト名を出す() throws {
        let link = try #require(RecipeLink(rawURL: "https://example.com/very/long/path"))

        #expect(link.displayName == "example.com")
    }

    @Test func 名前があればそれを出す() throws {
        let link = try #require(RecipeLink(rawURL: "https://example.com", title: "参考動画"))

        #expect(link.displayName == "参考動画")
    }

    @Test func 空白だけの名前は無視される() throws {
        let link = try #require(RecipeLink(rawURL: "https://example.com", title: "   "))

        #expect(link.title == nil)
        #expect(link.displayName == "example.com")
    }
}
