# Development Guide / 開発ガイド

How to build, test, and extend Cookory.
ビルド・テスト・拡張の手順をまとめます。

---

## 1. Environment / 開発環境

| Item | Version |
|---|---|
| Xcode | 26.0+ |
| iOS Deployment Target | 26.5 |
| Swift language mode | 5.0 |
| Test framework | Swift Testing (unit) / XCTest (UI) |

No package manager is required. The project has **zero external dependencies**
by design — see [ARCHITECTURE.md](ARCHITECTURE.md) §36 on why dependency
injection is hand-rolled rather than delegated to a DI framework.

外部依存はゼロです。DI フレームワークを使わない理由は
[ARCHITECTURE.md](ARCHITECTURE.md) 第36条を参照してください。

---

## 2. Build & test / ビルドとテスト

### From Xcode

Open `Cookory.xcodeproj` and press ⌘B to build, ⌘U to test.

### From the command line

```bash
# Build only / ビルドのみ
xcodebuild build \
  -project Cookory.xcodeproj \
  -scheme Cookory \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Unit tests / ユニットテスト
xcodebuild test \
  -project Cookory.xcodeproj \
  -scheme Cookory \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:CookoryTests

# Architecture rules / アーキテクチャ規約検査
./scripts/check-architecture.sh
```

> **Do not pass `CODE_SIGNING_ALLOWED=NO` when running tests.**
> It prevents the `.xctest` bundle from loading and fails with
> `TEST EXECUTE FAILED`. Simulator builds resolve signing automatically.
>
> **テスト実行時に `CODE_SIGNING_ALLOWED=NO` を付けないでください。**
> `.xctest` バンドルがロードできず `TEST EXECUTE FAILED` になります。
> シミュレータ向けビルドは署名が自動解決されます。

---

## 3. CI / 継続的インテグレーション

Three workflows run on pull requests to `main` and on pushes to `main`.

| Workflow | Runner | Purpose |
|---|---|---|
| [`ci.yml`](../.github/workflows/ci.yml) | `macos-26` | Build and run unit tests |
| [`architecture.yml`](../.github/workflows/architecture.yml) | `ubuntu-latest` | Enforce dependency rules and block committed secrets |
| [`cd.yml`](../.github/workflows/cd.yml) | `macos-26` | Deliver to TestFlight (push to `main` only) |

The architecture check runs on Linux deliberately: it is a text-level check that
needs no Xcode, and macOS runners consume the GitHub Actions free tier at **10x**
the rate of Linux runners.

アーキテクチャ検査を Linux で動かしているのは意図的です。Xcode を必要としない
テキスト検査であり、macOS ランナーは無料枠を Linux の **10 倍** 消費するためです。

Both workflows skip documentation-only changes via `paths-ignore`, so editing a
`.md` file does not burn CI minutes.

---

## 3b. CD / 継続的デリバリー

`main` への push で TestFlight へ配信する（[`cd.yml`](../.github/workflows/cd.yml)）。

### 必要な GitHub Secrets

| Secret | 共有可否 | 内容 |
|---|---|---|
| `APP_STORE_CONNECT_KEY_ID` | 他アプリと共有 | API キーの Key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | 他アプリと共有 | API キーの Issuer ID |
| `APP_STORE_CONNECT_API_KEY` | 他アプリと共有 | `.p8` ファイルの中身 |
| `MATCH_GIT_URL` | 他アプリと共有 | 証明書リポジトリの SSH URL |
| `MATCH_PASSWORD` | 他アプリと共有 | match の暗号化パスフレーズ |
| `MATCH_DEPLOY_KEY` | 他アプリと共有 | 証明書リポジトリ read 権限の SSH 秘密鍵 |
| `DEVELOPMENT_TEAM` | 他アプリと共有 | Apple Developer Team ID |

API キーと証明書は Apple Developer アカウント単位なので、同じアカウントの他アプリと使い回せる。アプリ固有なのはプロビジョニングプロファイルだけで、これは `setup_certificates` が作る。

### 初回セットアップ

1. Apple Developer で Bundle ID `com.egi-engineer.Cookory` を登録
2. App Store Connect にアプリを作成
3. ローカルで環境変数を設定し、証明書を作成する

```bash
export DEVELOPMENT_TEAM=<Team ID>
export APP_STORE_CONNECT_KEY_ID=<Key ID>
export APP_STORE_CONNECT_ISSUER_ID=<Issuer ID>
export APP_STORE_CONNECT_API_KEY="$(cat AuthKey_XXXXX.p8)"
export MATCH_PASSWORD=<パスフレーズ>

# 書き込みが必要なため HTTPS を使う（詳細は下の注記）
export MATCH_GIT_URL=https://github.com/y-as-u-16/ios-certificates.git

bundle exec fastlane setup_certificates
```


