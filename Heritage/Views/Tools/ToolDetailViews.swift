import Photos
import PhotosUI
import SwiftUI
import UIKit

struct PhotoRestorationView: View {
    @Binding var selectedScreen: AppScreen
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var restoredImage: UIImage?
    @State private var isShowingCamera = false
    @State private var phase: PhotoRestorationPhase = .empty
    @State private var progress = 0.0
    @State private var errorMessage: String?
    @State private var saveToastMessage: String?

    init(
        selectedScreen: Binding<AppScreen>,
        selectedImage: UIImage? = nil,
        restoredImage: UIImage? = nil,
        phase: PhotoRestorationPhase = .empty
    ) {
        _selectedScreen = selectedScreen
        _selectedImage = State(initialValue: selectedImage)
        _restoredImage = State(initialValue: restoredImage)
        _phase = State(initialValue: phase)
    }

    var body: some View {
        Group {
            switch phase {
            case .empty:
                PhotoRestorationPickerScreen(
                    selectedPhotoItem: $selectedPhotoItem,
                    openCamera: { isShowingCamera = true },
                    backAction: { selectedScreen = .tools },
                    errorMessage: errorMessage
                )
            case .preview:
                PhotoRestorationPreviewScreen(
                    image: selectedImage,
                    errorMessage: errorMessage,
                    backAction: { phase = .empty },
                    continueAction: startRestoration
                )
            case .analyzing:
                PhotoRestorationAnalyseView(progress: progress)
            case .result:
                PhotoRestorationResultScreen(
                    image: restoredImage ?? selectedImage,
                    backAction: { selectedScreen = .tools },
                    saveAction: saveResult,
                    cancelAction: reset
                )
            }
        }
        .overlay(alignment: .top) {
            if let saveToastMessage {
                PhotoRestorationToast(message: saveToastMessage)
                    .padding(.top, 74)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: saveToastMessage)
        .sheet(isPresented: $isShowingCamera) {
            PhotoRestorationCameraPicker { image in
                setSelectedImage(image)
                isShowingCamera = false
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
            defer { selectedPhotoItem = nil }

            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data)
            else {
                errorMessage = "Could not load this photo. Please try another image."
                return
            }

            setSelectedImage(image)
        }
    }

    private func setSelectedImage(_ image: UIImage) {
        selectedImage = image
        restoredImage = nil
        errorMessage = nil
        phase = .preview
    }

    private func startRestoration() {
        guard let selectedImage else {
            phase = .empty
            return
        }

        errorMessage = nil
        saveToastMessage = nil

        guard ImagePersonDetector.containsPerson(in: selectedImage) else {
            progress = 0
            errorMessage = PhotoRestorationError.noPeopleDetected.localizedDescription
            phase = .preview
            return
        }

        progress = 0.02
        phase = .analyzing

        Task {
            let progressTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    await MainActor.run {
                        progress = SmartAnalysisProgress.nextWaitingValue(from: progress)
                    }
                }
            }

            do {
                let image = try await OpenAIPhotoRestorationService().restore(selectedImage)
                progressTask.cancel()
                await SmartAnalysisProgress.complete(from: progress) {
                    progress = $0
                }
                restoredImage = image
                phase = .result
            } catch {
                progressTask.cancel()
                errorMessage = error.localizedDescription
                phase = .preview
            }
        }
    }

    private func saveResult() {
        guard let image = restoredImage ?? selectedImage else {
            return
        }

        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        } completionHandler: { success, error in
            Task { @MainActor in
                saveToastMessage = success
                    ? "Photo saved successfully"
                    : (error?.localizedDescription ?? "Could not save photo")

                let currentMessage = saveToastMessage
                try? await Task.sleep(nanoseconds: 2_200_000_000)
                if saveToastMessage == currentMessage {
                    saveToastMessage = nil
                }
            }
        }
    }

    private func reset() {
        selectedImage = nil
        restoredImage = nil
        selectedPhotoItem = nil
        progress = 0
        errorMessage = nil
        saveToastMessage = nil
        phase = .empty
    }
}

