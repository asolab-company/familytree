import PhotosUI
import SwiftUI
import UIKit

struct ScanView: View {
    @Binding var selectedScreen: AppScreen
    @EnvironmentObject private var premiumStore: StoreKitPremiumStore

    @StateObject private var historyStore = ScanHistoryStore()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isShowingCamera = false
    @State private var isAnalyzing = false
    @State private var analysisProgress = 0.0
    @State private var selectedDetail: ScanHistoryItem?
    @State private var errorMessage: String?

    private let analysisService = OpenAIScanAnalysisService()

    var body: some View {
        Group {
            if isAnalyzing {
                ScanAnalyseView(progress: analysisProgress)
            } else if let selectedDetail {
                ScanDetailsView(
                    item: selectedDetail,
                    image: historyStore.image(for: selectedDetail),
                    backAction: {
                        self.selectedDetail = nil
                    },
                    deleteAction: {
                        historyStore.delete(selectedDetail)
                        self.selectedDetail = nil
                    }
                )
            } else {
                ScanMainView(
                    selectedScreen: $selectedScreen,
                    items: historyStore.items,
                    imageProvider: historyStore.image(for:),
                    errorMessage: errorMessage,
                    selectedPhotoItem: $selectedPhotoItem,
                    hasPremiumAccess: premiumStore.hasPremiumAccess,
                    paywallAction: {
                        selectedScreen = .paywall
                    },
                    cameraAction: {
                        isShowingCamera = true
                    },
                    selectDetail: { item in
                        selectedDetail = item
                    },
                    deleteItem: { item in
                        historyStore.delete(item)
                    }
                )
            }
        }
        .sheet(isPresented: $isShowingCamera) {
            ScanCameraPicker { image in
                isShowingCamera = false
                analyze(image)
            } onCancel: {
                isShowingCamera = false
            }
            .ignoresSafeArea()
        }
        .onChange(of: selectedPhotoItem) { _, item in
            loadPhoto(from: item)
        }
    }

    private func loadPhoto(from item: PhotosPickerItem?) {
        guard let item else {
            return
        }

        Task {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data)
            else {
                return
            }

            selectedPhotoItem = nil
            analyze(image)
        }
    }

    private func analyze(_ image: UIImage) {
        guard ImagePersonDetector.containsPerson(in: image) else {
            analysisProgress = 0
            isAnalyzing = false
            errorMessage = ScanAnalysisError.noPeopleDetected.localizedDescription
            return
        }

        Task {
            errorMessage = nil
            analysisProgress = SmartAnalysisProgress.initialValue
            isAnalyzing = true

            let progressTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    await MainActor.run {
                        analysisProgress = SmartAnalysisProgress.nextWaitingValue(from: analysisProgress)
                    }
                }
            }

            do {
                let result = try await analysisService.analyze(image: image)
                progressTask.cancel()
                let item = try historyStore.add(image: image, result: result)
                await SmartAnalysisProgress.complete(from: analysisProgress) {
                    analysisProgress = $0
                }
                selectedDetail = item
            } catch {
                progressTask.cancel()
                errorMessage = error.localizedDescription
            }

            isAnalyzing = false
            analysisProgress = 0
        }
    }
}

private struct ScanMainView: View {
    @Binding var selectedScreen: AppScreen
    let items: [ScanHistoryItem]
    let imageProvider: (ScanHistoryItem) -> UIImage?
    let errorMessage: String?
    @Binding var selectedPhotoItem: PhotosPickerItem?
    let hasPremiumAccess: Bool
    let paywallAction: () -> Void
    let cameraAction: () -> Void
    let selectDetail: (ScanHistoryItem) -> Void
    let deleteItem: (ScanHistoryItem) -> Void

