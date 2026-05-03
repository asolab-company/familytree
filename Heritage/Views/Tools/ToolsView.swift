import SwiftUI

struct ToolsView: View {
    @Binding var selectedScreen: AppScreen

    var body: some View {
        MainTabShell(
            selectedScreen: $selectedScreen,
            selectedTab: .tools,
            title: "Tools",
            subtitle: "See the past through a modern lens"
        ) { metrics in
            ToolsTabContent(
                metrics: metrics,
                nameOriginsAction: {
                    selectedScreen = .nameOrigins
                },
                photoRestorationAction: {
                    selectedScreen = .photoRestoration
                }
            )
        }
    }
}

private struct ToolsTabContent: View {
    let metrics: DesignAdaptiveMetrics
    let nameOriginsAction: () -> Void
    let photoRestorationAction: () -> Void

    var body: some View {
        let topY: CGFloat = metrics.isCompactHeight ? 128 : 144
        let spacing: CGFloat = metrics.isCompactHeight ? 18 : 24
        let cardHeight = metrics.isCompactHeight
            ? min(250, max(190, (metrics.bottomBarY - topY - spacing - 18) / 2))
            : 250
        let secondY = topY + cardHeight + spacing

        ZStack(alignment: .topLeading) {
            ToolsImageCard(
                title: "Name Origins",
                subtitle: "Trace your roots in seconds.",
                kind: .single(DesignAsset.Tools.cardMain),
                height: cardHeight,
                action: nameOriginsAction
            )
            .designFrame(x: 18, y: topY, width: 356, height: cardHeight)

            ToolsImageCard(
                title: "Photo Restoration",
                subtitle: "Reimagine the past in modern color.",
                kind: .split(
                    left: DesignAsset.Tools.cardSplitLeft,
                    right: DesignAsset.Tools.cardSplitRight
                ),
                height: cardHeight,
                action: photoRestorationAction
            )
            .designFrame(x: 18, y: secondY, width: 356, height: cardHeight)
        }
        .frame(width: AppMetrics.designWidth, height: metrics.visibleHeight)
    }
}

private struct ToolsImageCard: View {
    let title: String
    let subtitle: String
    let kind: ToolsCardImageKind
    let height: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                ToolsCardImage(kind: kind, height: height)

                LinearGradient(
                    colors: [
                        Color(hex: 0x21211E).opacity(0.50),
                        Color(hex: 0x23211E).opacity(0.80),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppTypography.bold(24))
                        .foregroundColor(AppColors.gold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text(subtitle)
                        .font(AppTypography.regular(16))
                        .foregroundColor(AppColors.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(width: 252, alignment: .leading)
                .padding(.leading, 16)
                .padding(.bottom, 26)

                ToolsArrowButton()
                    .designFrame(x: 300, y: height - 56, width: 40, height: 40)
            }
            .frame(width: 356, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(AppColors.gold.opacity(0.45), lineWidth: 1)
                    .blendMode(.screen)
            )
            .shadow(color: AppColors.black.opacity(0.34), radius: 2, x: 0, y: 2)
            .contentShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private enum ToolsCardImageKind {
    case single(String)
    case split(left: String, right: String)
}

private struct ToolsCardImage: View {
    let kind: ToolsCardImageKind
    let height: CGFloat

    var body: some View {
        Group {
            switch kind {
            case .single(let assetName):
                Image(assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 356, height: height)
            case .split(let left, let right):
                HStack(spacing: 0) {
                    Image(left)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 178, height: height)
                        .clipped()

                    Image(right)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 178, height: height)
                        .clipped()
                }
            }
        }
        .frame(width: 356, height: height)
        .clipped()
    }
}

private struct ToolsArrowButton: View {
    var body: some View {
        ZStack {
      

            Image(DesignAsset.Tools.arrow)
                .resizable()
                .scaledToFit()
         
        }
        .frame(width: 40, height: 40)
    }
}

#Preview {
    ToolsView(selectedScreen: .constant(.tools))
        .environmentObject(StoreKitPremiumStore())
}
