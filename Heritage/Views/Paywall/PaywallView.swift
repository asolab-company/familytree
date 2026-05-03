import SwiftUI

enum PaywallVariant: Equatable {
    case main
    case heritageResult
}

struct PaywallView: View {
    @Binding var selectedScreen: AppScreen
    var variant: PaywallVariant = .heritageResult
    var analysisResult: HeritageAnalysisResult? = nil
    var onSkip: (() -> Void)? = nil
    var onPremiumActivated: (() -> Void)? = nil

    @EnvironmentObject private var premiumStore: StoreKitPremiumStore

    private var result: HeritageAnalysisResult {
        analysisResult ?? .placeholder
    }

    var body: some View {
        DesignAdaptiveScreenContainer { metrics in
            ZStack(alignment: .topLeading) {
                PaywallBackground(height: metrics.visibleHeight)

                if variant == .main {
                    VStack(spacing: 0) {
                        PaywallPremiumSection(
                            layout: .main(metrics: metrics),
                            onSkip: closePaywall,
                            onPremiumActivated: activatePremiumAndClose
                        )
                        .environmentObject(premiumStore)
                        .padding(.top, metrics.isCompactHeight ? 82 : 124)
                        .padding(.horizontal, 19)
                    }
                    .frame(
                        width: AppMetrics.designWidth,
                        height: metrics.visibleHeight,
                        alignment: .top
                    )
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            PaywallHero()
                                .paywallHeroMode(variant)
                                .padding(.top, 126)

                            PaywallResultCard()
                                .environment(\.heritageAnalysisResult, result)
                                .padding(.top, 32)
                                .padding(.horizontal, 19)

                            PaywallSurnameInfoCard()
                                .environment(\.heritageAnalysisResult, result)
                                .padding(.top, 16)
                                .padding(.horizontal, 19)

                            PaywallPremiumSection(
                                layout: .regular,
                                onSkip: closePaywall,
                                onPremiumActivated: activatePremiumAndClose
                            )
                            .environmentObject(premiumStore)
                            .padding(.top, 16)
                            .padding(.horizontal, 19)
                            .padding(.bottom, metrics.scrollBottomPadding)
                        }
                        .frame(width: AppMetrics.designWidth)
                    }
                    .frame(
                        width: AppMetrics.designWidth,
                        height: metrics.visibleHeight
                    )
                }

                DesignHitButton(x: 19, y: 67, width: 40, height: 40) {
                    closePaywall()
                }
            }
        }
        .task {
            await premiumStore.load()
        }
    }

    private func closePaywall() {
        if let onSkip {
            onSkip()
        } else {
            selectedScreen = .familyTree
        }
    }

    private func activatePremiumAndClose() {
        if let onPremiumActivated {
            onPremiumActivated()
        } else {
            selectedScreen = .familyTree
        }
    }
}

struct MainPaywallView: View {
    @Binding var selectedScreen: AppScreen
    var onSkip: (() -> Void)? = nil
    var onPremiumActivated: (() -> Void)? = nil

    var body: some View {
        PaywallView(
            selectedScreen: $selectedScreen,
            variant: .main,
            onSkip: onSkip,
            onPremiumActivated: onPremiumActivated
        )
    }
}

private struct HeritageAnalysisResultKey: EnvironmentKey {
    static let defaultValue = HeritageAnalysisResult.placeholder
}

private extension EnvironmentValues {
    var heritageAnalysisResult: HeritageAnalysisResult {
        get { self[HeritageAnalysisResultKey.self] }
        set { self[HeritageAnalysisResultKey.self] = newValue }
    }
}

private struct PaywallBackground: View {
    let height: CGFloat

    var body: some View {
        LinearGradient(
            colors: [AppColors.bgTop, AppColors.bgBottom],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: AppMetrics.designWidth, height: height)
    }
}

private struct PaywallHero: View {
    @Environment(\.paywallVariant) private var variant

