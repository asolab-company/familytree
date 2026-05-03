import SwiftUI

struct GlassCard: View {
    var cornerRadius: CGFloat = 32
    var fill: Color = AppColors.card

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppColors.gold.opacity(0.21), lineWidth: 1)
            )
            .shadow(color: AppColors.black.opacity(0.25), radius: 1, x: 0, y: 0)
    }
}

struct GradientMainButton: View {
    var body: some View {
        GradientPrimaryButtonShape()
    }
}

struct CircularCaptureButton: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(AppColors.black.opacity(0.75))
                .frame(width: 64, height: 64)
                .overlay(Circle().stroke(AppColors.white, lineWidth: 2))
                .opacity(0.8)

            Circle()
                .fill(AppColors.white)
                .frame(width: 52, height: 52)
        }
    }
}