enum PhotoRestorationPhase {
    case empty
    case preview
    case analyzing
    case result
}

private struct PhotoRestorationToast: View {
    let message: String

    var body: some View {
        Text(message)
            .font(AppTypography.medium(14))
            .foregroundColor(AppColors.gold)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppColors.bgTop.opacity(0.94))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(AppColors.gold.opacity(0.35), lineWidth: 1)
                    )
                    .shadow(color: AppColors.black.opacity(0.35), radius: 10, x: 0, y: 5)
            )
            .frame(maxWidth: 320)
    }
}

private struct PhotoRestorationPickerScreen: View {
    @Binding var selectedPhotoItem: PhotosPickerItem?
    let openCamera: () -> Void
    let backAction: () -> Void
    let errorMessage: String?

    var body: some View {
        DesignAdaptiveScreenContainer { metrics in
            let isCompact = metrics.isCompactHeight
            let cardY = isCompact ? 132.0 : 144.0
            let cardHeight = isCompact ? 214.0 : 250.0
            let tipsTitleY = cardY + cardHeight + (isCompact ? 24.0 : 71.0)
            let tipsListY = tipsTitleY + (isCompact ? 30.0 : 38.0)
            let tipsListHeight = isCompact ? 124.0 : 160.0
            let buttonHeight = isCompact ? 54.0 : 60.0
            let buttonY = isCompact ? metrics.visibleHeight - buttonHeight - 22.0 : 721.0
            let cameraSize = isCompact ? 54.0 : 60.0
            let errorY = buttonY - 34.0

            ZStack(alignment: .topLeading) {
                PhotoRestorationBackground(height: metrics.visibleHeight)

                PhotoRestorationHeader(backAction: backAction)

                PhotoRestorationBeforeAfterCard(height: cardHeight)
                    .designFrame(x: 18, y: cardY, width: 356, height: cardHeight)

                Text("Tips for best Photo Restoration:")
                    .font(AppTypography.regular(16))
                    .foregroundColor(AppColors.gold)
                    .multilineTextAlignment(.center)
                    .designFrame(x: 94, y: tipsTitleY, width: 205, height: 22)

                VStack(alignment: .leading, spacing: isCompact ? 8 : 16) {
                    PhotoRestorationTipRow(
                        icon: DesignAsset.Tools.clean,
                        title: "Clean your photos",
                        subtitle: "Remove dust before scanning to avoid extra editing",
                        compact: isCompact
                    )

                    PhotoRestorationTipRow(
                        icon: DesignAsset.Scan.light,
                        title: "Use good lighting",
                        subtitle: "Make sure there are no shadows or glare for the best quality",
                        compact: isCompact
                    )

                    PhotoRestorationTipRow(
                        icon: "app_ic_scan",
                        title: "Scan at the right resolution",
                        subtitle: "Use 300 DPI for a perfect balance of quality and speed",
                        compact: isCompact
                    )
                }
                .designFrame(x: 18, y: tipsListY, width: 356, height: tipsListHeight)

                if let errorMessage {
                    Text(errorMessage)
                        .font(AppTypography.regular(12))
                        .foregroundColor(AppColors.muted)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .designFrame(x: 28, y: errorY, width: 337, height: 28)
                }

                PhotosPicker(
                    selection: $selectedPhotoItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    ZStack {
                        GradientPrimaryButtonShape()

                        Text("Select Photo")
                            .font(AppTypography.medium(18))
                            .foregroundColor(AppColors.gold)
                    }
                    .frame(width: 280, height: buttonHeight)
                }
                .buttonStyle(.plain)
                .designFrame(x: 19, y: buttonY, width: 280, height: buttonHeight)

                Button(action: openCamera) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [AppColors.greenTop, AppColors.greenBottom],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .overlay(Circle().stroke(AppColors.white.opacity(0.21), lineWidth: 1))

                        Image(systemName: "camera.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(AppColors.gold)
                    }
                    .frame(width: cameraSize, height: cameraSize)
                }
                .buttonStyle(.plain)
                .designFrame(x: isCompact ? 321 : 315, y: buttonY, width: cameraSize, height: cameraSize)
            }
        }
    }
}