    var body: some View {
        VStack(spacing: 0) {
            if variant == .heritageResult {
                Image(DesignAsset.Loading.logo)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 130, height: 130)
                    .accessibilityHidden(true)

                Text("Your Family Tree Is Ready")
                    .font(AppTypography.bold(24))
                    .foregroundColor(AppColors.gold)
                    .multilineTextAlignment(.center)
                    .frame(width: 263)
                    .padding(.top, 44)

                Text(
                    "We’ve prepared your personalized family tree insights.\nTo view your full results and unlock your complete\nfamily history, please upgrade to Premium."
                )
                .font(AppTypography.regular(16))
                .foregroundColor(AppColors.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 356)
                .padding(.top, 9)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct PaywallVariantKey: EnvironmentKey {
    static let defaultValue: PaywallVariant = .heritageResult
}

private extension EnvironmentValues {
    var paywallVariant: PaywallVariant {
        get { self[PaywallVariantKey.self] }
        set { self[PaywallVariantKey.self] = newValue }
    }
}

private extension View {
    func paywallHeroMode(_ variant: PaywallVariant) -> some View {
        environment(\.paywallVariant, variant)
    }
}

private struct PaywallResultCard: View {
    @Environment(\.heritageAnalysisResult) private var result

    var body: some View {
        ZStack {
            PaywallInfoCardBackground(cornerRadius: 32)

            VStack(spacing: 16) {
                Text("Result:")
                    .font(AppTypography.bold(16))
                    .foregroundColor(AppColors.gold)

                VStack(spacing: 8) {
                    ForEach(result.origins) { row in
                        PaywallCountryRow(row: row) .blur(radius: 4)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .frame(width: 356, height: 230)
    }
}

private struct PaywallCountryRow: View {
    let row: HeritageOriginResult

    var body: some View {
        HStack(spacing: 8) {
            Image(row.flagAssetName)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

            Text(row.country)
                .font(AppTypography.regular(16))
                .foregroundColor(AppColors.muted)

            Spacer(minLength: 12)

            Text(row.percentText)
                .font(AppTypography.regular(16))
                .foregroundColor(AppColors.gold)
                .frame(minWidth: 28, alignment: .trailing)
        }
        .frame(height: 24)
    }
}

private struct PaywallSurnameInfoCard: View {
    @Environment(\.heritageAnalysisResult) private var result

    var body: some View {
        ZStack(alignment: .topLeading) {
            PaywallInfoCardBackground(cornerRadius: 32)

            PaywallSurnameText(result: result)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .blur(radius: 4)
            
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: 356, alignment: .topLeading)
       
    }
}

private struct PaywallInfoCardBackground: View {
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(AppColors.card)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppColors.gold.opacity(0.21), lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppColors.white.opacity(0.04), lineWidth: 1)
            )
            .shadow(color: AppColors.black.opacity(0.25), radius: 1, x: 0, y: 0)
    }
}

private struct PaywallSurnameText: View {
    let result: HeritageAnalysisResult

    var body: some View {
        Text(result.surnameDescription)
            .font(AppTypography.regular(16))
            .foregroundColor(AppColors.gold)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PaywallPremiumLayout {
    let cardHeight: CGFloat
    let cardRowSpacing: CGFloat
    let iconSize: CGSize
    let iconTop: CGFloat
    let titleTop: CGFloat
    let titleFontSize: CGFloat
    let subtitleFontSize: CGFloat
    let subscriptionTop: CGFloat
    let buttonTop: CGFloat
    let buttonHeight: CGFloat
    let legalTop: CGFloat

    static let regular = PaywallPremiumLayout(
        cardHeight: 232,
        cardRowSpacing: 16,
        iconSize: CGSize(width: 72, height: 84),
        iconTop: 24,
        titleTop: 24,
        titleFontSize: 16,
        subtitleFontSize: 16,
        subscriptionTop: 29,
        buttonTop: 30,
        buttonHeight: 60,
        legalTop: 17
    )

    static func main(metrics: DesignAdaptiveMetrics) -> PaywallPremiumLayout {
        guard metrics.isCompactHeight else {
            return .regular
        }

        return PaywallPremiumLayout(
            cardHeight: 176,
            cardRowSpacing: 12,
            iconSize: CGSize(width: 54, height: 62),
            iconTop: 16,
            titleTop: 12,
            titleFontSize: 15,
            subtitleFontSize: 15,
            subscriptionTop: 16,
            buttonTop: 16,
            buttonHeight: 54,
            legalTop: 10
        )
    }
}

private struct PaywallPremiumSection: View {
    @EnvironmentObject private var premiumStore: StoreKitPremiumStore
    @Environment(\.openURL) private var openURL

    let layout: PaywallPremiumLayout
    let onSkip: () -> Void
    let onPremiumActivated: () -> Void

    private var features: [PaywallPremiumFeature] {
        [
            PaywallPremiumFeature(
                title: "Ethnic origin",
                subtitle: "Discover the\ncultures behind\nyour DNA.",
                iconName: DesignAsset.Paywall.icon04
            ),
            PaywallPremiumFeature(
                title: "Unlimited family tree",
                subtitle: "Build generations\nwithout\nlimits.",
                iconName: DesignAsset.Paywall.icon03
            ),
            PaywallPremiumFeature(
                title: "Photo restoration",
                subtitle: "Bring old\nmemories back\nto life.",
                iconName: DesignAsset.Paywall.icon02
            ),
            PaywallPremiumFeature(
                title: premiumStore.presentation.featureTitle,
                subtitle: premiumStore.presentation.featureSubtitle,
                iconName: DesignAsset.Paywall.icon01
            ),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: layout.cardRowSpacing) {
                HStack(spacing: 16) {
                    PaywallFeatureCard(feature: features[0], layout: layout)
                    PaywallFeatureCard(feature: features[1], layout: layout)
                }

                HStack(spacing: 16) {
                    PaywallFeatureCard(feature: features[2], layout: layout)
                    PaywallFeatureCard(feature: features[3], layout: layout)
                }
            }

            Text("Subscription auto-renews. Cancel anytime.")
                .font(AppTypography.medium(12))
                .foregroundColor(Color(hex: 0x575757))
                .multilineTextAlignment(.center)
                .frame(width: 332)
                .padding(.top, layout.subscriptionTop)

            Button {
                Task {
                    let didActivatePremium = await premiumStore.purchase()
                    if didActivatePremium {
                        onPremiumActivated()
                    }
                }
            } label: {
                ZStack {
                    GradientPrimaryButtonShape()

                    Text(premiumStore.isPurchasing ? "Processing..." : premiumStore.presentation.ctaTitle)
                        .font(AppTypography.medium(18))
                        .foregroundColor(AppColors.gold)
                }
                .frame(width: 356, height: layout.buttonHeight)
            }
            .buttonStyle(.plain)
            .disabled(premiumStore.isPurchasing)
            .opacity(premiumStore.isPurchasing ? 0.72 : 1)
            .padding(.top, layout.buttonTop)

            PaywallLegalLinks(
                onPrivacy: {
                    openURL(AppConfiguration.Legal.privacyPolicyURL)
                },
                onSkip: {
                    onSkip()
                },
                onRestore: {
                    Task {
                        let didRestorePremium = await premiumStore.restorePurchases()
                        if didRestorePremium {
                            onPremiumActivated()
                        }
                    }
                },
                onTerms: {
                    openURL(AppConfiguration.Legal.termsOfUseURL)
                }
            )
                .padding(.top, layout.legalTop)
        }
    }
}

private struct PaywallPremiumFeature: Identifiable {
    let title: String
    let subtitle: String
    let iconName: String

    var id: String {
        title
    }
}

private struct PaywallFeatureCard: View {
    let feature: PaywallPremiumFeature
    let layout: PaywallPremiumLayout

    var body: some View {
        ZStack(alignment: .top) {
            PaywallFeatureCardBackground()

            VStack(spacing: 0) {
                PaywallFeatureIcon(iconName: feature.iconName, size: layout.iconSize)
                    .padding(.top, layout.iconTop)

                Text(feature.title)
                    .font(AppTypography.regular(layout.titleFontSize))
                    .foregroundColor(AppColors.gold)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .frame(width: 146)
                    .padding(.top, layout.titleTop)

                Text(feature.subtitle)
                    .font(AppTypography.regular(layout.subtitleFontSize))
                    .foregroundColor(AppColors.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 122)
                    .padding(.top, 4)
            }
        }
        .frame(width: 170, height: layout.cardHeight)
    }
}

private struct PaywallFeatureCardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
            .fill(AppColors.card)
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(AppColors.gold, lineWidth: 1)
            )
            .shadow(color: AppColors.black.opacity(0.25), radius: 1, x: 0, y: 0)
    }
}

private struct PaywallFeatureIcon: View {
    let iconName: String
    let size: CGSize

    var body: some View {
        Image(iconName)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size.width, height: size.height)
    }
}

private struct PaywallLegalLinks: View {
    let onPrivacy: () -> Void
    let onSkip: () -> Void
    let onRestore: () -> Void
    let onTerms: () -> Void

    private var items: [PaywallLegalItem] {
        [
            PaywallLegalItem(title: "Privacy Policy", action: onPrivacy),
            PaywallLegalItem(title: "Skip", action: onSkip),
            PaywallLegalItem(title: "Restore", action: onRestore),
            PaywallLegalItem(title: "Terms of Use", action: onTerms),
        ]
    }

    var body: some View {
        HStack {
            ForEach(items) { item in
                Button(action: item.action) {
                    Text(item.title)
                        .font(AppTypography.medium(12))
                        .foregroundColor(AppColors.muted)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(width: 332, height: 19)
    }
}

private struct PaywallLegalItem: Identifiable {
    let title: String
    let action: () -> Void

    var id: String {
        title
    }
}

#Preview {
    PaywallView(selectedScreen: .constant(.paywall))
        .environmentObject(StoreKitPremiumStore())
}

#Preview("Main Paywall") {
    MainPaywallView(selectedScreen: .constant(.paywall))
        .environmentObject(StoreKitPremiumStore())
}
