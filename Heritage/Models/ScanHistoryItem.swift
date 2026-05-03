import Foundation

struct ScanHistoryItem: Identifiable, Codable, Equatable {
    let id: UUID
    var createdAt: Date
    var imageFileName: String
    var result: HeritageAnalysisResult

    var previewOrigins: [HeritageOriginResult] {
        Array(result.origins.prefix(3))
    }
}