private struct PhotoRestorationPreviewScreen: View {
    let image: UIImage?
    let errorMessage: String?
    let backAction: () -> Void
    let continueAction: () -> Void

    var body: some View {
        DesignAdaptiveScreenContainer { metrics in
            let isCompact = metrics.isCompactHeight
            let imageY = isCompact ? 128.0 : 135.0
            let buttonHeight = isCompact ? 54.0 : 60.0
            let buttonY = isCompact ? metrics.visibleHeight - buttonHeight - 22.0 : 721.0
            let panelHeight = isCompact ? 96.0 : 147.0
            let panelY = isCompact ? buttonY - panelHeight - 14.0 : 705.0
            let imageHeight = isCompact ? max(320.0, panelY - imageY) : 570.0
            let errorY = isCompact ? panelY + 10.0 : 684.0

            ZStack(alignment: .topLeading) {
                PhotoRestorationBackground(height: metrics.visibleHeight)

                PhotoRestorationPreviewImage(image: image, height: imageHeight)
                    .designFrame(x: 0, y: imageY, width: 393, height: imageHeight)

                Rectangle()
                    .fill(Color(hex: 0x1E1E1E))
                    .designFrame(x: 0, y: panelY, width: 393, height: panelHeight)

                PhotoRestorationHeader(backAction: backAction)

                if let errorMessage {
                    Text(errorMessage)
                        .font(AppTypography.regular(12))
                        .foregroundColor(AppColors.muted)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .designFrame(x: 28, y: errorY, width: 337, height: 28)
                }

                Button(action: continueAction) {
                    ZStack {
                        GradientPrimaryButtonShape()

                        Text("Continue")
                            .font(AppTypography.medium(18))
                            .foregroundColor(AppColors.gold)
                    }
                    .frame(width: 356, height: buttonHeight)
                }
                .buttonStyle(.plain)
                .designFrame(x: 19, y: buttonY, width: 356, height: buttonHeight)
            }
        }
    }
}

private struct PhotoRestorationAnalyseView: View {
    let progress: Double

    var body: some View {
        AdaptiveAnalysisLoadingScreen(progress: progress)
    }
}

private struct PhotoRestorationResultScreen: View {
    let image: UIImage?
    let backAction: () -> Void
    let saveAction: () -> Void
    let cancelAction: () -> Void

    var body: some View {
        DesignAdaptiveScreenContainer { metrics in
            let isCompact = metrics.isCompactHeight
            let imageY = isCompact ? 128.0 : 135.0
            let panelHeight = isCompact ? 92.0 : 147.0
            let buttonHeight = isCompact ? 52.0 : 60.0
            let buttonY = isCompact ? metrics.visibleHeight - buttonHeight - 54.0 : 721.0
            let cancelY = isCompact ? buttonY + buttonHeight + 6.0 : 791.0
            let panelY = isCompact ? buttonY - panelHeight - 14.0 : 705.0
            let imageHeight = isCompact
                ? max(320.0, panelY - imageY)
                : 570.0

            ZStack(alignment: .topLeading) {
                PhotoRestorationBackground(height: metrics.visibleHeight)

                PhotoRestorationPreviewImage(image: image, height: imageHeight)
                    .designFrame(x: 0, y: imageY, width: 393, height: imageHeight)

                Rectangle()
                    .fill(Color(hex: 0x1E1E1E))
                    .designFrame(x: 0, y: panelY, width: 393, height: panelHeight)

                PhotoRestorationHeader(backAction: backAction)

                Button(action: saveAction) {
                    ZStack {
                        GradientPrimaryButtonShape()

                        Text("Save")
                            .font(AppTypography.medium(18))
                            .foregroundColor(AppColors.gold)

                        Image(DesignAsset.Tools.save)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .designFrame(x: 316, y: (buttonHeight - 22) / 2, width: 22, height: 22)
                    }
                    .frame(width: 356, height: buttonHeight)
                }
                .buttonStyle(.plain)
                .designFrame(x: 19, y: buttonY, width: 356, height: buttonHeight)

                Button(action: cancelAction) {
                    Text("Cancel")
                        .font(AppTypography.medium(18))
                        .foregroundColor(AppColors.gold)
                        .frame(width: 356, height: 30)
                }
                .buttonStyle(.plain)
                .designFrame(x: 19, y: cancelY, width: 356, height: 30)
            }
        }
    }
}

