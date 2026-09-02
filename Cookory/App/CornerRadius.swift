import CoreGraphics

/// 角丸の段階。値を画面ごとに決めると、同じ役割の要素で半径がばらつく。
///
/// 要素の大きさに比例させる。小さい面に大きな角丸を当てると輪郭が溶ける。
enum CornerRadius {
    /// 一覧の小さなサムネイル（56〜72pt）。
    static let thumbnail: CGFloat = 8

    /// チップやバッジなど、文字を囲む小さな面。
    static let chip: CGFloat = 10

    /// カードと、記録画面の写真（140〜160pt）。
    static let card: CGFloat = 14

    /// 画面幅に近い大きさで見せる写真。
    static let hero: CGFloat = 20
}