### なぜローカルだけ HTTPS なのか

`MATCH_GIT_URL` はローカル実行と CI で形式が異なる。

| 実行場所 | URL 形式 | 認証 | 権限 |
|---|---|---|---|
| ローカル（`setup_certificates`） | HTTPS | `gh` の認証情報 | 書き込み可 |
| CI（`beta`） | SSH | `MATCH_DEPLOY_KEY` | 読み取りのみ |

証明書リポジトリの deploy key は **read only** で登録してある。CI に書き込みを許すと、Apple 側の証明書を再生成・失効させて他アプリの配信やローカル署名をまとめて壊しうるため。

プロファイルの作成は書き込みを伴うので、権限を持つローカルから実行する。

4. GitHub Secrets を登録

```bash
gh secret set APP_STORE_CONNECT_API_KEY -R y-as-u-16/Cookory < AuthKey_XXXXX.p8
gh secret set DEVELOPMENT_TEAM -R y-as-u-16/Cookory
# 以下同様
```

### なぜ Team ID を Secrets にするのか

このリポジトリは公開されており、Fastfile も誰でも読める。Team ID は秘密鍵ではないが、公開物に識別子を書かない方針で一貫させている。

同じ理由で `project.pbxproj` の `DEVELOPMENT_TEAM` は空にしてある。CD では `update_code_signing_settings` が署名前に注入する。

### Xcode が DEVELOPMENT_TEAM を書き戻す問題

自動署名が有効なため、**Xcode でプロジェクトを開くと `DEVELOPMENT_TEAM` に Team ID が書き戻される。** そのままコミットすると公開リポジトリに漏れる。

```bash
# Xcode で作業した後は確認する
git diff Cookory.xcodeproj/project.pbxproj

# 書き戻されていたら捨てる
git checkout -- Cookory.xcodeproj/project.pbxproj
```

[`scripts/check-no-secrets.sh`](../scripts/check-no-secrets.sh) が CI で検出して落とすため、見落としても main には入らない。ただし PR が赤くなるので、push 前にローカルで確認する方が早い。

### 踏んではいけない罠

| 罠 | 対処 |
|---|---|
| `macos-15` だと ASC が iOS 26 SDK 必須で 409 を返す | `runs-on: macos-26` を使う |
| CI で match がロック解除ダイアログを待ち無限ハングする | `setup_ci if is_ci` を先に呼ぶ |
| ビルド番号を CI 実行回数から採ると re-run で重複し弾かれる | `latest_testflight_build_number + 1` を使う |
| TestFlight に1件も無いと採番が例外になる | `initial_build_number: 0` を指定 |
| fastlane の標準出力にログが混ざり値が取れない | `BUILD_NUMBER_OUTPUT` でファイル経由にする |
| 秘密鍵がログに出る | `set -x` を使わない。確認は `wc -c` で |
| 配信が二重に走りビルド番号が衝突する | `concurrency: cd-testflight` / `cancel-in-progress: false` |

## 4. Architecture enforcement / アーキテクチャの強制

A rule that nothing checks is a rule that decays. These four rules from
[ARCHITECTURE.md](ARCHITECTURE.md) are machine-verified on every push:

検証されない規約は必ず腐ります。以下の4つは CI で機械的に検査されます。

| Rule | Check |
|---|---|
| §9, §76 — Domain imports only Foundation | No `import SwiftUI/SwiftData/UIKit/...` under `Cookory/Domain/` |
| §10 — Domain entities are not SwiftData models | No `@Model` under `Cookory/Domain/` |
| §7, §28 — Views never touch SwiftData directly | No `@Query`/`ModelContext`/`FetchDescriptor` under `Cookory/Features/` |
| §5, §74 — Repositories are per aggregate | No `protocol <ScreenName>Repository` anywhere |

Violations are reported as GitHub annotations on the offending line, so they
appear inline in the pull request diff.

違反は GitHub のアノテーションとして該当行に表示され、PR の差分上で直接確認
できます。

### Adding a rule / ルールを追加する

Edit [`scripts/check-architecture.sh`](../scripts/check-architecture.sh). Each
check is a `grep` feeding the shared `fail` helper. Verify a new rule by
deliberately writing a violating file, confirming the script exits non-zero,
then deleting it — a check that has never failed has never been tested.