private struct PhotoRestorationHeader: View {
    let backAction: () -> Void

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

            Text("Photo Restoration")
                .font(AppTypography.bold(24))
                .foregroundColor(AppColors.gold)
                .frame(width: 230, height: 33, alignment: .leading)
                .designFrame(x: 75, y: 70, width: 230, height: 33)
        }
        .frame(width: AppMetrics.designWidth, height: 136)
    }
}

private struct PhotoRestorationBackground: View {
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

private struct PhotoRestorationBeforeAfterCard: View {
    var height: CGFloat = 250

    var body: some View {
        let halfWidth = 178.0

        HStack(spacing: 0) {
            Image(DesignAsset.Tools.cardSplitLeft)
                .resizable()
                .scaledToFill()
                .frame(width: halfWidth, height: height)
                .clipped()

            Image(DesignAsset.Tools.cardSplitRight)
                .resizable()
                .scaledToFill()
                .frame(width: halfWidth, height: height)
                .clipped()
        }
        .frame(width: 356, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(AppColors.gold.opacity(0.4), lineWidth: 1)
                .blendMode(.screen)
        )
        .shadow(color: AppColors.black.opacity(0.34), radius: 2, x: 0, y: 2)
    }
}

private struct PhotoRestorationPreviewImage: View {
    let image: UIImage?
    var height: CGFloat = 570

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(DesignAsset.Tools.cardSplitLeft)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: 393, height: height)
        .clipped()
    }
}

private struct PhotoRestorationTipRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var compact = false

    var body: some View {
        HStack(alignment: .top, spacing: compact ? 10 : 12) {
            Image(icon)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundColor(AppColors.gold)
                .frame(width: compact ? 21 : 24, height: compact ? 21 : 24)
                .padding(.top, compact ? 4 : 6)

            VStack(alignment: .leading, spacing: compact ? -1 : 0) {
                Text(title)
                    .font(AppTypography.bold(compact ? 13 : 14))
                    .foregroundColor(AppColors.gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(subtitle)
                    .font(AppTypography.regular(compact ? 12 : 14))
                    .foregroundColor(AppColors.gold)
                    .lineLimit(compact ? 1 : 2)
                    .minimumScaleFactor(0.78)
            }
            .frame(width: compact ? 320 : 318, alignment: .leading)
        }
        .frame(width: 356, alignment: .leading)
    }
}

private struct PhotoRestorationCameraPicker: UIViewControllerRepresentable {
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

struct NameOriginsView: View {
    @Binding var selectedScreen: AppScreen
    @State private var query = ""
    @State private var result: NameOriginAnalysisResult?
    @State private var isAnalyzing = false
    @State private var analysisProgress = 0.0
    @State private var errorMessage: String?
    @FocusState private var isInputFocused: Bool

    private let service = OpenAINameOriginsService()

    init(
        selectedScreen: Binding<AppScreen>,
        initialQuery: String = "",
        initialResult: NameOriginAnalysisResult? = nil
    ) {
        _selectedScreen = selectedScreen
        _query = State(initialValue: initialQuery)
        _result = State(initialValue: initialResult)
    }