    var body: some View {
        MainTabShell(
            selectedScreen: $selectedScreen,
            selectedTab: .scan,
            title: "Ethnic Origin",
            subtitle: "Upload a photo to get a breakdown of your portrait"
        ) { metrics in
            if items.isEmpty {
                ScanEmptyContent(
                    metrics: metrics,
                    selectedPhotoItem: $selectedPhotoItem,
                    hasPremiumAccess: hasPremiumAccess,
                    paywallAction: paywallAction,
                    cameraAction: cameraAction,
                    errorMessage: errorMessage
                )
            } else {
                ScanHistoryContent(
                    metrics: metrics,
                    items: items,
                    imageProvider: imageProvider,
                    selectedPhotoItem: $selectedPhotoItem,
                    hasPremiumAccess: hasPremiumAccess,
                    paywallAction: paywallAction,
                    cameraAction: cameraAction,
                    selectDetail: selectDetail,
                    deleteItem: deleteItem,
                    errorMessage: errorMessage
                )
            }
        }
    }
}

private struct ScanEmptyContent: View {
    let metrics: DesignAdaptiveMetrics
    @Binding var selectedPhotoItem: PhotosPickerItem?
    let hasPremiumAccess: Bool
    let paywallAction: () -> Void
    let cameraAction: () -> Void
    let errorMessage: String?

    var body: some View {
        let isCompact = metrics.isCompactHeight
        let portraitFrame = CGRect(
            x: isCompact ? 111 : 89,
            y: isCompact ? 139 : 149,
            width: isCompact ? 170 : 214,
            height: isCompact ? 218 : 296
        )
        let buttonHeight: CGFloat = isCompact ? 52 : 60
        let buttonY = isCompact ? metrics.bottomBarY - buttonHeight - 16 : 676
        let tipsRowsHeight: CGFloat = isCompact ? 116 : 138
        let tipsRowsY = isCompact ? buttonY - tipsRowsHeight - 14 : 506
        let tipsTitleY = isCompact ? tipsRowsY - 32 : 468
        let errorBannerY = isCompact ? tipsTitleY + 10 : buttonY - 86

        ZStack(alignment: .topLeading) {
            ScanEmptyPortrait()
                .designFrame(
                    x: portraitFrame.minX,
                    y: portraitFrame.minY,
                    width: portraitFrame.width,
                    height: portraitFrame.height
                )

            if let errorMessage {
                ScanErrorBanner(message: errorMessage)
                    .designFrame(x: 24, y: errorBannerY, width: 345, height: 64)
            } else {
                Text("Tips for fast scanning:")
                    .font(AppTypography.regular(16))
                    .foregroundColor(AppColors.gold)
                    .multilineTextAlignment(.center)
                    .designFrame(x: 36, y: tipsTitleY, width: 320, height: 22)

                VStack(alignment: .leading, spacing: isCompact ? 10 : 16) {
                    ScanTipRow(
                        icon: DesignAsset.Scan.light,
                        title: "Lighting",
                        subtitle: "Use front lighting to avoid side shadows"
                    )
                    ScanTipRow(
                        icon: DesignAsset.Scan.pose,
                        title: "Pose",
                        subtitle: "Hold the camera at eye level, face forward"
                    )
                    ScanTipRow(
                        icon: DesignAsset.Scan.glasses,
                        title: "Glasses/accessories",
                        subtitle: "Avoid glare, no hats, keep hair away from your face"
                    )
                }
                .designFrame(x: 21, y: tipsRowsY, width: 350, height: tipsRowsHeight)
            }

            ScanPickButton(
                selectedPhotoItem: $selectedPhotoItem,
                hasPremiumAccess: hasPremiumAccess,
                paywallAction: paywallAction
            )
                .designFrame(x: 19, y: buttonY, width: isCompact ? 288 : 280, height: buttonHeight)

            ScanCameraButton(
                hasPremiumAccess: hasPremiumAccess,
                paywallAction: paywallAction,
                action: cameraAction
            )
                .designFrame(x: isCompact ? 323 : 315, y: buttonY, width: buttonHeight, height: buttonHeight)
        }
        .frame(width: AppMetrics.designWidth, height: metrics.visibleHeight)
    }
}

