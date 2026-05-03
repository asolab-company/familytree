import SwiftUI
import StoreKit

struct SettingsView: View {
    @Binding var selectedScreen: AppScreen
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @EnvironmentObject private var premiumStore: StoreKitPremiumStore

    var body: some View {
        DesignAdaptiveScreenContainer { metrics in
            ZStack(alignment: .topLeading) {
                SettingsBackground(height: metrics.visibleHeight)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        if !premiumStore.hasPremiumAccess {
                            SettingsPremiumCard {
                                selectedScreen = .paywall
                            }
                            .padding(.top, 144)
                        }

                        SettingsSection(title: "Support & Legal") {
                            SettingsRow(title: "Privacy", icon: DesignAsset.Settings.set06) {
                                openURL(AppConfiguration.Legal.privacyPolicyURL)
                            }

                            SettingsRow(title: "Terms and Conditions", icon: DesignAsset.Settings.set03) {
                                openURL(AppConfiguration.Legal.termsOfUseURL)
                            }
                        }
                        .padding(.top, premiumStore.hasPremiumAccess ? 144 : 26)

                        SettingsSection(title: "General") {
                            SettingsShareRow(
                                title: "Share app",
                                icon: DesignAsset.Settings.set05
                            )

                            SettingsRow(title: "Rate Us", icon: DesignAsset.Settings.set02) {
                                requestReview()
                            }

                            if !premiumStore.hasPremiumAccess {
                                SettingsRow(title: "Restore", icon: DesignAsset.Settings.set04) {
                                    Task {
                                        _ = await premiumStore.restorePurchases()
                                    }
                                }
                            }

                            SettingsRow(title: "Delete Data", icon: DesignAsset.Settings.set01) {
                                deleteUserData()
                            }
                        }
                        .padding(.top, 24)
                        .padding(.bottom, metrics.scrollBottomPadding)
                    }
                    .padding(.horizontal, 19)
                    .frame(width: AppMetrics.designWidth, alignment: .topLeading)
                }
                .frame(width: AppMetrics.designWidth, height: metrics.visibleHeight)

                SettingsHeader {
                    selectedScreen = .familyTree
                }
            }
        }
    }

    private func deleteUserData() {
        do {
            try UserDataResetService.deleteAllUserData()
            selectedScreen = .familyTree
        } catch {
            premiumStore.errorMessage = error.localizedDescription
        }
    }
}

private struct SettingsBackground: View {
    let height: CGFloat

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.bgTop, AppColors.bgBottom],
                startPoint: .top,
                endPoint: .bottom
            )

            Image(DesignAsset.FamilyTree.texture)
                .resizable()
                .scaledToFill()
                .frame(width: 568, height: height)
                .rotationEffect(.degrees(-90))
                .opacity(0.18)
                .blendMode(.overlay)
        }
        .frame(width: AppMetrics.designWidth, height: height)
        .clipped()
    }
}

private struct SettingsHeader: View {
    let backAction: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                stops: [
                    .init(color: AppColors.bgTop, location: 0.83),
                    .init(color: AppColors.bgTop.opacity(0), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: AppMetrics.designWidth, height: 136)

            Button(action: backAction) {
                ZStack {
              

                    Image("app_ic_back")
                        .resizable()
                        .scaledToFit()
                      
                }
                .frame(width: 40, height: 40)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .designFrame(x: 19, y: 67, width: 40, height: 40)

            Text("Settings")
                .font(AppTypography.bold(24))
                .foregroundColor(AppColors.gold)
                .designFrame(x: 76, y: 78, width: 110, height: 29)
        }
        .frame(width: AppMetrics.designWidth, height: 136)
    }
}

private struct SettingsPremiumCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                Image("app_bg_tools")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 356, height: 250)
                    .clipped()

                LinearGradient(
                    stops: [
                        .init(color: Color(hex: 0x21211E, alpha: 0.5), location: 0),
                        .init(color: Color(hex: 0x23211E, alpha: 0.88), location: 0.71)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 1) {
                    Text("Go To Premium")
                        .font(AppTypography.bold(24))
                        .foregroundColor(AppColors.gold)

                    Text("Your family story deserves to be complete")
                        .font(AppTypography.regular(16))
                        .foregroundColor(AppColors.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .padding(.leading, 16)
                .padding(.bottom, 25)

                SettingsArrowCircle()
                    .offset(x: 300, y: -15)
            }
            .frame(width: 356, height: 250)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(AppColors.gold, lineWidth: 2)
            )
            .shadow(color: AppColors.black.opacity(0.34), radius: 2, x: 0, y: 2)
            .contentShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(AppTypography.regular(16))
                .foregroundColor(AppColors.gold)

            VStack(spacing: 10) {
                content()
            }
        }
    }
}

private struct SettingsRow: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                    .padding(.leading, 16)

                Text(title)
                    .font(AppTypography.regular(16))
                    .foregroundColor(AppColors.gold)
                    .padding(.leading, 25)

                Spacer()

                SettingsArrowCircle()
                    .padding(.trailing, 16)
            }
            .frame(width: 356, height: 66)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(AppColors.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(AppColors.gold.opacity(0.13), lineWidth: 1)
                    )
                    .shadow(color: AppColors.black.opacity(0.25), radius: 2, x: 0, y: 0)
            )
            .contentShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsShareRow: View {
    let title: String
    let icon: String

    var body: some View {
        ShareLink(
            item: AppConfiguration.App.appStoreURL,
            subject: Text("Heritage"),
            message: Text(AppConfiguration.App.shareMessage)
        ) {
            SettingsRowContent(title: title, icon: icon)
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsRowContent: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 0) {
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(width: 34, height: 34)
                .padding(.leading, 16)

            Text(title)
                .font(AppTypography.regular(16))
                .foregroundColor(AppColors.gold)
                .padding(.leading, 25)

            Spacer()

            SettingsArrowCircle()
                .padding(.trailing, 16)
        }
        .frame(width: 356, height: 66)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(AppColors.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(AppColors.gold.opacity(0.13), lineWidth: 1)
                )
                .shadow(color: AppColors.black.opacity(0.25), radius: 2, x: 0, y: 0)
        )
        .contentShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }
}

private struct SettingsArrowCircle: View {
    var body: some View {
        ZStack {
          

            Image(DesignAsset.Settings.arrow)
                .resizable()
                .scaledToFit()
                
        }
        .frame(width: 40, height: 40)
    }
}

#Preview {
    SettingsView(selectedScreen: .constant(.settings))
        .environmentObject(StoreKitPremiumStore())
}
