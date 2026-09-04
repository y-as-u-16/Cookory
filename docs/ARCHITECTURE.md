# 料理記録アプリ アーキテクチャ設計書

## 1. Architecture Decision

本アプリでは以下を採用する。

```text
Feature-Based
+
Clean Architecture
+
MVVM
+
Local First
+
CQRS-lite
```

ただし、

> FeatureごとにDomain/Data/Repositoryを複製する構成

は採用しない。

採用するのは、

```text
Feature-Based
    → Presentation / Application

Shared
    → Domain / Data
```

というハイブリッド構成。

---

# 2. なぜこの構成なのか

SwiftUI自体はMVC、MVVM、Clean Architectureなど特定のアーキテクチャを要求していない。

AppleのSwiftUIチームも、SwiftUIはarchitecture-agnosticであり、アプリに合う構成を使うという方針を示している。

またAppleは、ViewとModel Dataを分離することで、

- modularity
- testability
- reasoning

を改善できるとしている。

したがって、

> Clean Architectureのフォルダ構成を機械的に再現する

ことを目的にしない。

---

# 3. Architecture Goals

本設計で達成したいもの。

```text
1. SwiftUIからSwiftDataを分離

2. DomainからFramework依存を排除

3. 将来Supabaseを追加可能

4. Offline First

5. Feature単位でUI開発可能

6. Repository乱立を防止

7. テスト可能

8. 過剰設計を避ける
```

---

# 4. Layer

依存方向：

```text
┌──────────────────────────────┐
│        Presentation          │
│ SwiftUI / ViewModel / State  │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│         Application          │
│           UseCase            │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│            Domain            │
│ Entity / ValueObject / Port  │
│  （Repository・Query・ReadModel）  │
└──────────────▲───────────────┘
               │ implements
               │
┌──────────────┴───────────────┐
│             Data             │
│ SwiftData / File / Remote    │
└──────────────────────────────┘
```

重要：

```text
Domain → Data
```

は禁止。

---

# 5. Feature-Basedの適用範囲

Feature：

```text
Home
Capture
Calendar
Cookbook
DishDetail
Memory
Search
Settings
Onboarding
```

Feature内に置くもの：

```text
View
ViewModel
Feature State
UseCase
Feature専用ReadModel
必要ならQuery Protocol
```

---

# 6. FeatureごとにDomainを作らない

NG：

```text
Features/

├── Calendar/
│   ├── Domain/
│   │   ├── CalendarMeal.swift
│   │   └── CalendarRepository.swift

├── Home/
│   ├── Domain/
│   │   ├── HomeMeal.swift
│   │   └── HomeRepository.swift

└── Cookbook/
    ├── Domain/
    │   ├── CookbookDish.swift
    │   └── CookbookRepository.swift
```

この構成では、

```text
Meal
Dish
```

という同じドメイン概念がFeatureごとに分裂しやすい。

---

# 7. Shared Domain

Domainはアプリ全体で共有する。

```text
Domain/

├── Entities/
│   ├── MealRecord.swift
│   ├── Dish.swift
│   ├── DishLog.swift
│   └── PhotoAsset.swift
│
├── ValueObjects/
│   ├── MealType.swift
│   ├── DishRating.swift
│   └── DishName.swift
│
├── Repositories/
│   ├── MealRecordRepository.swift
│   └── DishRepository.swift
│
└── Errors/
```

---

# 8. Directory Structure

初期段階では1 App Targetとする。

過剰なSwift Package分割はしない。