private struct ScanErrorBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(AppTypography.regular(13))
            .foregroundColor(AppColors.gold)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.86)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppColors.bgTop.opacity(0.88))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(AppColors.gold.opacity(0.32), lineWidth: 1)
                    )
                    .shadow(color: AppColors.black.opacity(0.28), radius: 10, x: 0, y: 5)
            )
    }
}

private struct ScanHistoryContent: View {
    let metrics: DesignAdaptiveMetrics
    let items: [ScanHistoryItem]
    let imageProvider: (ScanHistoryItem) -> UIImage?
    @Binding var selectedPhotoItem: PhotosPickerItem?
    let hasPremiumAccess: Bool
    let paywallAction: () -> Void
    let cameraAction: () -> Void
    let selectDetail: (ScanHistoryItem) -> Void
    let deleteItem: (ScanHistoryItem) -> Void
    let errorMessage: String?

    var body: some View {
        let listHeight = metrics.isCompactHeight
            ? max(240, metrics.bottomBarY - 299 - 16)
            : 430

        ZStack(alignment: .topLeading) {
            ScanPickButton(
                selectedPhotoItem: $selectedPhotoItem,
                hasPremiumAccess: hasPremiumAccess,
                paywallAction: paywallAction
            )
                .designFrame(x: 19, y: 161, width: 280, height: 60)

            ScanCameraButton(
                hasPremiumAccess: hasPremiumAccess,
                paywallAction: paywallAction,
                action: cameraAction
            )
                .designFrame(x: 315, y: 161, width: 60, height: 60)

            Text("History")
                .font(AppTypography.regular(16))
                .foregroundColor(AppColors.gold)
                .frame(width: 160, height: 24, alignment: .leading)
                .position(x: 99, y: 273)

            List {
                ForEach(items) { item in
                    ScanHistoryCard(
                        item: item,
                        image: imageProvider(item)
                    ) {
                        selectDetail(item)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteItem(item)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteItem(item)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .designFrame(x: 19, y: 299, width: 356, height: listHeight)

            if let errorMessage {
                Text(errorMessage)
                    .font(AppTypography.regular(12))
                    .foregroundColor(AppColors.muted)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .designFrame(x: 24, y: 228, width: 345, height: 28)
            }
        }
        .frame(width: AppMetrics.designWidth, height: metrics.visibleHeight)
    }
}

private struct ScanEmptyPortrait: View {
    var body: some View {
        Image(DesignAsset.Scan.scanImage)
            .resizable()
            .scaledToFit()
    }
}

private struct ScanTipRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(AppTypography.bold(14))
                    .foregroundColor(AppColors.gold)

                Text(subtitle)
                    .font(AppTypography.regular(14))
                    .foregroundColor(AppColors.gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }
}

private struct ScanPickButton: View {
    @Binding var selectedPhotoItem: PhotosPickerItem?
    let hasPremiumAccess: Bool
    let paywallAction: () -> Void

    var body: some View {
        if hasPremiumAccess {
            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                buttonContent
            }
            .buttonStyle(.plain)
        } else {
            Button(action: paywallAction) {
                buttonContent
            }
            .buttonStyle(.plain)
        }
    }

    private var buttonContent: some View {
        ZStack {
            GradientPrimaryButtonShape()

            Text("Select Photo")
                .font(AppTypography.medium(18))
                .foregroundColor(AppColors.gold)
        }
    }
}

private struct ScanCameraButton: View {
    let hasPremiumAccess: Bool
    let paywallAction: () -> Void
    let action: () -> Void

