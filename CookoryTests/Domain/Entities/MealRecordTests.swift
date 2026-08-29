import Foundation
import Testing
@testable import Cookory

struct MealRecordTests {
    private let occurredAt = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func 写真を追加するとphotoIDsに反映される() {
        let photoID = UUID()
        let record = MealRecord(occurredAt: occurredAt).addingPhoto(photoID)

        #expect(record.photoIDs == [photoID])
    }

    @Test func 同じ写真を二度追加しても重複しない() {
        let photoID = UUID()
        let record = MealRecord(occurredAt: occurredAt)
            .addingPhoto(photoID)
            .addingPhoto(photoID)

        #expect(record.photoIDs.count == 1)
    }

    @Test func 写真を削除できる() {
        let keep = UUID()
        let remove = UUID()
        let record = MealRecord(occurredAt: occurredAt)
            .addingPhoto(keep)
            .addingPhoto(remove)
            .removingPhoto(remove)

        #expect(record.photoIDs == [keep])
    }

    @Test func 更新してもcreatedAtは変わらない() {
        let created = Date(timeIntervalSince1970: 1_000)
        let updated = Date(timeIntervalSince1970: 2_000)
        let record = MealRecord(occurredAt: occurredAt, createdAt: created)
            .addingPhoto(UUID(), at: updated)

        #expect(record.createdAt == created)
        #expect(record.updatedAt == updated)
    }

    @Test func 変化がなければupdatedAtも動かない() {
        let created = Date(timeIntervalSince1970: 1_000)
        let photoID = UUID()
        let record = MealRecord(occurredAt: occurredAt, createdAt: created)
            .addingPhoto(photoID, at: created)

        let unchanged = record.addingPhoto(photoID, at: Date(timeIntervalSince1970: 9_999))

        #expect(unchanged.updatedAt == created)
    }

    @Test func 空白だけのメモはnilになる() {
        let record = MealRecord(occurredAt: occurredAt, note: "   ")

        #expect(record.note == nil)
    }

    @Test func 等価性はIDだけでなく全フィールドを見る() {
        let id = UUID()
        let created = Date(timeIntervalSince1970: 1_000)
        let a = MealRecord(id: id, occurredAt: occurredAt, createdAt: created)
        let b = MealRecord(id: id, occurredAt: occurredAt, mealType: .dinner, createdAt: created)

        #expect(a != b)
    }

    @Test func 写真なしでも記録は成立する() {
        let record = MealRecord(occurredAt: occurredAt)

        #expect(record.photoIDs.isEmpty)
        #expect(record.mealType == nil)
    }
}