```text
CookingLog/
│
├── App/
│   ├── CookingLogApp.swift
│   ├── AppEnvironment.swift
│   ├── DependencyContainer.swift
│   └── Navigation/
│       ├── AppRouter.swift
│       └── AppRoute.swift
│
├── Features/
│   │
│   ├── Home/
│   │   ├── Presentation/
│   │   │   ├── HomeView.swift
│   │   │   ├── HomeViewModel.swift
│   │   │   └── Components/
│   │   └── Application/
│   │       ├── GetHomeContentUseCase.swift
│   │       └── HomeContent.swift
│   │
│   ├── Capture/
│   │   ├── Presentation/
│   │   │   ├── CaptureView.swift
│   │   │   └── CaptureViewModel.swift
│   │   └── Application/
│   │       └── CreateMealRecordUseCase.swift
│   │
│   ├── Calendar/
│   ├── Cookbook/
│   ├── DishDetail/
│   ├── Memory/
│   ├── Search/
│   ├── Settings/
│   └── Onboarding/
│
├── Domain/
│   ├── Entities/
│   ├── ValueObjects/
│   ├── Repositories/
│   └── Errors/
│
├── Data/
│   │
│   ├── Persistence/
│   │   └── SwiftData/
│   │       ├── Models/
│   │       ├── Mappers/
│   │       ├── Schema/
│   │       └── SwiftDataStore.swift
│   │
│   ├── Repositories/
│   │   ├── SwiftDataMealRecordRepository.swift
│   │   └── SwiftDataDishRepository.swift
│   │
│   ├── Queries/
│   │
│   ├── ImageStorage/
│   │   └── LocalImageStorage.swift
│   │
│   └── Sync/
│       └── // Future
│
├── Core/
│   ├── Analytics/
│   ├── Logging/
│   ├── Extensions/
│   └── Utilities/
│
├── DesignSystem/
│
├── Resources/
│
└── Tests/
```

---

# 9. なぜ1 App Targetなのか

個人開発・小規模アプリの初期段階で、

```text
HomeKit Package
CaptureKit Package
CalendarKit Package
DomainKit Package
DataKit Package
...
```

のように分割すると、

- public/internal管理
- Package依存
- build設定
- dependency graph

の管理コストが増える。

初期はフォルダによる論理境界だけを作る。

Package化は、

- チーム拡大
- Build Time問題
- 独立再利用
- 明確な依存境界が必要

になってから実施する。

---

# 10. Domain Entity

## MealRecord

1回の食卓・料理記録。

```swift
struct MealRecord: Identifiable, Sendable, Equatable {
    let id: UUID

    var occurredAt: Date
    var mealType: MealType?

    var note: String?

    var photoIDs: [UUID]
    var dishLogIDs: [UUID]

    let createdAt: Date
    var updatedAt: Date
}
```

---

# 11. Dish

料理そのもののCanonical Entity。

```swift
struct Dish: Identifiable, Sendable, Equatable {
    let id: UUID

    var name: DishName

    var isFavorite: Bool

    let createdAt: Date
    var updatedAt: Date
}
```

例：

```text
Dish

唐揚げ
```

は1件。

何度作ってもDish自体は増えない。

---

# 12. DishLog

Dishを実際に作った1回分。

```swift
struct DishLog: Identifiable, Sendable, Equatable {
    let id: UUID

    let dishID: UUID
    let mealRecordID: UUID

    var rating: DishRating?
    var note: String?

    let cookedAt: Date
}
```

これにより、

```text
Dish
唐揚げ

├── DishLog
│   2026/08/29
│
├── DishLog
│   2026/07/14
│
└── DishLog
    2026/06/03
```

を表現できる。

---

# 13. PhotoAsset

```swift
struct PhotoAsset: Identifiable, Sendable, Equatable {
    let id: UUID

    let filename: String
    let width: Int
    let height: Int

    let createdAt: Date
}
```

Domainでは、

```text
URL
UIImage
Data
```

を保持しない。

---

# 14. SwiftData Model

Domain Entityに、

```swift
@Model
```

を付けない。

NG：

```swift
@Model
final class Dish {
}
```

DomainとPersistenceを分離する。

Data：

```swift
@Model
final class DishModel {

    @Attribute(.unique)
    var id: UUID

    var name: String

    var isFavorite: Bool

    var createdAt: Date
    var updatedAt: Date
}
```

---

# 15. Mapper

```text
DishModel

 ↓

Dish
```

を明示的に変換する。

```swift
extension DishModel {

    func toDomain() -> Dish {
        // ...
    }
}
```

逆方向：

```swift
DishModel.update(from: dish)
```

---

# 16. Repository Policy

Repositoryは、

> Feature単位ではなくDomain Aggregate単位

で作る。

採用：

```text
MealRecordRepository
DishRepository
```

NG：

```text
HomeRepository
CalendarRepository
CookbookRepository
MemoryRepository
```

---

# 17. MealRecordRepository

Repositoryに画面都合のメソッドを大量追加しない。

```swift
protocol MealRecordRepository: Sendable {

    func find(
        id: UUID
    ) async throws -> MealRecord?

    func save(
        _ meal: MealRecord
    ) async throws

    func delete(
        id: UUID
    ) async throws
}
```