    var body: some View {
        DesignAdaptiveScreenContainer { metrics in
            ZStack(alignment: .topLeading) {
                NameOriginsBackground(height: metrics.visibleHeight)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        NameOriginsInputField(
                            query: $query,
                            isDisabled: isAnalyzing,
                            isFocused: $isInputFocused,
                            submitAction: submit
                        )
                        .frame(width: 356, height: 48)

                        if isAnalyzing {
                            NameOriginsLoadingCard(progress: analysisProgress)
                                .frame(width: 356, height: 132)
                                .padding(.top, 24)
                        } else if let errorMessage {
                            Text(errorMessage)
                                .font(AppTypography.regular(16))
                                .foregroundColor(AppColors.muted)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(width: 356, alignment: .leading)
                                .padding(.top, 24)
                        } else if let result {
                            NameOriginsTopCountriesCard(result: result)
                                .frame(width: 356, height: 252)
                                .padding(.top, 24)

                            NameOriginsDescriptionCard(result: result)
                                .frame(width: 356)
                                .padding(.top, 16)
                        } else {
                            NameOriginsEmptyText()
                                .frame(width: 356, alignment: .leading)
                                .padding(.top, 24)
                        }
                    }
                    .frame(width: 356)
                    .padding(.top, 144)
                    .padding(.horizontal, 19)
                    .padding(.bottom, metrics.scrollBottomPadding)
                }
                .frame(width: AppMetrics.designWidth, height: metrics.visibleHeight)
                .scrollDismissesKeyboard(.interactively)

                NameOriginsHeader {
                    selectedScreen = .tools
                }
            }
        }
        .onChange(of: query) { _, newValue in
            guard let result,
                  newValue.trimmingCharacters(in: .whitespacesAndNewlines) != result.query
            else {
                return
            }

            self.result = nil
            errorMessage = nil
        }
    }

    private func submit() {
        isInputFocused = false

        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty, !isAnalyzing else {
            return
        }

        query = normalizedQuery
        result = nil
        errorMessage = nil
        analysisProgress = SmartAnalysisProgress.initialValue
        isAnalyzing = true

        Task {
            let progressTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    await MainActor.run {
                        analysisProgress = SmartAnalysisProgress.nextWaitingValue(from: analysisProgress)
                    }
                }
            }

            do {
                let analysis = try await service.analyze(query: normalizedQuery)
                progressTask.cancel()
                await SmartAnalysisProgress.complete(from: analysisProgress) {
                    analysisProgress = $0
                }
                result = analysis
                query = analysis.query
            } catch {
                progressTask.cancel()
                errorMessage = error.localizedDescription
            }

            isAnalyzing = false
            analysisProgress = 0
        }
    }
}

private struct NameOriginsBackground: View {
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

private struct NameOriginsHeader: View {
    let backAction: () -> Void

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

            Text("Name Origins")
                .font(AppTypography.bold(24))
                .foregroundColor(AppColors.gold)
                .frame(width: 180, height: 33, alignment: .leading)
                .designFrame(x: 75, y: 70, width: 180, height: 33)
        }
        .frame(width: AppMetrics.designWidth, height: 136)
    }
}

private struct NameOriginsInputField: View {
    @Binding var query: String
    let isDisabled: Bool
    let isFocused: FocusState<Bool>.Binding
    let submitAction: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Image(DesignAsset.Tools.search)
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: 32, height: 32)
                .opacity(query.isEmpty ? 0.76 : 1)
                .padding(.leading, 16)

            TextField(
                "",
                text: $query,
                prompt: Text("Enter First Name*").foregroundColor(AppColors.placeholder)
            )
            .font(AppTypography.regular(16))
            .foregroundColor(AppColors.gold)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .submitLabel(.search)
            .onSubmit(submitAction)
            .disabled(isDisabled)
            .focused(isFocused)
            .padding(.leading, 0)
            .padding(.trailing, 18)
        }
        .frame(width: 356, height: 48)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(AppColors.field)
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(AppColors.fieldStroke, lineWidth: 1)
                )
        )
        .opacity(isDisabled ? 0.62 : 1)
    }
}