    var body: some View {
        Button(action: hasPremiumAccess ? action : paywallAction) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppColors.greenTop, AppColors.greenBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Image(systemName: "camera.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppColors.gold)
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

private struct ScanHistoryCard: View {
    let item: ScanHistoryItem
    let image: UIImage?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                ScanThumbnail(image: image)
                    .frame(width: 88, height: 88)
                    .padding(.leading, 16)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(item.previewOrigins) { origin in
                        HStack(spacing: 8) {
                            Image(origin.flagAssetName)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 40, height: 24)
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                            Text(origin.country)
                                .font(AppTypography.regular(16))
                                .foregroundColor(AppColors.muted)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.leading, 16)

                Spacer()

                ScanArrowCircle()
                    .padding(.trailing, 16)
            }
            .frame(width: 356, height: 120)
            .background(ScanInfoBackground(cornerRadius: 32))
            .contentShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct ScanThumbnail: View {
    let image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(DesignAsset.Scan.emptyPhoto)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: 88, height: 88)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppColors.gold.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: AppColors.black.opacity(0.7), radius: 8, x: 0, y: 0)
    }
}

private struct ScanArrowCircle: View {
    var body: some View {
        ZStack {
          

            Image(DesignAsset.Settings.arrow)
                .resizable()
                .scaledToFit()
                
        }
        .frame(width: 40, height: 40)
    }
}

private struct ScanDetailsView: View {
    let item: ScanHistoryItem
    let image: UIImage?
    let backAction: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        DesignAdaptiveScreenContainer { metrics in
            let isCompact = metrics.isCompactHeight
            let imageSize = isCompact ? 312.0 : 356.0
            let imageX = (AppMetrics.designWidth - imageSize) / 2
            let imageY = isCompact ? 136.0 : 144.0
            let cardY = imageY + imageSize + (isCompact ? 16.0 : 16.0)
            let cardHeight = isCompact ? 210.0 : 230.0

            ZStack(alignment: .topLeading) {
                ScanScreenBackground(height: metrics.visibleHeight)

                ScanDetailsHeader(
                    backAction: backAction,
                    deleteAction: deleteAction
                )

                ScanDetailImage(image: image, size: imageSize)
                    .designFrame(x: imageX, y: imageY, width: imageSize, height: imageSize)

                ScanResultCard(result: item.result, isCompact: isCompact)
                    .designFrame(x: 19, y: cardY, width: 356, height: cardHeight)
            }
        }
    }
}

private struct ScanDetailsHeader: View {
    let backAction: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                stops: [
                    .init(color: AppColors.bgTop, location: 0.83),
                    .init(color: AppColors.bgTop.opacity(0), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: AppMetrics.designWidth, height: 136)

            Button(action: backAction) {
                Image("app_ic_back")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .designFrame(x: 19, y: 67, width: 40, height: 40)

            Text("Ethnic Origin")
                .font(AppTypography.bold(24))
                .foregroundColor(AppColors.gold)
                .frame(width: 160, height: 32, alignment: .leading)
                .designFrame(x: 75, y: 70, width: 160, height: 32)

            Button(action: deleteAction) {
                ZStack {
               

                    Image(DesignAsset.Scan.deleteIcon)
                        .resizable()
                        .scaledToFit()
                       
                }
                .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .designFrame(x: 335, y: 68, width: 40, height: 40)
        }
        .frame(width: AppMetrics.designWidth, height: 136)
    }
}

private struct ScanDetailImage: View {
    let image: UIImage?
    let size: CGFloat

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(DesignAsset.Scan.emptyPhoto)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }
}

private struct ScanResultCard: View {
    let result: HeritageAnalysisResult
    let isCompact: Bool

    var body: some View {
        VStack(spacing: isCompact ? 12 : 16) {
            Text("Result:")
                .font(AppTypography.bold(isCompact ? 15 : 16))
                .foregroundColor(AppColors.gold)

            VStack(spacing: isCompact ? 6 : 8) {
                ForEach(result.origins) { origin in
                    HStack(spacing: 8) {
                        Image(origin.flagAssetName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: isCompact ? 36 : 40, height: isCompact ? 22 : 24)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                        Text(origin.country)
                            .font(AppTypography.regular(isCompact ? 15 : 16))
                            .foregroundColor(AppColors.muted)

                        Spacer()

                        Text(origin.percentText)
                            .font(AppTypography.regular(isCompact ? 15 : 16))
                            .foregroundColor(AppColors.gold)
                    }
                    .frame(height: isCompact ? 22 : 24)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, isCompact ? 14 : 16)
        .frame(width: 356, height: isCompact ? 210 : 230, alignment: .top)
        .background(ScanInfoBackground(cornerRadius: 32))
    }
}

private struct ScanAnalyseView: View {
    let progress: Double

    var body: some View {
        AdaptiveAnalysisLoadingScreen(progress: progress)
    }
}

private struct ScanScreenBackground: View {
    var height: CGFloat = AppMetrics.designHeight

    var body: some View {
        LinearGradient(
            colors: [AppColors.bgTop, AppColors.bgBottom],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: AppMetrics.designWidth, height: height)
    }
}

private struct ScanInfoBackground: View {
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(AppColors.card)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppColors.gold.opacity(0.13), lineWidth: 1)
            )
            .shadow(color: AppColors.black.opacity(0.25), radius: 2, x: 0, y: 0)
    }
}