---

# 18. DishRepository

```swift
protocol DishRepository: Sendable {

    func find(
        id: UUID
    ) async throws -> Dish?

    func save(
        _ dish: Dish
    ) async throws

    func delete(
        id: UUID
    ) async throws
}
```

---

# 19. CQRS-lite

Calendar等では、

```text
2026年8月の
日付ごとの料理サムネイル
```

のような画面専用Queryが必要になる。

これを、

```swift
MealRecordRepository.getCalendarData()
```

に入れない。

必要になった場合、

```text
CalendarMealQuery
```

をApplication Portとして作る。

---

# 20. Query例

```swift
protocol CalendarMealQuery: Sendable {

    func execute(
        month: Date
    ) async throws -> [CalendarDaySummary]
}
```

ReadModel：

```swift
struct CalendarDaySummary: Sendable {
    let date: Date
    let mealCount: Int
    let thumbnailID: UUID?
}
```

---

# 21. Query Dependency

```text
CalendarView

↓

CalendarViewModel

↓

GetCalendarUseCase

↓

CalendarMealQuery

↓

SwiftDataCalendarMealQuery
```

QueryもRemoteを見る必要はない。

Local FirstではSwiftDataだけを見る。

---

# 22. RepositoryとQueryの違い

Repository：

```text
Domain Entity
を保存・取得する
```

Query：

```text
画面表示に最適化された
Read Modelを返す
```

これにより、

```text
巨大Repository
```

を防止する。

Query protocol と Read Model は Repository と同じく Domain に置く。

Data 層は Query を実装するため戻り値の型を参照する。これを Features 側に
置くと Data → Features の逆流になり、単一ターゲットでは import が要らない
ためコンパイラも黙ってしまう。SPM 分割を試みた瞬間に循環参照で詰む。

`scripts/check-architecture.sh` が Data・Domain から Features の型への
参照を検出する。

---

# 23. Application Layer

UseCaseはユーザー操作またはアプリのユースケース単位。

例：

```text
CreateMealRecordUseCase

UpdateMealRecordUseCase

DeleteMealRecordUseCase

AssignDishToMealUseCase

GetHomeContentUseCase

GetCalendarUseCase

GetCookbookUseCase

GetDishHistoryUseCase

GetMemoriesUseCase
```

---

# 24. Capture Flow

```text
CaptureView

↓

CaptureViewModel

↓

CreateMealRecordUseCase

├── ImageStorage
│
├── MealRecordRepository
│
└── DishRepository
```

---

# 25. CreateMealRecordUseCase

概念例：

```swift
struct CreateMealRecordUseCase {

    let mealRepository: MealRecordRepository
    let imageStorage: ImageStorage

    func execute(
        image: Data,
        occurredAt: Date
    ) async throws -> MealRecord {

        let asset = try await imageStorage.save(image)

        let now = Date()

        let meal = MealRecord(
            id: UUID(),
            occurredAt: occurredAt,
            mealType: nil,
            note: nil,
            photoIDs: [asset.id],
            dishLogIDs: [],
            createdAt: now,
            updatedAt: now
        )

        try await mealRepository.save(meal)

        return meal
    }
}
```

---

# 26. MVVM

ViewModel：

```text
Presentation State

+

User Intent受付

+

UseCase呼び出し
```

を担当。

Repository操作やSwiftData操作を直接書かない。

---

# 27. ViewModel

```swift
@MainActor
@Observable
final class CaptureViewModel {

    enum State {
        case idle
        case saving
        case saved
        case failed
    }

    var state: State = .idle

    private let createMealRecord:
        CreateMealRecordUseCase

    init(
        createMealRecord: CreateMealRecordUseCase
    ) {
        self.createMealRecord = createMealRecord
    }
}
```

ObservationはSwiftUIのModel Dataを監視する標準機構で、AppleもModelとViewの分離に利用している。

---

# 28. ViewからSwiftDataを直接使わない

今回のアーキテクチャでは原則、

```swift
@Query
```

をFeature Viewに直接置かない。

理由：

```text
View

↓

SwiftData
```

という結合がアプリ全体に広がるため。

---

# 29. 例外

以下のような完全にローカルなUI状態なら、

```text
SwiftUI State
```

をそのまま使用する。

例えば：

- Sheet開閉
- 選択中Tab
- 一時的TextField
- Animation State

