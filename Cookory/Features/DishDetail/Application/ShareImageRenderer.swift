import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// SNS へ投稿する画像を描く。
///
/// 9:16 の 1 枚だけ作る。Instagram ストーリーズ・LINE のトーク・TikTok が
/// この比率で、利用者にトリミングをさせないことが共有の摩擦を最も下げる。
struct ShareImageRenderer: Sendable {
    /// ストーリーズの標準サイズ。
    static let width: CGFloat = 1080
    static let height: CGFloat = 1920

    /// 上下は UI（ユーザー名・返信バー）に隠れる。右は Reels のボタン列がある。
    /// 実測値には 220〜250px の説があるため安全側の 260 を取る。
    static let safeTop: CGFloat = 260
    static let safeBottom: CGFloat = 260
    static let safeLeading: CGFloat = 72
    static let safeTrailing: CGFloat = 120

    struct Content: Sendable {
        let dishName: String
        /// 「12回作りました」のような、数ではなく物語になる一文。
        let headline: String
        let subline: String?
        let photo: Data?
    }

    func render(_ content: Content) throws -> Data {
        guard let context = CGContext(
            data: nil, width: Int(Self.width), height: Int(Self.height),
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            throw DomainError.imageStorageFailed
        }

        drawBackground(in: context)

        let contentWidth = Self.width - Self.safeLeading - Self.safeTrailing
        let safeHeight = Self.height - Self.safeTop - Self.safeBottom

        // 文字の高さを先に測り、残りを写真に充てる。写真を先に置くと
        // 文字の下に大きな余白が残って間延びする。
        let textHeight = measureText(content, width: contentWidth)
        let brandHeight: CGFloat = 60
        let gap: CGFloat = 72
        let photoHeight = min(
            safeHeight - textHeight - brandHeight - gap * 2,
            contentWidth * 1.15
        )

        // 余った分を上下に振り分けて中央に寄せる。
        let used = photoHeight + gap + textHeight + gap + brandHeight
        let topInset = Self.safeBottom + (safeHeight - used) / 2
        let photoY = topInset + brandHeight + gap + textHeight + gap

        drawPhoto(
            content.photo,
            in: context,
            rect: CGRect(x: Self.safeLeading, y: photoY, width: contentWidth, height: photoHeight)
        )

        var cursor = photoY - gap
        cursor = draw(
            content.dishName, in: context, at: cursor, width: contentWidth,
            size: 88, weight: .bold, alpha: 1
        )
        cursor -= 24
        cursor = draw(
            content.headline, in: context, at: cursor, width: contentWidth,
            size: 44, weight: .medium, alpha: 0.85
        )
        if let subline = content.subline {
            cursor -= 16
            cursor = draw(
                subline, in: context, at: cursor, width: contentWidth,
                size: 34, weight: .regular, alpha: 0.6
            )
        }

        // ブランドは主張ではなく署名。小さく、文字の下に置く。
        _ = draw(
            "Cookory", in: context, at: topInset + brandHeight, width: contentWidth,
            size: 26, weight: .medium, alpha: 0.45
        )

        guard let image = context.makeImage() else { throw DomainError.imageStorageFailed }
        return try Self.encode(image)
    }

    /// 文字ブロック全体の高さ。行間の余白も含む。
    private func measureText(_ content: Content, width: CGFloat) -> CGFloat {
        var height = measure(content.dishName, width: width, size: 88, weight: Weight.bold)
        height += 24 + measure(content.headline, width: width, size: 44, weight: Weight.medium)
        if let subline = content.subline {
            height += 16 + measure(subline, width: width, size: 34, weight: Weight.regular)
        }
        return height
    }

    // MARK: - 描画

    private func drawBackground(in context: CGContext) {
        let space = CGColorSpaceCreateDeviceRGB()
        guard let top = CGColor(colorSpace: space, components: [0.16, 0.11, 0.09, 1]),
              let bottom = CGColor(colorSpace: space, components: [0.09, 0.06, 0.05, 1]),
              let gradient = CGGradient(
                  colorsSpace: space, colors: [top, bottom] as CFArray, locations: [0, 1]
              ) else { return }
        context.drawLinearGradient(
            gradient, start: CGPoint(x: 0, y: Self.height), end: .zero, options: []
        )
    }