private struct ScanCameraPicker: UIViewControllerRepresentable {
    let onImageSelected: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera)
            ? .camera
            : .photoLibrary

        if UIImagePickerController.isCameraDeviceAvailable(.front) {
            picker.cameraDevice = .front
        }

        picker.cameraCaptureMode = .photo
        picker.showsCameraControls = true
        return picker
    }

    func updateUIViewController(
        _ uiViewController: UIImagePickerController,
        context: Context
    ) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageSelected: onImageSelected, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onImageSelected: (UIImage) -> Void
        private let onCancel: () -> Void

        init(
            onImageSelected: @escaping (UIImage) -> Void,
            onCancel: @escaping () -> Void
        ) {
            self.onImageSelected = onImageSelected
            self.onCancel = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let image = info[.originalImage] as? UIImage else {
                onCancel()
                return
            }

            onImageSelected(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}

#Preview {
    ScanView(selectedScreen: .constant(.scan))
        .environmentObject(StoreKitPremiumStore())
}

#Preview("Scan Empty") {
    ScanMainView(
        selectedScreen: .constant(.scan),
        items: [],
        imageProvider: { _ in nil },
        errorMessage: nil,
        selectedPhotoItem: .constant(nil),
        hasPremiumAccess: true,
        paywallAction: {},
        cameraAction: {},
        selectDetail: { _ in },
        deleteItem: { _ in }
    )
    .environmentObject(StoreKitPremiumStore())
}

#Preview("Scan History") {
    ScanMainView(
        selectedScreen: .constant(.scan),
        items: ScanPreviewData.items,
        imageProvider: { _ in nil },
        errorMessage: nil,
        selectedPhotoItem: .constant(nil),
        hasPremiumAccess: true,
        paywallAction: {},
        cameraAction: {},
        selectDetail: { _ in },
        deleteItem: { _ in }
    )
    .environmentObject(StoreKitPremiumStore())
}

#Preview("Scan Analyse") {
    ScanAnalyseView(progress: 0.5)
}

#Preview("Scan Details") {
    ScanDetailsView(
        item: ScanPreviewData.items[0],
        image: nil,
        backAction: {},
        deleteAction: {}
    )
}

private enum ScanPreviewData {
    static let items: [ScanHistoryItem] = [
        ScanHistoryItem(
            id: UUID(),
            createdAt: Date(),
            imageFileName: "preview-1.jpg",
            result: .placeholder
        ),
        ScanHistoryItem(
            id: UUID(),
            createdAt: Date().addingTimeInterval(-3600),
            imageFileName: "preview-2.jpg",
            result: HeritageAnalysisResult(
                origins: [
                    HeritageOriginResult(country: "Israel", percentage: 45, flagAssetName: "155-israel"),
                    HeritageOriginResult(country: "Kazakhstan", percentage: 25, flagAssetName: "074-kazakhstan"),
                    HeritageOriginResult(country: "Ukraine", percentage: 15, flagAssetName: "145-ukraine"),
                    HeritageOriginResult(country: "Poland", percentage: 10, flagAssetName: "211-poland"),
                    HeritageOriginResult(country: "Georgia", percentage: 5, flagAssetName: "256-georgia"),
                ],
                surname: "",
                surnameDescription: ""
            )
        ),
    ]
}
