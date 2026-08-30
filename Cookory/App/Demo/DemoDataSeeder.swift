import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// App Store 掲載用スクリーンショットのためのデモデータ。
///
/// `-seedDemoData` を付けて起動したときだけ動く。実データを汚さないよう、
/// 既に記録があれば何もしない。
struct DemoDataSeeder: Sendable {
    static let launchArgument = "-seedDemoData"

    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    private let container: DependencyContainer

    init(container: DependencyContainer) {
        self.container = container
    }

    func seed(now: Date = Date(), calendar: Calendar = .current) async throws {
        // 実データがあるときは投入しない。
        guard try await container.mealRepository.fetchRecent(limit: 1).isEmpty else { return }

        for entry in Self.entries {
            guard let dishName = DishName(entry.dish) else { continue }
            let occurredAt = calendar.date(byAdding: .day, value: -entry.daysAgo, to: now) ?? now

            let meal = try await container.createMealRecord.execute(
                images: Self.makeImages(entry.style, count: entry.photoCount),
                occurredAt: occurredAt,
                now: occurredAt
            )
            try await container.updateMealRecord.updateMeal(
                id: meal.id, mealType: entry.mealType, note: entry.mealNote, now: occurredAt
            )
            try await container.assignDishToMeal.execute(
                mealRecordID: meal.id,
                dishName: dishName,
                rating: DishRating(entry.rating),
                note: entry.logNote,
                now: occurredAt
            )
        }

        // 図鑑と Dish Detail に「お気に入り」が出るようにする。
        if let favorite = DishName("鶏の唐揚げ"),
           let dish = try await container.dishRepository.find(name: favorite) {
            try await container.dishRepository.save(dish.favoriteToggled())
        }
    }

    // MARK: - データ
    // MARK: - データ

    /// 料理の見た目の型。イラストの描き分けに使う。
    private enum DishStyle {
        case fried      // 唐揚げ
        case stew       // 肉じゃが
        case fish       // 焼き魚
        case omelet     // 卵焼き
        case curry      // カレー
        case soup       // 汁物
        case patty      // ハンバーグ
        case simmered   // 煮物
    }

    private struct Entry {
        let dish: String
        let daysAgo: Int
        let mealType: MealType
        let rating: Int
        let mealNote: String?
        let logNote: String?
        let style: DishStyle

        /// 複数枚の記録も見せるため、一部の記録に 2 枚以上入れる。
        var photoCount: Int = 1
    }

    /// 同じ料理を複数回入れて、Dish Detail に履歴が並ぶようにする。
    private static let entries: [Entry] = [
        Entry(dish: "鶏の唐揚げ", daysAgo: 1, mealType: .dinner, rating: 5,
              mealNote: "家族に好評だった", logNote: "片栗粉を多めにしたらカリッとした", style: .fried,
              photoCount: 3),
        Entry(dish: "肉じゃが", daysAgo: 3, mealType: .dinner, rating: 4,
              mealNote: nil, logNote: "煮込み時間を長めに", style: .stew),
        Entry(dish: "鮭のホイル焼き", daysAgo: 5, mealType: .dinner, rating: 4,
              mealNote: "きのこを追加", logNote: "バターを少なめでも十分", style: .fish),
        Entry(dish: "だし巻き玉子", daysAgo: 6, mealType: .breakfast, rating: 3,
              mealNote: nil, logNote: "巻きが崩れた。火を弱めに", style: .omelet),
        Entry(dish: "鶏の唐揚げ", daysAgo: 18, mealType: .dinner, rating: 4,
              mealNote: nil, logNote: "少し味が濃かった", style: .fried),
        Entry(dish: "キーマカレー", daysAgo: 21, mealType: .lunch, rating: 5,
              mealNote: "作り置きにも良い", logNote: "クミンを追加したのが正解", style: .curry,
              photoCount: 2),
        Entry(dish: "豚汁", daysAgo: 24, mealType: .dinner, rating: 4,
              mealNote: nil, logNote: "根菜を大きめに切る", style: .soup),
        Entry(dish: "鶏の唐揚げ", daysAgo: 46, mealType: .dinner, rating: 3,
              mealNote: nil, logNote: "二度揚げを試した", style: .fried),
        Entry(dish: "ハンバーグ", daysAgo: 83, mealType: .dinner, rating: 5,
              mealNote: "デミグラスから手作り", logNote: "つなぎを減らして肉感を出した", style: .patty),
        Entry(dish: "ぶり大根", daysAgo: 95, mealType: .dinner, rating: 4,
              mealNote: nil, logNote: "下茹でを丁寧に", style: .simmered),
    ]