新しいルールを追加したら、**必ずわざと違反するファイルを書いて落ちることを
確認**してください。一度も落ちたことのない検査は、検査として機能している証拠
がありません。

---

## 5. Implementation order / 実装の進め方

The layers must be built inward-out, because inner layers have no dependencies
and can be tested in isolation from the start.

内側の層から作ります。内側ほど依存がなく、最初から単体でテストできるためです。

```
1. Domain          ← Entities, ValueObjects, Repository protocols
2. Data            ← SwiftData models, mappers, repository implementations
3. Application     ← UseCases, Queries, ReadModels
4. Presentation    ← Views, ViewModels
5. App             ← DependencyContainer, routing
```

### Suggested first slice / 最初の実装単位

Build one vertical slice end-to-end before broadening. The Capture flow is the
right first choice: it is the app's core value, and it exercises every layer.

横に広げる前に、縦に1本通します。Capture フローが最適です。アプリの中核価値で
あり、全レイヤーを一度に検証できるためです。

| Step | Deliverable | Test |
|---|---|---|
| 1 | `Dish`, `MealRecord`, `DishLog`, `PhotoAsset` entities | Pure unit tests, no framework |
| 2 | `DishName`, `DishRating` value objects with validation | Boundary values, invalid input |
| 3 | `MealRecordRepository` / `DishRepository` protocols | — (protocol only) |
| 4 | In-memory fakes of both repositories | Used by later tests |
| 5 | `ImageStorage` protocol + `LocalImageStorage` | Temp directory, save/load/delete |
| 6 | `CreateMealRecordUseCase` | Fakes injected, no real I/O |
| 7 | SwiftData models + mappers + real repositories | In-memory `ModelContainer` |
| 8 | `CaptureViewModel` | Fake UseCase, assert state transitions |
| 9 | `CaptureView` | Manual verification / UI test |

---

## 6. Testing policy / テスト方針

Target: **80% coverage** on Domain and Application layers. Presentation is
covered by ViewModel state tests rather than snapshot tests.

目標は Domain 層・Application 層で **カバレッジ 80%** です。Presentation 層は
スナップショットテストではなく ViewModel の状態遷移テストで担保します。

Write the test first. The workflow is RED → GREEN → REFACTOR:

1. Write a failing test that describes the behavior
2. Confirm it fails for the expected reason
3. Write the minimum code to pass
4. Refactor with the test as a safety net

Coverage is enabled in the shared scheme, so `⌘U` in Xcode reports it directly.

カバレッジは共有スキームで有効化済みのため、Xcode で ⌘U を押せばそのまま計測
されます。

### Test naming

Describe the behavior, not the method name:

```swift
@Test func 料理名が空文字なら生成に失敗する() { }
@Test func 同じ料理を2回記録してもDishは1件のまま() { }
```

---

## 7. Roadmap / ロードマップ

Scope per phase is defined in [APP_DESIGN.md](APP_DESIGN.md) §18–24.

| Phase | Scope | Status |
|---|---|---|
| **MVP** | Capture, Home, Calendar, Cookbook, Dish History, search, export | In progress |
| **1.1** | Retention — "not cooked lately", one year ago, monthly summary, Widget | Planned |
| **1.2** | Smart Capture — on-device dish name suggestion from the photo | Planned |
| **2** | Cloud — Supabase auth, database, storage, sync | Planned |
| **2.1** | Family — household, reactions, "make it again" requests | Planned |
| **3** | Recipe — only if user demand is confirmed | Conditional |

Explicitly **not** in the MVP: login, family sharing, AI recipe generation,
social features, fridge management, shopping lists, nutrition tracking.
See [APP_DESIGN.md](APP_DESIGN.md) §19 for the full exclusion list and rationale.

MVP に **含めない** ものは [APP_DESIGN.md](APP_DESIGN.md) 第19条を参照してください。

---

## 8. Commit convention / コミット規約

One line, in Japanese, prefixed by type.

```
feat: 料理記録の保存機能を追加
fix: サムネイル生成時の向き補正を修正
refactor: MealRecordRepository の責務を整理
docs: アーキテクチャ設計書に同期戦略を追記
test: DishName のバリデーションテストを追加
chore: CI に依存方向検査を追加
```

Types: `feat` / `fix` / `refactor` / `docs` / `test` / `chore` / `perf` / `ci`

---


## 8b. Branch workflow / ブランチ運用

Every change starts with an issue. Branches are cut from that issue, and `main`
is protected: direct pushes are rejected, so every change goes through a pull
request.

**変更は必ず Issue から始める。** 新機能もバグ修正も、まず Issue を立て、それに
紐づくブランチを切ってから作業する。`main` は保護されており直接 push できない。