    /// 写真は角丸で切り抜き、写真が無いときは枠だけ出す。
    private func drawPhoto(_ data: Data?, in context: CGContext, rect: CGRect) {
        let path = CGPath(
            roundedRect: rect, cornerWidth: 40, cornerHeight: 40, transform: nil
        )

        context.saveGState()
        context.addPath(path)
        context.setFillColor(CGColor(gray: 1, alpha: 0.08))
        context.fillPath()
        context.restoreGState()

        guard let data,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: max(rect.width, rect.height) * 1.5,
              ] as CFDictionary) else { return }

        context.saveGState()
        context.addPath(path)
        context.clip()
        // 短辺を合わせて中央を切り出す。歪ませない。
        context.draw(image, in: Self.aspectFillRect(imageSize: CGSize(
            width: image.width, height: image.height
        ), in: rect))
        context.restoreGState()
    }

    /// 縦横比を保ったまま矩形を覆う位置とサイズ。
    static func aspectFillRect(imageSize: CGSize, in rect: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return rect }
        let scale = max(rect.width / imageSize.width, rect.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: rect.midX - size.width / 2,
            y: rect.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private enum Weight {
        case regular, medium, bold

        var traits: CGFloat {
            switch self {
            case .regular: 0
            case .medium: 0.23
            case .bold: 0.4
            }
        }
    }

    /// 文字を組む。描画と計測で同じ結果を得るため 1 か所にまとめる。
    private func makeFramesetter(
        _ text: String, size: CGFloat, weight: Weight, alpha: CGFloat
    ) -> CTFramesetter {
        let font = CTFontCreateUIFontForLanguage(.system, size, nil)
            ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
        let descriptor = CTFontDescriptorCreateCopyWithAttributes(
            CTFontCopyFontDescriptor(font),
            [kCTFontTraitsAttribute: [kCTFontWeightTrait: weight.traits]] as CFDictionary
        )
        let styled = CTFontCreateWithFontDescriptor(descriptor, size, nil)

        // UIKit を import せずに済ませるため CoreText の属性名を使う。
        return CTFramesetterCreateWithAttributedString(
            NSAttributedString(string: text, attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): styled,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String):
                    CGColor(gray: 1, alpha: alpha),
            ])
        )
    }

    private func measure(
        _ text: String, width: CGFloat, size: CGFloat, weight: Weight
    ) -> CGFloat {
        CTFramesetterSuggestFrameSizeWithConstraints(
            makeFramesetter(text, size: size, weight: weight, alpha: 1),
            CFRange(location: 0, length: 0), nil,
            CGSize(width: width, height: .greatestFiniteMagnitude), nil
        ).height
    }

    /// - Returns: 描いたテキストの上端。次の要素の配置に使う。
    @discardableResult
    private func draw(
        _ text: String, in context: CGContext, at bottom: CGFloat,
        width: CGFloat, size: CGFloat, weight: Weight, alpha: CGFloat
    ) -> CGFloat {
        let framesetter = makeFramesetter(text, size: size, weight: weight, alpha: alpha)
        let suggested = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter, CFRange(location: 0, length: 0), nil,
            CGSize(width: width, height: .greatestFiniteMagnitude), nil
        )

        let rect = CGRect(
            x: Self.safeLeading, y: bottom - suggested.height,
            width: width, height: suggested.height
        )
        let frame = CTFramesetterCreateFrame(
            framesetter, CFRange(location: 0, length: 0),
            CGPath(rect: rect, transform: nil), nil
        )
        CTFrameDraw(frame, context)

        return rect.minY
    }

    private static func encode(_ image: CGImage) throws -> Data {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, UTType.png.identifier as CFString, 1, nil
        ) else {
            throw DomainError.imageStorageFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw DomainError.imageStorageFailed
        }
        return output as Data
    }
}
