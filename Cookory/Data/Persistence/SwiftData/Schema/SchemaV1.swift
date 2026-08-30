import Foundation
import SwiftData

/// 初版のスキーマ。
///
/// 最初からバージョンを切っておく。料理記録は年単位で残るデータで、
/// 移行が必要になってからバージョニングを導入すると既存データを救えない。
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            MealRecordModel.self, DishModel.self, DishLogModel.self,
            PhotoAssetModel.self, RecipeModel.self,
        ]
    }
}

/// 現時点では V1 のみ。V2 を足す際はここに Migration Stage を追加する。
enum CookoryMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }

    static var stages: [MigrationStage] { [] }
}
