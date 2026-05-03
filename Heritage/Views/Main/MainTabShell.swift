import SwiftUI

enum MainTab: CaseIterable {
    case familyTree
    case scan
    case tools

    var title: String {
        switch self {
        case .familyTree:
            "Family tree"
        case .scan:
            "Scan"
        case .tools:
            "Tools"
        }
    }

    var screen: AppScreen {
        switch self {
        case .familyTree:
            .familyTree
        case .scan:
            .scan
        case .tools:
            .tools
        }
    }

    var iconAssetName: String {
        switch self {
        case .familyTree:
            DesignAsset.FamilyTree.menuFamily
        case .scan:
            DesignAsset.FamilyTree.menuScan
        case .tools:
            DesignAsset.FamilyTree.menuTools
        }
    }
}

struct MainTabsView: View {
    @Binding var selectedScreen: AppScreen
    @ObservedObject var familyTreeStore: FamilyTreeStore

    var body: some View {
        switch currentTab {
        case .familyTree:
            FamilyTreeView(
                selectedScreen: $selectedScreen,
                familyTreeStore: familyTreeStore
            )
        case .scan:
            ScanView(selectedScreen: $selectedScreen)
        case .tools:
            ToolsView(selectedScreen: $selectedScreen)
        }
    }

    private var currentTab: MainTab {
        switch selectedScreen {
        case .scan:
            .scan
        case .tools:
            .tools
        default:
            .familyTree
        }
    }
}

struct MainTabShell<Content: View>: View {
    @Binding var selectedScreen: AppScreen
    let selectedTab: MainTab
    let title: String
    let subtitle: String
    var backgroundAssetName: String? = nil
    let content: (DesignAdaptiveMetrics) -> Content

    init(
        selectedScreen: Binding<AppScreen>,
        selectedTab: MainTab,
        title: String,
        subtitle: String,
        backgroundAssetName: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        _selectedScreen = selectedScreen
        self.selectedTab = selectedTab
        self.title = title
        self.subtitle = subtitle
        self.backgroundAssetName = backgroundAssetName
        self.content = { _ in content() }
    }

    init(
        selectedScreen: Binding<AppScreen>,
        selectedTab: MainTab,
        title: String,
        subtitle: String,
        backgroundAssetName: String? = nil,
        @ViewBuilder content: @escaping (DesignAdaptiveMetrics) -> Content
    ) {
        _selectedScreen = selectedScreen
        self.selectedTab = selectedTab
        self.title = title
        self.subtitle = subtitle
        self.backgroundAssetName = backgroundAssetName
        self.content = content
    }

    var body: some View {
        DesignAdaptiveScreenContainer { metrics in
            ZStack(alignment: .topLeading) {
                MainTabBackground(
                    assetName: backgroundAssetName,
                    height: metrics.visibleHeight
                )

                content(metrics)

                MainTabHeader(
                    title: title,
                    subtitle: subtitle
                ) {
                    selectedScreen = .settings
                }

                MainBottomBar(
                    selectedTab: selectedTab,
                    selectedScreen: $selectedScreen
                )
                .designFrame(x: 18, y: metrics.bottomBarY, width: 356, height: 64)
            }
        }
    }
}

private struct MainTabBackground: View {
    let assetName: String?
    let height: CGFloat

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.bgTop, AppColors.bgBottom],
                startPoint: .top,
                endPoint: .bottom
            )

            if let assetName {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: AppMetrics.designWidth, height: height)
            } else {
                Image(DesignAsset.FamilyTree.texture)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 568, height: height)
                    .rotationEffect(.degrees(-90))
                    .opacity(0.22)
                    .blendMode(.overlay)
            }
        }
        .frame(width: AppMetrics.designWidth, height: height)
        .clipped()
    }
}

private struct MainTabHeader: View {
    let title: String
    let subtitle: String
    let settingsAction: () -> Void

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

            Text(title)
                .font(AppTypography.bold(24))
                .foregroundColor(AppColors.gold)
                .frame(width: 280, height: 33, alignment: .leading)
                .designFrame(x: 19, y: 60, width: 280, height: 33)

            Text(subtitle)
                .font(AppTypography.regular(16))
                .foregroundColor(AppColors.muted)
                .frame(width: 280, height: 23, alignment: .leading)
                .designFrame(x: 19, y: 93, width: 280, height: 23)

            Button(action: settingsAction) {
                Image(DesignAsset.FamilyTree.settingsButton)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                .contentShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            }
            .buttonStyle(.plain)
            .designFrame(x: 335, y: 67, width: 40, height: 40)
        }
        .frame(width: AppMetrics.designWidth, height: 136)
    }
}

private struct MainBottomBar: View {
    let selectedTab: MainTab
    @Binding var selectedScreen: AppScreen
    @EnvironmentObject private var premiumStore: StoreKitPremiumStore

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(AppColors.glass)
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(AppColors.gold.opacity(0.21), lineWidth: 1)
                )
                .shadow(color: AppColors.black.opacity(0.25), radius: 1, x: 0, y: 0)

            HStack(spacing: 0) {
                ForEach(MainTab.allCases, id: \.self) { tab in
                    MainBottomBarItem(
                        tab: tab,
                        isSelected: tab == selectedTab
                    ) {
                        if tab.screen.requiresPremium && !premiumStore.hasPremiumAccess {
                            selectedScreen = .paywall
                        } else {
                            selectedScreen = tab.screen
                        }
                    }
                }
            }
            .padding(.horizontal, 5)
        }
    }
}

private struct MainBottomBarItem: View {
    let tab: MainTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(AppColors.glass)
                        .overlay(
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .stroke(AppColors.gold.opacity(0.12), lineWidth: 1)
                        )
                }

                VStack(spacing: 2) {
                    Image(tab.iconAssetName)
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .foregroundColor(isSelected ? AppColors.gold : AppColors.muted)

                    Text(tab.title)
                        .font(AppTypography.regular(12))
                        .foregroundColor(isSelected ? AppColors.gold : AppColors.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(width: 102, height: 54)
            }
            .frame(width: 114, height: 54)
            .contentShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview("Main Tab Shell") {
    MainTabShell(
        selectedScreen: .constant(.familyTree),
        selectedTab: .familyTree,
        title: "Family Tree",
        subtitle: "Your story begins with family",
        backgroundAssetName: DesignAsset.FamilyTree.backgroundMask
    ) {
        Color.clear
    }
    .environmentObject(StoreKitPremiumStore())
}
