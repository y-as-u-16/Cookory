import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// App Store 6.9インチ必須サイズ
let W = 1320.0, H = 2868.0

struct Shot {
    let file: String
    let caption: String
    let sub: String
}

let args = CommandLine.arguments
guard args.count >= 4 else {
    print("usage: compose <srcDir> <outDir> <ja|en>")
    exit(1)
}
let srcDir = args[1], outDir = args[2], lang = args[3]

let ja = [
    Shot(file: "01-home", caption: "作った料理を、写真で残そう。",
         sub: "撮るだけ。数秒で記録できる"),
    Shot(file: "02-calendar", caption: "いつ何を作ったか、ひと目で。",
         sub: "写真が並ぶカレンダー"),
    Shot(file: "03-cookbook", caption: "料理図鑑が、自然に育つ。",
         sub: "作った料理だけが並ぶ"),
    Shot(file: "04-dish-history", caption: "同じ料理の上達まで残せる。",
         sub: "評価とメモが時系列で並ぶ"),
    Shot(file: "05-meal-detail", caption: "あとから書き足せる。",
         sub: "写真だけ先に。料理名は後で"),
]
let en = [
    Shot(file: "01-home", caption: "Keep what you cooked",
         sub: "Just snap a photo. Done in seconds"),
    Shot(file: "02-calendar", caption: "Your month at a glance",
         sub: "A calendar made of your photos"),
    Shot(file: "03-cookbook", caption: "Your cookbook grows itself",
         sub: "Only the dishes you actually made"),
    Shot(file: "04-dish-history", caption: "Watch a dish get better",
         sub: "Ratings and notes over time"),
    Shot(file: "05-meal-detail", caption: "Fill in the details later",
         sub: "Photo first. Name it when you can"),
]
let shots = lang == "ja" ? ja : en

// 食卓を思わせる暖色。アプリ内の色調に合わせる。
let topColor = NSColor(srgbRed: 0.847, green: 0.514, blue: 0.259, alpha: 1)
let bottomColor = NSColor(srgbRed: 0.549, green: 0.278, blue: 0.153, alpha: 1)

for shot in shots {
    let srcPath = "\(srcDir)/\(shot.file).png"
    guard let src = NSImage(contentsOfFile: srcPath) else {
        print("skip: \(srcPath)")
        continue
    }

    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H),
        // 描画用。alpha 付きでないと NSGraphicsContext が作れないため、
        // 不透明化は書き出し直前に行う。
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { exit(1) }
    rep.size = NSSize(width: W, height: H)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    guard let ctx = NSGraphicsContext.current?.cgContext else { exit(1) }

    NSGradient(starting: topColor, ending: bottomColor)?
        .draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -90)

    let para = NSMutableParagraphStyle()
    para.alignment = .center
    para.lineSpacing = 8

    let title = NSAttributedString(string: shot.caption, attributes: [
        .font: NSFont.systemFont(ofSize: 84, weight: .bold),
        .foregroundColor: NSColor.white,
        .paragraphStyle: para,
    ])
    let subtitle = NSAttributedString(string: shot.sub, attributes: [
        .font: NSFont.systemFont(ofSize: 44, weight: .medium),
        .foregroundColor: NSColor.white.withAlphaComponent(0.75),
        .paragraphStyle: para,
    ])

    let margin = 80.0
    let textW = W - margin * 2
    let titleH = title.boundingRect(
        with: NSSize(width: textW, height: 500), options: [.usesLineFragmentOrigin]
    ).height
    let subH = subtitle.boundingRect(
        with: NSSize(width: textW, height: 300), options: [.usesLineFragmentOrigin]
    ).height

    let titleTop = 130.0
    title.draw(
        with: NSRect(x: margin, y: H - titleTop - titleH, width: textW, height: titleH),
        options: [.usesLineFragmentOrigin]
    )
    subtitle.draw(
        with: NSRect(
            x: margin, y: H - titleTop - titleH - 28 - subH, width: textW, height: subH
        ),
        options: [.usesLineFragmentOrigin]
    )

    // 端末画面（角丸＋影付き）
    let deviceW = W * 0.82
    let scale = deviceW / W
    let deviceH = H * scale
    let deviceX = (W - deviceW) / 2
    let captionBottom = H - titleTop - titleH - 28 - subH
    let gap = 90.0
    let deviceY = captionBottom - gap - deviceH

    let radius = 58.0 * scale * 2.4
    let frame = NSRect(x: deviceX, y: deviceY, width: deviceW, height: deviceH)

    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -18), blur: 46,
        color: NSColor.black.withAlphaComponent(0.45).cgColor
    )
    let path = NSBezierPath(roundedRect: frame, xRadius: radius, yRadius: radius)
    NSColor.white.setFill()
    path.fill()
    ctx.restoreGState()

    ctx.saveGState()
    path.addClip()
    src.draw(in: frame, from: .zero, operation: .sourceOver, fraction: 1.0)
    ctx.restoreGState()

    NSGraphicsContext.restoreGraphicsState()

    // App Store Connect はアルファ付き PNG を拒否する。
    // noneSkipLast のコンテキストへ描き直してアルファを落とす。
    guard let cg = rep.cgImage,
          let opaqueCtx = CGContext(
              data: nil, width: Int(W), height: Int(H),
              bitsPerComponent: 8, bytesPerRow: 0,
              space: CGColorSpaceCreateDeviceRGB(),
              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
          ) else {
        print("context failed: \(shot.file)")
        continue
    }
    opaqueCtx.draw(cg, in: CGRect(x: 0, y: 0, width: W, height: H))
    guard let flat = opaqueCtx.makeImage() else {
        print("flatten failed: \(shot.file)")
        continue
    }

    // NSBitmapImageRep を経由すると alpha 情報が復活するため、
    // CGImage を CGImageDestination で直接書き出す。
    let dest = "\(outDir)/\(shot.file).png"
    guard let destination = CGImageDestinationCreateWithURL(
        URL(fileURLWithPath: dest) as CFURL, "public.png" as CFString, 1, nil
    ) else {
        print("destination failed: \(shot.file)")
        continue
    }
    let props: [CFString: Any] = [kCGImagePropertyHasAlpha: false]
    CGImageDestinationAddImage(destination, flat, props as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
        print("write failed: \(shot.file)")
        continue
    }
    print("wrote \(dest)")
}
