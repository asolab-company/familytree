import SwiftUI

struct DesignScreenContainer<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            let widthScale = proxy.size.width / AppMetrics.designWidth
            let heightScale = proxy.size.height / AppMetrics.designHeight
            let isCompactHeight = proxy.size.height < AppMetrics.designHeight * widthScale

            ZStack {
                Color.black.ignoresSafeArea()

                if isCompactHeight {
                    ScrollView(.vertical, showsIndicators: false) {
                        content()
                            .frame(width: AppMetrics.designWidth, height: AppMetrics.designHeight)
                            .scaleEffect(widthScale, anchor: .top)
                            .frame(
                                width: proxy.size.width,
                                height: AppMetrics.designHeight * widthScale,
                                alignment: .top
                            )
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .scrollBounceBehavior(.basedOnSize)
                } else {
                    content()
                        .frame(width: AppMetrics.designWidth, height: AppMetrics.designHeight)
                        .scaleEffect(min(widthScale, heightScale), anchor: .center)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
    }
}

struct DesignAdaptiveMetrics {
    let visibleHeight: CGFloat

    var isCompactHeight: Bool {
        visibleHeight < AppMetrics.designHeight - 1
    }

    var bottomBarY: CGFloat {
        min(760, max(596, visibleHeight - 92))
    }

    var scrollBottomPadding: CGFloat {
        max(50, AppMetrics.designHeight - visibleHeight + 80)
    }
}

struct DesignAdaptiveScreenContainer<Content: View>: View {
    let content: (DesignAdaptiveMetrics) -> Content

    init(@ViewBuilder content: @escaping (DesignAdaptiveMetrics) -> Content) {
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            let widthScale = max(proxy.size.width / AppMetrics.designWidth, 0.01)
            let visibleDesignHeight = max(proxy.size.height / widthScale, 1)
            let metrics = DesignAdaptiveMetrics(visibleHeight: visibleDesignHeight)

            ZStack {
                Color.black.ignoresSafeArea()

                content(metrics)
                    .frame(width: AppMetrics.designWidth, height: visibleDesignHeight, alignment: .top)
                    .scaleEffect(widthScale, anchor: .top)
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                    .clipped()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
    }
}

extension View {
    func designFrame(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        frame(width: width, height: height)
            .position(x: x + width / 2, y: y + height / 2)
    }
}

struct GradientPrimaryButtonShape: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
            .fill(LinearGradient(colors: [AppColors.greenTop, AppColors.greenBottom], startPoint: .top, endPoint: .bottom))
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(AppColors.white.opacity(0.21), lineWidth: 1)
            )
    }
}

struct GlassIconCircle: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
            .fill(AppColors.glassStrong)
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(AppColors.white, lineWidth: 1)
            )
    }
}


struct DesignHitButton: View {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Rectangle()
                .fill(Color.white.opacity(0.001))
                .contentShape(Rectangle())
                .frame(width: width, height: height)
        }
        .buttonStyle(.plain)
        .designFrame(x: x, y: y, width: width, height: height)
    }
}