private struct NameOriginsEmptyText: View {
    var body: some View {
        Text(
            """
            Enter a name or surname to discover its meaning, origin, and history.

            You can search for family names from around the world and learn about their linguistic roots, cultural significance, and geographic distribution. Whether you're exploring your ancestry or just curious about a name, we'll provide clear and engaging insights to help you understand where it comes from.

            Start typing to begin your search.
            """
        )
        .font(AppTypography.regular(16))
        .foregroundColor(AppColors.placeholder)
        .lineSpacing(2)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct NameOriginsLoadingCard: View {
    let progress: Double

    var body: some View {
        VStack(spacing: 12) {
            Text("\(Int(progress * 100))%")
                .font(AppTypography.bold(24))
                .foregroundColor(AppColors.gold)

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(AppColors.greenTop)
                .frame(width: 252)
                .animation(.easeInOut(duration: 0.22), value: progress)

            Text("Analyzing name origin...")
                .font(AppTypography.regular(16))
                .foregroundColor(AppColors.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NameOriginsInfoBackground())
    }
}

private struct NameOriginsTopCountriesCard: View {
    let result: NameOriginAnalysisResult

    var body: some View {
        ZStack(alignment: .topLeading) {
            NameOriginsInfoBackground()

            Text("Top 5 countries where \"\(result.query)\" is most common today:")
                .font(AppTypography.bold(16))
                .foregroundColor(AppColors.gold)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(width: 236, height: 44, alignment: .center)
                .designFrame(x: 60, y: 16, width: 236, height: 44)

            VStack(spacing: 8) {
                ForEach(result.topCountries.prefix(5)) { country in
                    NameOriginsCountryRow(country: country)
                }
            }
            .designFrame(x: 16, y: 76, width: 324, height: 152)
        }
    }
}

private struct NameOriginsCountryRow: View {
    let country: NameOriginCountryResult

    var body: some View {
        HStack(spacing: 8) {
            Image(country.flagAssetName)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

            Text(country.country)
                .font(AppTypography.regular(16))
                .foregroundColor(AppColors.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 8)

            Text(country.countText)
                .font(AppTypography.regular(16))
                .foregroundColor(AppColors.gold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(width: 324, height: 24)
    }
}

private struct NameOriginsDescriptionCard: View {
    let result: NameOriginAnalysisResult

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(descriptionLines, id: \.self) { line in
                Text(line)
                    .font(isHeading(line) ? AppTypography.bold(16) : AppTypography.regular(16))
                    .foregroundColor(AppColors.gold)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: 324, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(NameOriginsInfoBackground())
    }

    private var descriptionLines: [String] {
        result.description
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func isHeading(_ line: String) -> Bool {
        line.count <= 34 && !line.contains(".") && !line.contains(",")
    }
}

private struct NameOriginsInfoBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
            .fill(AppColors.card)
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(AppColors.gold.opacity(0.21), lineWidth: 1)
                    .blendMode(.screen)
            )
            .shadow(color: AppColors.black.opacity(0.25), radius: 1, x: 0, y: 0)
    }
}

#Preview {
    PhotoRestorationView(selectedScreen: .constant(.photoRestoration))
}

#Preview("Photo Restoration Preview") {
    PhotoRestorationView(
        selectedScreen: .constant(.photoRestoration),
        phase: .preview
    )
}

#Preview("Photo Restoration Analyse") {
    PhotoRestorationView(
        selectedScreen: .constant(.photoRestoration),
        phase: .analyzing
    )
}

#Preview("Photo Restoration Result") {
    PhotoRestorationView(
        selectedScreen: .constant(.photoRestoration),
        phase: .result
    )
}

#Preview("Name Origins Empty") {
    NameOriginsView(selectedScreen: .constant(.nameOrigins))
}

#Preview("Name Origins Results") {
    NameOriginsView(
        selectedScreen: .constant(.nameOrigins),
        initialQuery: NameOriginAnalysisResult.placeholder.query,
        initialResult: .placeholder
    )
}
