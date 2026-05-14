import Foundation
import StoreKit
import Combine

struct PremiumProductPresentation: Equatable {
    let featureTitle: String
    let featureSubtitle: String
    let ctaTitle: String

    static let placeholder = PremiumProductPresentation(
        featureTitle: "Premium access",
        featureSubtitle: "Loading price...",
        ctaTitle: "Loading..."
    )
}

@MainActor
final class StoreKitPremiumStore: ObservableObject {
    @Published private(set) var product: Product?
    @Published private(set) var isLoadingProduct = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var hasPremiumAccess = false
    @Published var errorMessage: String?

    private var transactionUpdatesTask: Task<Void, Never>?

    init() {
        transactionUpdatesTask = listenForTransactionUpdates()
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    var presentation: PremiumProductPresentation {
        guard let product else {
            return .placeholder
        }

        let priceLine = product.paywallPriceLine

        if let trialTitle = product.freeTrialTitle {
            return PremiumProductPresentation(
                featureTitle: trialTitle,
                featureSubtitle: "Then\n\(priceLine)",
                ctaTitle: "Unlock your family story today"
            )
        }

        return PremiumProductPresentation(
            featureTitle: priceLine,
            featureSubtitle: "Premium access",
            ctaTitle: "Unlock your family story today"
        )
    }

    func load() async {
        guard product == nil, !isLoadingProduct else {
            return
        }

        isLoadingProduct = true
        defer { isLoadingProduct = false }

        do {
            let products = try await Product.products(
                for: AppConfiguration.StoreKit.premiumProductIDs
            )
            product = AppConfiguration.StoreKit.premiumProductIDs
                .compactMap { productID in
                    products.first { $0.id == productID }
                }
                .first

            if product == nil {
                errorMessage = "Premium product is not available."
            }

            await refreshEntitlements()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func purchase() async -> Bool {
        if product == nil {
            await load()
        }

        guard let product else {
            errorMessage = "Premium product is not available."
            return false
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                if AppConfiguration.StoreKit.premiumProductIDs.contains(transaction.productID) {
                    hasPremiumAccess = true
                }
                await refreshEntitlements()
                return hasPremiumAccess
            case .pending:
                return false
            case .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func restorePurchases() async -> Bool {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            return hasPremiumAccess
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func refreshEntitlements() async {
        var isPremium = false

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result),
                  AppConfiguration.StoreKit.premiumProductIDs.contains(transaction.productID)
            else {
                continue
            }

            isPremium = true
            break
        }

        hasPremiumAccess = isPremium
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified:
            throw StoreKitPremiumError.failedVerification
        }
    }

    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else {
                    return
                }

                do {
                    let transaction = try checkVerified(result)
                    await transaction.finish()
                    await refreshEntitlements()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

private enum StoreKitPremiumError: LocalizedError {
    case failedVerification

    var errorDescription: String? {
        "StoreKit transaction verification failed."
    }
}

private extension Product {
    var freeTrialTitle: String? {
        guard let offer = subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial
        else {
            return nil
        }

        return "\(offer.period.paywallDurationText) free"
    }

    var paywallPriceLine: String {
        "\(displayPrice) per \(paywallBillingPeriodText)"
    }

    private var paywallBillingPeriodText: String {
        if id == AppConfiguration.StoreKit.premiumProductID {
            return "week"
        }

        return subscription?.subscriptionPeriod.paywallDurationText ?? "period"
    }
}

private extension Product.SubscriptionPeriod {
    var paywallDurationText: String {
        if value == 1 {
            return unit.paywallSingularText
        }

        return "\(value) \(unit.paywallPluralText)"
    }
}

private extension Product.SubscriptionPeriod.Unit {
    var paywallSingularText: String {
        switch self {
        case .day:
            "day"
        case .week:
            "week"
        case .month:
            "month"
        case .year:
            "year"
        @unknown default:
            "period"
        }
    }

    var paywallPluralText: String {
        switch self {
        case .day:
            "days"
        case .week:
            "weeks"
        case .month:
            "months"
        case .year:
            "years"
        @unknown default:
            "periods"
        }
    }
}
