import Foundation
import Testing
@testable import Cookory

struct PhotoAssetTests {
    @Test func 寸法とファイル名を保持する() {
        let asset = PhotoAsset(filename: "original.heic", width: 4032, height: 3024)

        #expect(asset.filename == "original.heic")
        #expect(asset.width == 4032)
        #expect(asset.height == 3024)
    }

    @Test func IDは生成ごとに異なる() {
        let a = PhotoAsset(filename: "a.heic", width: 1, height: 1)
        let b = PhotoAsset(filename: "a.heic", width: 1, height: 1)

        #expect(a.id != b.id)
    }
}
