# App Store 掲載画像の作り方

## 1. スクリーンショットを撮る

デモデータは `-seedDemoData` でアプリが自前で投入する（`DemoDataSeeder`）。
実データがある端末では投入しないため、**シミュレータを消してから撮る**。

```bash
xcrun simctl erase <device-id>

# 日本語
xcodebuild test -project Cookory.xcodeproj -scheme Cookory \
  -destination 'platform=iOS Simulator,id=<device-id>' \
  -only-testing:CookoryUITests/ScreenshotTests \
  -testLanguage ja -testRegion JP -resultBundlePath /tmp/shots-ja.xcresult

# 英語
xcodebuild test ... -testLanguage en -testRegion US -resultBundlePath /tmp/shots-en.xcresult
```

xcresult から PNG を取り出して名前を戻す:

```bash
xcrun xcresulttool export attachments \
  --path /tmp/shots-ja.xcresult --output-path /tmp/ex-ja

mkdir -p /tmp/shots-ja && cd /tmp/ex-ja
for f in *.png; do
  NAME=$(grep -A5 "\"$f\"" manifest.json | grep -oE '[0-9]{2}-[a-z-]+' | head -1)
  [ -n "$NAME" ] && cp "$f" "/tmp/shots-ja/$NAME.png"
done
```

## 2. キャッチコピーを合成する

```bash
swift tools/appstore/compose-screenshots.swift /tmp/shots-ja fastlane/screenshots/ja ja
swift tools/appstore/compose-screenshots.swift /tmp/shots-en fastlane/screenshots/en-US en
```

出力は 1320×2868（App Store 6.9インチ必須サイズ）、アルファ無し。
App Store Connect はアルファ付き PNG を拒否するため、書き出し前に落としている。

## 素材の置き場所

| 対象 | 場所 | git |
|---|---|---|
| 掲載テキスト | `fastlane/metadata/` | 追跡する |
| スクリーンショット | `fastlane/screenshots/` | 除外（サイズが大きい） |
| 審査担当者向け連絡先 | `fastlane/metadata/review_information/` | **除外（個人情報）** |

**パブリックリポジトリのため、氏名・電話番号・メールアドレスは追跡しない。**
`review_information/` に置いた内容は App Store Connect の画面から手で入れる。

## 撮影時の落とし穴

### デモデータが入らない

`DemoDataSeeder` は既に記録があると何もしない。前回の撮影データが残っていると
古い画像のまま撮れてしまうため、必ず `simctl erase` してから撮る。

### 遷移したつもりで遷移していない

図鑑から詳細画面へのタップは、遷移先にしか無い要素（`dishCookCount`）で
確認している。戻るボタンやナビゲーションバーは図鑑にも存在するため、
それらで確認すると失敗を検出できない。

### シミュレータが不安定

`Application failed preflight checks` や `server died` は端末側の問題で、
コードの誤りではない。`simctl erase` してから再実行する。

## ASC の画面でしか設定できないもの

fastlane では入らないため、初回は手で設定する。

- プライマリカテゴリ（フード＆ドリンク）
- コンテンツ配信権
- アプリのプライバシー（データを収集していません）
- 価格（無料）と配信国
- 年齢制限の質問票（すべて「なし」→ 4+）
- DSA トレーダーステータス（個人開発なら非トレーダー）
- 審査担当者向けの連絡先
- ビルドの選択

## 3. App Store Connect へ登録する

### 認証情報

```bash
export APP_STORE_CONNECT_KEY_ID="..."
export APP_STORE_CONNECT_ISSUER_ID="..."
export APP_STORE_CONNECT_API_KEY="$(cat /path/to/AuthKey_XXXX.p8)"
```

### 掲載テキスト

```bash
bundle exec fastlane upload_text_only
```

### スクリーンショット

```bash
bundle exec ruby tools/appstore/sync_screenshots.rb
```

**fastlane の `deliver` でスクショを送らないこと。** `overwrite_screenshots` は
削除直後にアップロードを始めるため、ASC 側の反映が間に合わず「アップロード
されていない」と誤判定してリトライし、毎回二重に登録される。

`sync_screenshots.rb` は 削除 → 0 枚になるまで待機 → アップロード → 検証 を
順に行うため、この問題が起きない。
