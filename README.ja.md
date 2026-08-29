# Cookory

> 作った料理を撮るだけで、わが家の料理の歴史が育っていく。

家庭料理を記録する iOS アプリです。レシピを探すアプリではなく、実際に作った
料理・その上達・わが家の定番になったものを残すことに特化しています。

**English version: [README.md](README.md)**

[![CI](https://github.com/y-as-u-16/Cookory/actions/workflows/ci.yml/badge.svg)](https://github.com/y-as-u-16/Cookory/actions/workflows/ci.yml)
[![Architecture](https://github.com/y-as-u-16/Cookory/actions/workflows/architecture.yml/badge.svg)](https://github.com/y-as-u-16/Cookory/actions/workflows/architecture.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## 開発状況

**初期段階です。** 設計は完了してドキュメント化されていますが、実装はこれから
です。現時点でアプリとして動作する機能はありません。

| 領域 | 状態 |
|---|---|
| プロダクト設計・アーキテクチャ設計 | 文書化済み（[docs/](docs/)） |
| CI（ビルド・テスト・規約検査） | 稼働中 |
| Domain / Data / Feature 各層 | 未実装 |

---

## コンセプト

多くの料理アプリは「次に何を作るか」に答えます。Cookory が答えるのは別の問い
です。「今まで何を作り、何がわが家のものになったか」。

```
作る → 撮る → 数秒で記録 → 過去の同じ料理とつながる
 ↑                                        │
 └────────── 「また作ろう」 ←──────────────┘
```

貫く原則はひとつです。

> **記録するときは極限までシンプルに。振り返るときは驚くほど豊かに。**

必須入力は写真だけです。料理名・評価・メモはすべて任意で、後から足しても、
足さなくても構いません。

---

## 中核機能

- **Capture** — 10 秒以内で記録。写真は他の入力を待たずに先に保存される
- **Cookbook** — 実際に作った料理だけで構成される、自分専用の料理図鑑
- **History** — 同じ料理を作った履歴を時系列で並べ、上達を見えるようにする
- **Memory** — しばらく作っていない料理や、1 年前の今日作った料理を再発見する

---

## アーキテクチャ

Feature-Based + Clean Architecture + MVVM を、ローカルファースト・CQRS-lite で
構成しています。

```
Presentation  →  Application  →  Domain  ←  Data
 SwiftUI          UseCase        Entity     SwiftData
 ViewModel        Query          Port       FileSystem
```

依存は常に内側を向きます。`Domain` は `Foundation` 以外を import しないため、
ビジネスルールが SwiftUI・SwiftData・将来のバックエンドから独立します。

特に重要な3つの判断:

1. **SwiftData のモデルを Domain Entity にしない。** 別の型として定義し、明示的
   なマッパーで変換します。永続化の都合がビジネスルールに漏れないようにするため
   です。
2. **Repository は集約単位で作り、画面単位では作らない。** `HomeRepository` は
   禁止、`MealRecordRepository` が正解です。画面固有の読み取りは Query オブジェクト
   として分離します。
3. **ローカル DB が唯一の正とする。** 将来クラウド同期を追加しても、それは
   SwiftData の**背後**に置きます。UI がリモート API を直接見ることはありません。

これらは努力目標ではありません。[`scripts/check-architecture.sh`](scripts/check-architecture.sh)
が CI で検査し、違反があればビルドを失敗させます。

設計の全文: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

---

## ドキュメント

| ドキュメント | 内容 |
|---|---|
| [docs/APP_DESIGN.md](docs/APP_DESIGN.md) | プロダクト設計 — コンセプト、UX原則、画面設計、MVP範囲、ロードマップ |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | 技術設計 — レイヤー構成、エンティティ、永続化、テスト、同期戦略 |
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | ビルド・テスト・変更の進め方 |

---

## 動作環境

- Xcode 26 以降
- iOS 26.5 以降（Deployment Target）
- Swift 5.0 言語モード

## セットアップ

```bash
git clone https://github.com/y-as-u-16/Cookory.git
cd Cookory
open Cookory.xcodeproj
```

`DEVELOPMENT_TEAM` は意図的に空にしてあります。署名情報なしでビルドが通る
ようにするためです。実機で動かす場合は Xcode の *Signing & Capabilities* タブで
ご自身のチームを設定してください。シミュレータなら設定は不要です。

コマンドラインからテストを実行する場合:

```bash
xcodebuild test \
  -project Cookory.xcodeproj \
  -scheme Cookory \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:CookoryTests
```

---

## ライセンス

[MIT](LICENSE) © 2026 y_as_u_16

ソースコードは MIT ライセンスです。ただし *Cookory* という名称・アイコン・
App Store 上のアプリそのものは、このライセンスの対象に含みません。