すべてをUseCase化しない。

---

# 30. Persistence

ローカルデータベース：

```text
SwiftData
```

を採用。

SwiftDataではModelContainerがSchemaとStorageを管理する。

---

# 31. SwiftData Concurrency

Persistenceアクセスを、

```text
@ModelActor
```

によって隔離する。

AppleのModelActorは、ModelContextへのアクセスをActorとして直列化する仕組みを提供する。

概念：

```swift
@ModelActor
actor SwiftDataStore {
}
```

RepositoryはこのStoreを利用する。

---

# 32. Image Storage

写真BinaryをSwiftDataへ直接保存しない。

保存先：

```text
Application Support/

Images/

{UUID}/
    original.heic
```

Thumbnail：

```text
Caches/

Images/

{UUID}/
    thumbnail.jpg
```

とする。

---

# 33. なぜFile Systemか

メリット：

- SwiftData肥大化防止
- Thumbnail管理
- Cache破棄可能
- Cloud Storage移行容易
- Image Processing制御可能

DBにはMetadataのみ保存する。

---

# 34. ImageStorage Protocol

```swift
protocol ImageStorage: Sendable {

    func save(
        _ data: Data
    ) async throws -> PhotoAsset

    func load(
        id: UUID
    ) async throws -> Data

    func delete(
        id: UUID
    ) async throws
}
```

実装：

```text
LocalImageStorage
```

将来：

```text
RemoteImageSyncService
```

を追加する。

---

# 35. Image Pipeline

```text
PhotosPicker / Camera

↓

Transferable

↓

Orientation Normalization

↓

Decode

↓

Resize

↓

Compression

↓

Original保存

↓

Thumbnail生成

↓

Metadata保存
```

---

# 36. Dependency Injection

外部DI Frameworkは使用しない。

Composition Root：

```text
DependencyContainer
```

をApp Layerに置く。

```swift
struct DependencyContainer {

    let mealRepository: MealRecordRepository
    let dishRepository: DishRepository

    let imageStorage: ImageStorage
}
```

---

# 37. Production

```text
MealRecordRepository
    =
SwiftDataMealRecordRepository

DishRepository
    =
SwiftDataDishRepository

ImageStorage
    =
LocalImageStorage
```

---

# 38. Test

```text
MealRecordRepository
    =
InMemoryMealRecordRepository

DishRepository
    =
InMemoryDishRepository

ImageStorage
    =
InMemoryImageStorage
```

---

# 39. Navigation

SwiftUI：

```text
NavigationStack
```

を利用。

Featureから別FeatureのViewを直接生成しすぎない。

```swift
enum AppRoute: Hashable {

    case mealDetail(UUID)

    case dishDetail(UUID)

    case calendar(Date)

    case settings
}
```

---

# 40. AppRouter

```swift
@MainActor
@Observable
final class AppRouter {

    var path: [AppRoute] = []

    func push(_ route: AppRoute) {
        path.append(route)
    }
}
```

---

# 41. Local First

最重要方針。

将来Supabaseを導入しても、

```text
UI

↓

Supabase
```

にはしない。

---

# 42. Single Source of Truth

常に、

```text
SwiftData
```

をUIのSource of Truthにする。

```text
UI

↓

UseCase / Query

↓

SwiftData

↓

SyncEngine

↓

Supabase
```

---

# 43. Supabase導入後

```text
User Action

↓

UseCase

↓

Local Write

↓

SwiftData

↓

Sync Operation

↓

SyncEngine

↓

Supabase
```

ユーザー操作時にRemote APIの完了を待たせない。

---

# 44. Remote Data Flow

```text
Supabase

↓

SyncEngine

↓

SwiftData

↓

Query

↓

ViewModel

↓

View
```

ViewがSupabase Clientを直接見ることは禁止。

---

# 45. Sync Engine

将来Data Layerへ追加。

```text
Data/

Sync/

├── SyncEngine.swift
├── SyncOperation.swift
├── SyncQueue.swift
├── ConflictResolver.swift
└── Supabase/
```

---

# 46. Client Generated ID

IDは最初から、

```text
UUID
```

をClientで生成する。

Remote DBから発行されたIDへ依存しない。

これによりOffline作成が可能。

---

# 47. Sync Metadata

Domain Entityへ、

```text
remoteID
syncStatus
supabaseID
```

