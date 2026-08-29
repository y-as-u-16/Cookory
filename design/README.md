# App icon / アプリアイコン

The icon is authored as SVG and rendered with macOS built-in tools only —
no ImageMagick, no Inkscape, nothing to install.

アイコンは SVG で作り、macOS 標準ツールだけで PNG 化する。
追加インストールは不要。

## Regenerating / 再生成

```bash
cd design

# Render at 2x, then downscale: smoother antialiasing than rendering at 1024.
# 2倍でレンダリングしてから縮小する。1024 で直接描くよりエッジが滑らかになる。
qlmanage -t -s 2048 -o . AppIcon.svg

sips -Z 1024 AppIcon.svg.png --out _big.png

# qlmanage always emits an alpha channel, which App Store Connect rejects.
# Round-tripping through JPEG is the only way to drop it with sips alone.
# qlmanage の出力は必ずアルファ付きになり、App Store Connect に弾かれる。
# sips だけでアルファを落とすには JPEG を経由するしかない。
sips -s format jpeg -s formatOptions best _big.png --out _flat.jpg
sips -s format png _flat.jpg --out ../Cookory/Assets.xcassets/AppIcon.appiconset/AppIcon1024.png

rm -f AppIcon.svg.png _big.png _flat.jpg

# Verify: must be 1024x1024 with hasAlpha: no
# 検証: 1024x1024 かつ hasAlpha: no であること
sips -g pixelWidth -g pixelHeight -g hasAlpha \
  ../Cookory/Assets.xcassets/AppIcon.appiconset/AppIcon1024.png
```

## Constraints / 制約

| Rule | Why |
|---|---|
| No alpha channel | App Store Connect rejects icons with transparency / 透過があるとアップロードが弾かれる |
| No rounded corners | iOS applies the squircle mask itself; baking one in leaves a hairline at the edge / OS が角丸マスクを適用するため、自分でつけると縁に線が残る |
| Fill the full square | Same reason as above / 同上 |
| One 1024x1024 file only | `actool` generates 120x120, 152x152 and the rest at build time / 残りのサイズはビルド時に自動生成される |
| Keep the subject inside the middle 80% | The corners are cropped by the mask / 角はマスクで削られる |
| Outline any text to paths | `<text>` breaks if the rendering host lacks the font / フォントが無い環境で壊れる |

## The 120x120 error / 120x120 エラーについて

An upload failing with:

```
Missing required icon file. The bundle does not contain an app icon for
iPhone / iPod Touch of exactly '120x120' pixels
```

does **not** mean a 120x120 file is missing. It means the asset catalog has no
image at all — `Contents.json` carried the slots but no `filename` key. Adding
the single 1024 entry fixes every size at once.

このエラーは 120x120 のファイルが必要という意味ではない。アセットカタログに
画像が1枚も無い（`Contents.json` に `filename` が無い）状態を指す。
1024 を1件登録すれば全サイズが解決する。

## Not yet done / 未対応

Dark and tinted variants are unset, so iOS derives them from the base icon.
Add them by placing `AppIcon1024-Dark.png` and a **fully opaque grayscale**
`AppIcon1024-Tinted.png` alongside, then declaring both in `Contents.json`.

Dark / Tinted バリアントは未設定で、iOS が元アイコンから自動生成する。
必要になったら上記2ファイルを追加して `Contents.json` に宣言する。
Tinted は**完全不透明のグレースケール**であること。
