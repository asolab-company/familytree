import Foundation

@MainActor
enum SmartAnalysisProgress {
    static let initialValue = 0.02
    static let maximumWaitingValue = 0.98

    static func nextWaitingValue(from progress: Double) -> Double {
        guard progress < maximumWaitingValue else {
            return maximumWaitingValue
        }

        let step: Double
        switch progress {
        case ..<0.35:
            step = 0.010
        case ..<0.65:
            step = 0.006
        case ..<0.85:
            step = 0.003
        case ..<0.94:
            step = 0.0015
        default:
            step = 0.0007
        }

        return min(progress + step, maximumWaitingValue)
    }

    static func complete(
        from progress: Double,
        duration: UInt64 = 2_000_000_000,
        update: (Double) -> Void
    ) async {
        let steps = 20
        let interval = duration / UInt64(steps)
        let start = min(max(progress, 0), 1)

        for step in 1...steps {
            try? await Task.sleep(nanoseconds: interval)
            let fraction = Double(step) / Double(steps)
            update(start + (1 - start) * fraction)
        }
    }
}