などを入れない。

Persistence側に、

```text
lastSyncedAt

serverUpdatedAt

syncRevision
```

等を保持する。

DomainをCloud仕様から守る。

---

# 48. Delete

Domainから見ると、

```text
delete
```

でよい。

クラウド同期が追加された後はData Layer内部で、

```text
Tombstone
```

として一定期間保持する。

Domain EntityにSync都合のdeletedAtを露出する必要はない。

---

# 49. Future Supabase

Cloud追加時：

```text
Supabase

├── Auth
├── Postgres
└── Storage
```

を利用。

Supabase公式SwiftチュートリアルでもAuth、Database、Storageを組み合わせる構成が案内されている。

---

# 50. Future Remote Schema

```text
users

households

household_members

meal_records

dishes

dish_logs

photo_assets

reactions

dish_requests
```

---

# 51. household

```text
households

id UUID PK

created_at
updated_at
```

---

# 52. household_members

```text
household_members

household_id
user_id
role
created_at
```

---

# 53. meal_records

```text
meal_records

id UUID PK

household_id UUID

occurred_at

meal_type

note

created_at
updated_at
deleted_at
```

---

# 54. Cloud Image

```text
PhotoAsset

↓

LocalImageStorage

↓

ImageSyncService

↓

Supabase Storage
```

Local imageは残す。

表示時に毎回Remoteから取得しない。

---

# 55. Authentication

初期：

```text
No Authentication
```

Phase 2：

```text
Supabase Auth
```

を導入。

AuthをDomainロジックに侵入させない。

---

# 56. AI Architecture

AIもProvider非依存にする。

```swift
protocol MealUnderstandingService: Sendable {

    func analyze(
        image: Data
    ) async throws -> MealUnderstandingResult
}
```

実装候補：

```text
NoOpMealUnderstandingService

FoundationModelsMealUnderstandingService

CloudMealUnderstandingService
```

---

# 57. Analytics

DomainからAnalyticsを呼ばない。

Analytics：

```text
Presentation/Application

↓

AnalyticsClient
```

Events：

```text
meal_capture_started

meal_saved

dish_named

dish_opened

memory_opened

monthly_story_shared
```

---

# 58. Error Handling

レイヤーごとにErrorを分ける。

例：

```text
ImageStorageError

PersistenceError

MealDomainError

SyncError
```

UIへ直接、

```text
SwiftData Error
Supabase Error
```

を表示しない。

ApplicationでUser Facing Errorへ変換する。

---

# 59. Logging

```text
Logger
```

Protocolを用意。

Production：

```text
OSLog
```

Test：

```text
NoOpLogger
```

---

# 60. Migration

料理記録は長期間保持するデータなのでMigrationは重要。

SwiftDataは自動Migrationに加え、複雑な変更についてVersionedSchemaとSchemaMigrationPlanを利用できる。

---

# 61. Schema Version

最初から、

```text
SchemaV1
```

を定義する。

```text
SchemaV1

↓

SchemaV2

↓

SchemaV3
```

と明示的に進化させる。

---

# 62. Export

Cloud導入前でもBackupできるようにする。

形式：

```text
CookingLogExport.zip

├── manifest.json
├── meals.json
├── dishes.json
├── dish_logs.json
└── images/
```

ユーザーが自分のデータを取り出せることを保証する。

---

# 63. Testing Strategy

## Domain Tests

Frameworkなし。

対象：

```text
DishName

DishRating

MealRecord

DishLog
```

---

# 64. UseCase Tests

Fake Repositoryを利用。

```text
CreateMealRecordUseCase

AssignDishUseCase

GetMemoriesUseCase
```

をテスト。

---

# 65. Repository Integration Tests

SwiftDataのIn-Memory Containerを利用。

対象：

```text
Save

Find

Delete

Relationship

Migration
```

---

# 66. Query Tests

例：

```text
CalendarMealQuery

CookbookQuery

MemoryQuery
```

に対して、

期待するReadModelが返ることを検証。

---

# 67. ImageStorage Tests

Temporary Directoryを使用。

```text
Save

Load

Delete

Thumbnail
```

を確認。

---

# 68. ViewModel Tests

確認：

```text
Idle

Loading

Success

Failure
```

UseCaseをFake化。

---

# 69. UI Tests

Critical Flowだけ実施。