    /// 料理のイラストを描く。
    ///
    /// 実際の料理写真を同梱すると権利の確認が都度必要になるため、
    /// 皿と料理を図形で描く。掲載画像でも料理の違いが分かるようにする。
    /// 同じ料理でも少しずつ違う絵にする。皿の向きを変えて複数枚を作る。
    private static func makeImages(_ style: DishStyle, count: Int) -> [Data] {
        (0..<max(1, count)).map { makeImage(style, variant: $0) }
    }

    private static func makeImage(_ style: DishStyle, variant: Int = 0) -> Data {
        let size = 900
        guard let context = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return Data() }

        let side = CGFloat(size)
        drawBackground(in: context, side: side, style: style)
        drawPlate(in: context, side: side, style: style)

        // 変化形は皿ごと回して別カットに見せる。
        context.saveGState()
        context.translateBy(x: side / 2, y: side / 2)
        context.rotate(by: CGFloat(variant) * 0.5)
        context.translateBy(x: -side / 2, y: -side / 2)
        drawFood(in: context, side: side, style: style)
        context.restoreGState()

        guard let image = context.makeImage() else { return Data() }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, UTType.jpeg.identifier as CFString, 1, nil
        ) else { return Data() }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
        return output as Data
    }

    /// テーブル面。木目を思わせる暖色のグラデーション。
    private static func drawBackground(in context: CGContext, side: CGFloat, style: DishStyle) {
        let space = CGColorSpaceCreateDeviceRGB()
        let top = rgb(0.87, 0.79, 0.70)
        let bottom = rgb(0.76, 0.66, 0.56)
        if let gradient = CGGradient(
            colorsSpace: space, colors: [top, bottom] as CFArray, locations: [0, 1]
        ) {
            context.drawLinearGradient(
                gradient, start: .zero, end: CGPoint(x: 0, y: side), options: []
            )
        }
    }

    /// 白い皿。真上から見た構図にする。
    private static func drawPlate(in context: CGContext, side: CGFloat, style: DishStyle) {
        let center = CGPoint(x: side / 2, y: side / 2)
        let outer = side * 0.40

        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: -side * 0.012),
            blur: side * 0.045,
            color: rgba(0, 0, 0, 0.28)
        )
        context.setFillColor(rgb(0.98, 0.97, 0.96))
        context.fillEllipse(in: CGRect(
            x: center.x - outer, y: center.y - outer, width: outer * 2, height: outer * 2
        ))
        context.restoreGState()

        // 皿の縁。内側をわずかに暗くして立体感を出す。
        context.setStrokeColor(rgba(0, 0, 0, 0.07))
        context.setLineWidth(side * 0.006)
        let inner = outer * 0.82
        context.strokeEllipse(in: CGRect(
            x: center.x - inner, y: center.y - inner, width: inner * 2, height: inner * 2
        ))
    }

    private static func drawFood(in context: CGContext, side: CGFloat, style: DishStyle) {
        let center = CGPoint(x: side / 2, y: side / 2)
        switch style {
        case .fried:
            scatter(in: context, center: center, side: side, count: 7, radius: side * 0.075,
                    colors: [rgb(0.85, 0.60, 0.25), rgb(0.78, 0.51, 0.19)], jitter: side * 0.13)
        case .stew:
            fillBowl(in: context, center: center, side: side, color: rgb(0.72, 0.45, 0.22))
            scatter(in: context, center: center, side: side, count: 5, radius: side * 0.055,
                    colors: [rgb(0.92, 0.82, 0.55), rgb(0.85, 0.42, 0.22)], jitter: side * 0.10)
        case .fish:
            let w = side * 0.34, h = side * 0.17
            roundedRect(in: context, rect: CGRect(
                x: center.x - w / 2, y: center.y - h / 2, width: w, height: h
            ), radius: h * 0.4, color: rgb(0.90, 0.55, 0.42))
            for index in 0..<3 {
                let y = center.y - h / 2 + h * CGFloat(index + 1) / 4
                context.setStrokeColor(rgba(1, 1, 1, 0.45))
                context.setLineWidth(side * 0.008)
                context.move(to: CGPoint(x: center.x - w / 2 + side * 0.02, y: y))
                context.addLine(to: CGPoint(x: center.x + w / 2 - side * 0.02, y: y))
                context.strokePath()
            }
        case .omelet:
            let w = side * 0.36, h = side * 0.20
            roundedRect(in: context, rect: CGRect(
                x: center.x - w / 2, y: center.y - h / 2, width: w, height: h
            ), radius: h * 0.45, color: rgb(0.96, 0.83, 0.35))
            context.setStrokeColor(rgba(0.80, 0.62, 0.18, 0.7))
            context.setLineWidth(side * 0.007)
            context.move(to: CGPoint(x: center.x - w * 0.15, y: center.y - h / 2))
            context.addLine(to: CGPoint(x: center.x - w * 0.15, y: center.y + h / 2))
            context.strokePath()
        case .curry:
            // 皿の半分にごはん、半分にルー。
            let r = side * 0.30
            context.setFillColor(rgb(0.97, 0.95, 0.90))
            context.fillEllipse(in: CGRect(
                x: center.x - r, y: center.y - r, width: r * 2, height: r * 2
            ))
            context.saveGState()
            context.addRect(CGRect(x: center.x, y: center.y - r, width: r, height: r * 2))
            context.clip()
            context.setFillColor(rgb(0.62, 0.36, 0.15))
            context.fillEllipse(in: CGRect(
                x: center.x - r, y: center.y - r, width: r * 2, height: r * 2
            ))
            context.restoreGState()
        case .soup:
            fillBowl(in: context, center: center, side: side, color: rgb(0.66, 0.45, 0.28))
            scatter(in: context, center: center, side: side, count: 4, radius: side * 0.040,
                    colors: [rgb(0.95, 0.92, 0.86), rgb(0.55, 0.62, 0.35)], jitter: side * 0.09)
        case .patty:
            let r = side * 0.19
            context.setFillColor(rgb(0.48, 0.29, 0.17))
            context.fillEllipse(in: CGRect(
                x: center.x - r, y: center.y - r * 0.78, width: r * 2, height: r * 1.56
            ))
            context.setFillColor(rgba(0.30, 0.16, 0.08, 0.55))
            context.fillEllipse(in: CGRect(
                x: center.x - r * 0.55, y: center.y - r * 0.30, width: r * 1.1, height: r * 0.6
            ))
        case .simmered:
            scatter(in: context, center: center, side: side, count: 4, radius: side * 0.085,
                    colors: [rgb(0.93, 0.90, 0.82), rgb(0.60, 0.42, 0.24)], jitter: side * 0.11)
        }
    }

    // MARK: - 描画の部品

    private static func fillBowl(
        in context: CGContext, center: CGPoint, side: CGFloat, color: CGColor
    ) {
        let r = side * 0.30
        context.setFillColor(color)
        context.fillEllipse(in: CGRect(
            x: center.x - r, y: center.y - r, width: r * 2, height: r * 2
        ))
    }

    /// 具材を散らす。乱数は使わず固定の配置にして、撮り直しても同じ絵にする。
    private static func scatter(
        in context: CGContext, center: CGPoint, side: CGFloat,
        count: Int, radius: CGFloat, colors: [CGColor], jitter: CGFloat
    ) {
        for index in 0..<count {
            let angle = CGFloat(index) * (.pi * 2 / CGFloat(count)) + 0.4
            let distance = index == 0 ? 0 : jitter
            let point = CGPoint(
                x: center.x + cos(angle) * distance,
                y: center.y + sin(angle) * distance
            )
            context.setFillColor(colors[index % colors.count])
            context.fillEllipse(in: CGRect(
                x: point.x - radius, y: point.y - radius * 0.85,
                width: radius * 2, height: radius * 1.7
            ))
        }
    }

    private static func roundedRect(
        in context: CGContext, rect: CGRect, radius: CGFloat, color: CGColor
    ) {
        let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        context.setFillColor(color)
        context.addPath(path)
        context.fillPath()
    }

    private static func rgb(_ r: Double, _ g: Double, _ b: Double) -> CGColor {
        rgba(r, g, b, 1)
    }

    private static func rgba(_ r: Double, _ g: Double, _ b: Double, _ a: Double) -> CGColor {
        CGColor(
            colorSpace: CGColorSpaceCreateDeviceRGB(),
            components: [CGFloat(r), CGFloat(g), CGFloat(b), CGFloat(a)]
        ) ?? CGColor(gray: 0.5, alpha: 1)
    }
}
