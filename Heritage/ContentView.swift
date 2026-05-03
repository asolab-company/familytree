import SwiftUI

struct ContentView: View {
    @StateObject private var flowViewModel = AppFlowViewModel()
    @StateObject private var premiumStore = StoreKitPremiumStore()

    var body: some View {
        Group {
            if flowViewModel.currentScreen.requiresPremium && !premiumStore.hasPremiumAccess {
                MainPaywallView(
                    selectedScreen: screenBinding,
                    onSkip: flowViewModel.dismissMainPaywall,
                    onPremiumActivated: flowViewModel.finishMainPaywallWithPremium
                )
            } else {
                content
            }
        }
        .environmentObject(premiumStore)
        .task {
            await premiumStore.load()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch flowViewModel.currentScreen {
            case .onboarding:
                OnboardingView(
                    selectedScreen: screenBinding
                ) { result, photo in
                    flowViewModel.finishOnboarding(with: result, photo: photo)
                }
            case .familyTree, .scan, .tools:
                MainTabsView(
                    selectedScreen: screenBinding,
                    familyTreeStore: flowViewModel.familyTreeStore
                )
            case .addFamilyMember:
                AddFamilyMemberView(
                    selectedScreen: screenBinding,
                    familyTreeStore: flowViewModel.familyTreeStore
                )
            case .settings:
                SettingsView(selectedScreen: screenBinding)
            case .paywall:
                MainPaywallView(
                    selectedScreen: screenBinding,
                    onSkip: flowViewModel.dismissMainPaywall,
                    onPremiumActivated: flowViewModel.finishMainPaywallWithPremium
                )
            case .heritagePaywall:
                PaywallView(
                    selectedScreen: screenBinding,
                    variant: .heritageResult,
                    analysisResult: flowViewModel.heritageAnalysisResult,
                    onSkip: flowViewModel.finishOnboardingPaywallWithoutPremium,
                    onPremiumActivated: flowViewModel.finishOnboardingPaywallWithPremium
                )
            case .photoRestoration:
                PhotoRestorationView(selectedScreen: screenBinding)
            case .nameOrigins:
                NameOriginsView(selectedScreen: screenBinding)
        }
    }

    private var screenBinding: Binding<AppScreen> {
        Binding(
            get: {
                flowViewModel.currentScreen
            },
            set: { screen in
                flowViewModel.open(
                    screen,
                    hasPremiumAccess: premiumStore.hasPremiumAccess
                )
            }
        )
    }
}

#Preview {
    ContentView()
}