```text
Launch

↓

Record Photo

↓

Save

↓

Calendar

↓

Detail
```

---

# 70. Migration Tests

非常に重要。

過去Version DB Fixtureから、

```text
V1

↓

Current
```

へのMigrationをCIで確認する。

---

# 71. SwiftUI Rules

View：

```text
表示

User Interaction

Animation
```

に集中。

View内に、

```text
Business Logic

Persistence

Network

Image Storage
```

を書かない。

---

# 72. ViewModel Rules

ViewModelには、

```text
View State

Intent

UseCase Invocation
```

のみ。

NG：

```text
SQL相当処理

SwiftData FetchDescriptor大量記述

Supabase API

FileManager
```

---

# 73. UseCase Rules

UseCaseは、

> ユーザーが行う意味のある操作

に対して作る。

すべての1行処理をUseCase化しない。

---

# 74. Repository Rules

RepositoryはDomain Aggregate単位。

NG：

```text
Feature名Repository
```

原則禁止。

---

# 75. Query Rules

複雑なRead UIの場合のみ作る。

簡単な取得のために大量のQuery Objectを作らない。

つまり、

```text
Repository Method
```

で十分ならRepository。

画面専用集計が複雑化したら、

```text
QueryService
```

へ昇格。

---

# 76. Domain Rules

Domainから以下をimportしない。

```text
SwiftUI

SwiftData

UIKit

PhotosUI

Supabase

StoreKit
```

Foundationのみを基本とする。

---

# 77. Data Rules

Data Layerは、

```text
Domain Protocol
```

をimplementsする。

逆方向の依存は禁止。

---

# 78. Architecture Dependency

最終的な依存構造：

```text
                 App
                  │
                  ▼
              Features
           ┌──────┴──────┐
           │             │
    Presentation    Application
           │             │
           └──────┬──────┘
                  │
                  ▼
               Domain
                  ▲
                  │
                  │ implements
                  │
                 Data
           ┌──────┼───────────┐
           │      │           │
       SwiftData Filesystem  Future
                            Supabase
```

---

# 79. Cloud導入後

```text
                 SwiftUI
                    │
                    ▼
                ViewModel
                    │
                    ▼
                 UseCase
                    │
             ┌──────┴──────┐
             │             │
             ▼             ▼
        Repository       Query
             │             │
             └──────┬──────┘
                    ▼
                SwiftData
                    │
                 SyncQueue
                    │
                SyncEngine
                    │
                    ▼
                Supabase
```

---

# 80. Architecture Rules Summary

以下をプロジェクトルールとして固定する。

```text
1.
Feature-BasedはPresentation/Applicationへ適用する。

2.
DomainはFeatureごとに分割しない。

3.
Domain Entityはアプリ全体で共有する。

4.
RepositoryはDomain Aggregate単位。

5.
HomeRepository等の画面Repositoryは禁止。

6.
複雑な画面取得はQueryServiceへ分離する。

7.
ViewからSwiftDataを直接操作しない。

8.
ViewModelからRepositoryを直接触りすぎず
UseCaseを経由する。

9.
DomainからSwiftData/Supabaseをimportしない。

10.
SwiftData ModelをDomain Entityにしない。

11.
写真BinaryをSwiftDataへ大量保存しない。

12.
UIのSource of TruthはLocal Database。

13.
Supabaseは将来Sync先として追加する。

14.
Client側でUUIDを生成する。

15.
Cloud固有情報をDomainへ入れない。

16.
初期は1 App Target。

17.
必要になるまでSPMマルチモジュール化しない。

18.
必要になるまでCQRSを複雑化しない。

19.
Migrationを最初から考慮する。

20.
アーキテクチャはフォルダ構成ではなく
Dependency Directionで守る。
```

---

# 81. Final Architecture

本プロジェクトでは、

> Feature-Based Clean Architecture MVVM

を次の意味で使用する。

```text
Feature-Based
=
画面・ユーザー機能単位で
Presentation/Applicationを整理

Clean Architecture
=
FrameworkからDomainを保護し
依存方向を内側へ向ける

MVVM
=
SwiftUIと画面状態・操作を分離

Local First
=
SwiftDataをUIのSingle Source of Truthとする

CQRS-lite
=
Repositoryを肥大化させず
必要な複雑ReadだけQueryに分離
```

これを本アプリの正式なアーキテクチャ方針とする。
