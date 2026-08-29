import Foundation

extension PhotoAssetModel {
    func toDomain() -> PhotoAsset {
        PhotoAsset(id: id, filename: filename, width: width, height: height, createdAt: createdAt)
    }

    convenience init(from photo: PhotoAsset) {
        self.init(
            id: photo.id,
            filename: photo.filename,
            width: photo.width,
            height: photo.height,
            createdAt: photo.createdAt
        )
    }
}
