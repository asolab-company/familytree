import SwiftUI

struct AdaptiveAnalysisLoadingScreen: View {
    let progress: Double

    var body: some View {
        DesignAdaptiveScreenContainer { metrics in
            ZStack(alignment: .topLeading) {
                Image(DesignAsset.Scan.analyzeBackground)
                    .resizable()
                    .scaledToFill()
                    .frame(width: AppMetrics.designWidth, height: metrics.visibleHeight)
                    .clipped()

                let circleSize = metrics.isCompactHeight
                    ? min(270.0, max(236.0, metrics.visibleHeight * 0.39))
                    : 370.0
                let imageSize = circleSize - (metrics.isCompactHeight ? 38.0 : 50.0)
                let ringSize = circleSize - 24.0
                let circleTop = metrics.isCompactHeight
                    ? max(56.0, min(86.0, metrics.visibleHeight * 0.11))
                    : 190.0
                let percentTop = circleTop + circleSize + (metrics.isCompactHeight ? 18.0 : 22.0)
                let loadingTop = metrics.isCompactHeight ? metrics.visibleHeight - 78.0 : 762.0

                ZStack {
                    Circle()
                        .fill(Color(hex: 0x221B14))
                        .frame(width: circleSize, height: circleSize)

                    Image(DesignAsset.Scan.loading01)
                        .resizable()
                        .scaledToFit()
                        .frame(width: imageSize, height: imageSize)
                        .clipShape(Circle())

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            AppColors.greenTop,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: ringSize, height: ringSize)
                        .animation(.easeInOut(duration: 0.22), value: progress)
                }
                .designFrame(
                    x: (AppMetrics.designWidth - circleSize) / 2,
                    y: circleTop,
                    width: circleSize,
                    height: circleSize
                )

                Text("\(Int(progress * 100))%")
                    .font(AppTypography.regular(metrics.isCompactHeight ? 28 : 32))
                    .foregroundColor(AppColors.muted)
                    .designFrame(x: 150, y: percentTop, width: 93, height: 40)
                    .animation(.easeInOut(duration: 0.22), value: progress)

                Text("Loading, please wait...")
                    .font(AppTypography.regular(16))
                    .foregroundColor(AppColors.muted)
                    .designFrame(x: 112, y: loadingTop, width: 170, height: 25)
            }
        }
    }
}
