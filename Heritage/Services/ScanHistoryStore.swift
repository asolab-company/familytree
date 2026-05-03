import Foundation
import UIKit
import Combine

@MainActor
final class ScanHistoryStore: ObservableObject {
    @Published private(set) var items: [ScanHistoryItem] = []

    private let fileManager: FileManager
    private let metadataFileName = "scan-history.json"

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        load()
    }

    func load() {
        do {
            let data = try Data(contentsOf: metadataURL)
            items = try JSONDecoder().decode([ScanHistoryItem].self, from: data)
                .sorted { $0.createdAt > $1.createdAt }
        } catch {
            items = []
        }
    }

    func image(for item: ScanHistoryItem) -> UIImage? {
        UIImage(contentsOfFile: imageURL(for: item.imageFileName).path)
    }

    func add(image: UIImage, result: HeritageAnalysisResult) throws -> ScanHistoryItem {
        try ensureDirectory()

        let id = UUID()
        let fileName = "\(id.uuidString).jpg"
        let url = imageURL(for: fileName)

        guard let data = image.normalizedJPEGData(maxPixel: 1400, quality: 0.86) else {
            throw ScanHistoryError.imageEncodingFailed
        }

        try data.write(to: url, options: .atomic)

        let item = ScanHistoryItem(
            id: id,
            createdAt: Date(),
            imageFileName: fileName,
            result: result
        )

        items.insert(item, at: 0)
        try save()
        return item
    }

    func delete(_ item: ScanHistoryItem) {
        items.removeAll { $0.id == item.id }
        try? fileManager.removeItem(at: imageURL(for: item.imageFileName))
        try? save()
    }

    private var directoryURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ScanHistory", isDirectory: true)
    }

    private var metadataURL: URL {
        directoryURL.appendingPathComponent(metadataFileName)
    }

    private func imageURL(for fileName: String) -> URL {
        directoryURL.appendingPathComponent(fileName)
    }

    private func ensureDirectory() throws {
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
    }

    private func save() throws {
        try ensureDirectory()
        let data = try JSONEncoder().encode(items)
        try data.write(to: metadataURL, options: .atomic)
    }
}

enum ScanHistoryError: LocalizedError {
    case imageEncodingFailed

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed:
            "Could not prepare the selected image."
        }
    }
}

private extension UIImage {
    func normalizedJPEGData(maxPixel: CGFloat, quality: CGFloat) -> Data? {
        let longestSide = max(size.width, size.height)
        let scale = longestSide > maxPixel ? maxPixel / longestSide : 1
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let image = renderer.image { _ in
            UIColor.black.setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: targetSize)).fill()
            draw(in: CGRect(origin: .zero, size: targetSize))
        }

        return image.jpegData(compressionQuality: quality)
    }
}