```bash
# 1. Issue を立てる（新規開発でもバグ修正でも必ず）
gh issue create --title "料理記録の保存機能を追加する" --body-file issue.md

# 2. Issue 番号を含むブランチを切る
git switch -c feat/4-capture-usecase

# 3. 作業してコミット
git add -A && git commit -m "feat: 料理記録の保存機能を追加"

# 4. push して PR を作る
git push -u origin feat/4-capture-usecase
gh pr create --body "Closes #4"   # Issue の紐づけは必須

# 5. CI が緑になったらマージ（ブランチは同時に削除される）
gh pr merge --squash --delete-branch

# 6. ローカルを追従させる
git switch main && git pull
```

`--delete-branch` を必ず付ける。放置するとブランチ一覧が使い物にならなくなる。

### Why an issue first / なぜ先に Issue を立てるのか

- **何をやるかを、コードを書く前に言葉にできる。** 着手してから要件が揺れると
  差分が膨らみ、PR が読めなくなる
- Issue 番号がブランチ名・PR・コミットを貫く一本の線になる。3か月後に
  「なぜこの変更をしたのか」を辿れる
- 作業前に完了条件を書いておくと、実装の途中で「どこまでやるか」を迷わない

Issue には背景・やること・完了条件をチェックリストで書く。粒度は PR 1 本ぶん
（[8c](#8c-pr-size--pr-の粒度) を参照）。

### Linking issues / Issue との紐づけ

PR 本文に `Closes #N` を書く。マージすると Issue が自動でクローズされる。

```bash
gh pr create --title "feat: Domain Entity を定義" --body "Closes #4

MealRecord / Dish / DishLog / PhotoAsset を追加した。"
```

複数の Issue を閉じる場合、**それぞれにキーワードが要る**。

```
Closes #4, closes #5     ← 両方閉じる
Closes #4, #5            ← #4 しか閉じない
```

使えるキーワード: `Closes` / `Fixes` / `Resolves`（大文字小文字は不問）

閉じずに参照だけしたいときはキーワードを付けずに `#4` と書く。

### Branch naming / ブランチ名

コミットの type をそのまま接頭辞に使う。

接頭辞に続けて Issue 番号を入れる。ブランチ名だけで出所が分かる。

```
feat/12-dish-history       機能追加
fix/18-thumbnail-rotation  バグ修正
refactor/23-meal-repo      リファクタ
docs/31-architecture       ドキュメント
chore/35-ci-cache          雑務
```

### Why PRs for a solo project / 個人開発でも PR を通す理由

- **CD が `main` への push で発火する。** 壊れたコードが直接入ると即座に TestFlight へ配信される
- CI と Guards が PR 上で走るので、`main` に入る前に規約違反や機密混入を止められる
- 差分をまとめて見返せる。3か月後の自分にとっての記録になる

管理者は保護をすり抜けて直接 push できるが、緊急時の逃げ道として残しているだけで、通常は使わない。

## 8c. PR size / PR の粒度

Issues stay small and specific. Pull requests do not: a push to `main` triggers
a TestFlight upload, and Apple rate-limits those per day.

**Issue は細かく立ててよいが、PR はまとめる。** `main` への push ごとに CD が
TestFlight へ配信するため、PR 1 本がアップロード 1 回に相当する。

2026-08-30 に Issue を 1 件ずつ PR にして 1 日で 13 回上げたところ、Apple の
アップロード上限に当たり CD が 2 回失敗した。

```
ERROR ITMS-90382: Upload limit reached ... wait 1 day
```

同じ設定・同じ Fastfile の BaseMatch は同日 7 回で問題なかったので、設定の
不備ではなく単純に回数の問題。CD のトリガー設定は正常に機能しているため
変更しない。

関連する Issue は 1 本の PR にまとめ、本文で個別に閉じる。

```
Closes #12, closes #13, closes #14
```

## 9. Before publishing / 公開前の確認

This repository is public. Before every push, confirm:

- [ ] No API keys, tokens, or credentials in the diff
- [ ] `DEVELOPMENT_TEAM` is still empty in `project.pbxproj`
- [ ] No `xcuserdata/` files staged (they leak your local username)
- [ ] No `.xcresult` or `DerivedData/` artifacts staged

`.gitignore` covers all of these, but a `git add -f` bypasses it. When in doubt:

```bash
git diff --cached --name-only   # what is actually staged
```

公開リポジトリです。push 前に上記を確認してください。`.gitignore` で対応済み
ですが、`git add -f` は無視設定を貫通します。
