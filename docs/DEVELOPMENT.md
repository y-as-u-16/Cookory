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

Two workflows run on every pull request to `main` and on pushes to `main`.

| Workflow | Runner | Purpose |
|---|---|---|
| [`ci.yml`](../.github/workflows/ci.yml) | `macos-26` | Build and run unit tests |
| [`architecture.yml`](../.github/workflows/architecture.yml) | `ubuntu-latest` | Enforce dependency rules |

The architecture check runs on Linux deliberately: it is a text-level check that
needs no Xcode, and macOS runners consume the GitHub Actions free tier at **10x**
the rate of Linux runners.

アーキテクチャ検査を Linux で動かしているのは意図的です。Xcode を必要としない
テキスト検査であり、macOS ランナーは無料枠を Linux の **10 倍** 消費するためです。

Both workflows skip documentation-only changes via `paths-ignore`, so editing a
`.md` file does not burn CI minutes.

---

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
