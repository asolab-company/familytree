import SwiftUI
import PhotosUI
import UIKit

private enum OnboardingDateDefaults {
    static let months = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ]

    static let today: (month: String, day: Int, year: Int) = {
        let date = Date()
        let calendar = Calendar.current
        let monthIndex = calendar.component(.month, from: date) - 1
        let month = months.indices.contains(monthIndex) ? months[monthIndex] : "Jan"
        let day = calendar.component(.day, from: date)
        let year = calendar.component(.year, from: date)

        return (month, day, year)
    }()
}

struct OnboardingView: View {
    @Binding var selectedScreen: AppScreen
    let onCompletedAnalysis: (HeritageAnalysisResult, UIImage?) -> Void

    @State private var page = 0
    @State private var selectedGender: Gender = .female
    @State private var fullName = ""
    @State private var nameErrorMessage: String?
    @State private var month = OnboardingDateDefaults.today.month
    @State private var day = OnboardingDateDefaults.today.day
    @State private var year = OnboardingDateDefaults.today.year
    @State private var selectedPhoto: UIImage?
    @State private var isAnalyzingHeritage = false
    @State private var heritageAnalysisProgress = 0.0
    @State private var analysisErrorMessage: String?

    private let pageCount = 6

    var body: some View {
        TabView(selection: $page) {
            WelcomeOnboardingPage(action: advance)
                .tag(0)

            NameOnboardingPage(
                selectedGender: $selectedGender,
                fullName: $fullName,
                errorMessage: nameErrorMessage,
                action: advanceFromName
            )
            .tag(1)

            BirthDateOnboardingPage(
                month: $month,
                day: $day,
                year: $year,
                action: advance
            )
            .tag(2)

            PhotoIntroOnboardingPage(action: advance)
                .tag(3)

            UploadPhotoOnboardingPage(
                selectedPhoto: $selectedPhoto,
                action: advance
            )
            .tag(4)

            EthnicResultOnboardingPage(
                selectedPhoto: selectedPhoto,
                isLoading: isAnalyzingHeritage,
                progress: heritageAnalysisProgress,
                errorMessage: analysisErrorMessage,
                onBack: returnToPhotoUpload,
                action: analyzeHeritageAndFinish
            )
            .tag(5)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.easeInOut(duration: 0.22), value: page)
        .background(PageSwipeDisabler())
        .ignoresSafeArea()
    }

    private func advance() {
        if page < pageCount - 1 {
            withAnimation(.easeInOut(duration: 0.22)) {
                page += 1
            }
        } else {
            selectedScreen = .familyTree
        }
    }

    private func advanceFromName() {
        let parts = fullNameParts

        guard parts.count >= 2 else {
            nameErrorMessage = "Please enter both first and last name."
            return
        }

        guard isValidNamePart(parts[0]), isValidNamePart(parts[parts.count - 1]) else {
            nameErrorMessage = "First and last name must be at least 2 characters."
            return
        }

        nameErrorMessage = nil
        fullName = parts.joined(separator: " ")
        advance()
    }

    private func analyzeHeritageAndFinish() {
        guard !isAnalyzingHeritage else {
            return
        }

        isAnalyzingHeritage = true
        heritageAnalysisProgress = SmartAnalysisProgress.initialValue
        analysisErrorMessage = nil

        let input = HeritageAnalysisInput(
            fullName: fullName,
            gender: selectedGender.rawValue,
            birthMonth: month,
            birthDay: day,
            birthYear: year
        )

        Task {
            let progressTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    await MainActor.run {
                        heritageAnalysisProgress = SmartAnalysisProgress.nextWaitingValue(from: heritageAnalysisProgress)
                    }
                }
            }

            do {
                let result = try await OpenAIHeritageService().analyze(
                    input: input,
                    image: selectedPhoto
                )
                progressTask.cancel()
                await SmartAnalysisProgress.complete(from: heritageAnalysisProgress) {
                    heritageAnalysisProgress = $0
                }
                isAnalyzingHeritage = false
                onCompletedAnalysis(result, selectedPhoto)
            } catch {
                progressTask.cancel()
                analysisErrorMessage = error.localizedDescription
                heritageAnalysisProgress = 0
                isAnalyzingHeritage = false
            }
        }
    }

    private func returnToPhotoUpload() {
        guard !isAnalyzingHeritage else {
            return
        }

        selectedPhoto = nil
        analysisErrorMessage = nil

        withAnimation(.easeInOut(duration: 0.22)) {
            page = 4
        }
    }

    private var fullNameParts: [String] {
        fullName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
    }

    private func isValidNamePart(_ part: String) -> Bool {
        part.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }
}

private struct PageSwipeDisabler: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        disablePagingScroll(from: view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        disablePagingScroll(from: uiView)
    }

    private func disablePagingScroll(from view: UIView) {
        DispatchQueue.main.async {
            guard let root = view.window ?? view.superview else {
                return
            }

            findScrollViews(in: root).forEach { scrollView in
                if scrollView.isPagingEnabled {
                    scrollView.isScrollEnabled = false
                    scrollView.panGestureRecognizer.isEnabled = false
                }
            }
        }
    }

    private func findScrollViews(in view: UIView) -> [UIScrollView] {
        var result = [UIScrollView]()

        if let scrollView = view as? UIScrollView {
            result.append(scrollView)
        }

        for subview in view.subviews {
            result.append(contentsOf: findScrollViews(in: subview))
        }

        return result
    }
}

private enum Gender: String, CaseIterable {
    case male = "Male"
    case female = "Female"
}

private enum OnboardingLayout {
    static let screenWidth: CGFloat = AppMetrics.designWidth
    static let screenHeight: CGFloat = AppMetrics.designHeight
    static let horizontalPadding: CGFloat = 18

    static let buttonHeight: CGFloat = 60
    static let heroHeight: CGFloat = 505
    static let formLogoTop: CGFloat = 126
    static let formLogoToTitle: CGFloat = 53
    static let bottomInset: CGFloat = 70
}

private struct OnboardingAdaptiveMetrics {
    let screenHeight: CGFloat
    let isCompact: Bool

    var logoTop: CGFloat { isCompact ? 72 : OnboardingLayout.formLogoTop }
    var logoSize: CGFloat { isCompact ? 108 : 130 }
    var logoToTitle: CGFloat { isCompact ? 30 : OnboardingLayout.formLogoToTitle }
    var titleToBody: CGFloat { isCompact ? 7 : 9 }
    var nameBodyToControls: CGFloat { isCompact ? 42 : 76 }
    var fieldTop: CGFloat { isCompact ? 14 : 21 }
    var birthBodyToPicker: CGFloat { isCompact ? 42 : 72 }
    var uploadBodyToTips: CGFloat { isCompact ? 38 : 76 }
    var tipsTitleToList: CGFloat { isCompact ? 8 : 10 }
    var tipsListHeight: CGFloat { isCompact ? 126 : 140 }
    var heroHeight: CGFloat { isCompact ? 424 : OnboardingLayout.heroHeight }
    var heroToTitle: CGFloat { isCompact ? 22 : 39 }
    var resultTop: CGFloat { isCompact ? 42 : 67 }
    var resultHeaderToPhoto: CGFloat { isCompact ? 18 : 28 }
    var resultPhotoHeight: CGFloat { isCompact ? 500 : 570 }
    var resultProgressBottomPadding: CGFloat { isCompact ? 16 : 38 }
    var bottomInset: CGFloat { isCompact ? 16 : OnboardingLayout.bottomInset }
}

private struct OnboardingAdaptivePage<Content: View>: View {
    let content: (OnboardingAdaptiveMetrics) -> Content

    init(@ViewBuilder content: @escaping (OnboardingAdaptiveMetrics) -> Content) {
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            let widthScale = proxy.size.width / AppMetrics.designWidth
            let designHeight = proxy.size.height / max(widthScale, 0.01)
            let metrics = OnboardingAdaptiveMetrics(
                screenHeight: designHeight,
                isCompact: designHeight < AppMetrics.designHeight - 1
            )

            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()

                content(metrics)
                    .frame(width: AppMetrics.designWidth, height: designHeight)
                    .scaleEffect(widthScale, anchor: .top)
                    .frame(
                        width: proxy.size.width,
                        height: proxy.size.height,
                        alignment: .top
                    )
                    .clipped()
            }
        }
        .ignoresSafeArea()
    }
}

private struct AppBackground: View {
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

private struct WelcomeOnboardingPage: View {
    let action: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let isCompactHeight = size.height < AppMetrics.designHeight
            let heroHeight = min(
                OnboardingLayout.heroHeight,
                max(332, size.height * (isCompactHeight ? 0.54 : 0.59))
            )
            let titleTopSpacing = isCompactHeight ? 22.0 : 36.0
            let bodyTopSpacing = isCompactHeight ? 10.0 : 14.0
            let bottomSpacing = isCompactHeight ? 12.0 : 27.0

            ZStack {
                LinearGradient(
                    colors: [AppColors.bgTop, AppColors.bgBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: size.width, height: size.height)

                VStack(spacing: 0) {
                    OnboardingHeroImage(assetName: "app_bg_onbording")
                        .heroContentOffset(isCompactHeight ? -34 : 0)
                        .frame(
                            width: size.width,
                            height: heroHeight
                        )

                    Spacer().frame(height: titleTopSpacing)

                    OnboardingTitle("Welcome To Your Family\nHistory Journey")

                    Spacer().frame(height: bodyTopSpacing)

                    OnboardingBody(
                        "Build and explore your family tree in a simple way.\nDiscover connections across generations and keep\nyour heritage in one place"
                    )

                    Spacer()

                    PrimaryOnboardingButton(
                        title: "Start your journey today",
                        action: action
                    )
                    .frame(height: OnboardingLayout.buttonHeight)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, OnboardingLayout.horizontalPadding)

                    Spacer().frame(height: 12)

                    LegalText()
                        .frame(width: 220, height: 32)

                    Spacer().frame(height: bottomSpacing)
                }
                .frame(
                    width: size.width,
                    height: size.height
                )
            }
        }
        .ignoresSafeArea()
    }
}

private struct NameOnboardingPage: View {
    @Binding var selectedGender: Gender
    @Binding var fullName: String
    let errorMessage: String?
    let action: () -> Void

    @FocusState private var isNameFocused: Bool
    @State private var keyboardHeight: CGFloat = 0

    var body: some View {
        OnboardingAdaptivePage { metrics in
            ZStack(alignment: .topLeading) {
                AppBackground(height: metrics.screenHeight)

                VStack(spacing: 0) {
                    Spacer().frame(height: metrics.logoTop)

                    LogoBadge()
                        .frame(width: metrics.logoSize, height: metrics.logoSize)

                    Spacer().frame(height: metrics.logoToTitle)

                    OnboardingTitle("What’s Your Name?")

                    Spacer().frame(height: metrics.titleToBody)

                    OnboardingBody(
                        "Enter your first and last name so we can\nstart building your family tree around you."
                    )

                    Spacer().frame(height: metrics.nameBodyToControls)

                    HStack(spacing: 16) {
                        ForEach(Gender.allCases, id: \.self) { gender in
                            GenderButton(
                                title: gender.rawValue,
                                isSelected: selectedGender == gender
                            ) {
                                selectedGender = gender
                            }
                        }
                    }
                    .frame(height: OnboardingLayout.buttonHeight)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, OnboardingLayout.horizontalPadding)

                    Spacer().frame(height: metrics.fieldTop)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("First and Last Name*")
                            .font(AppTypography.medium(16))
                            .foregroundColor(AppColors.gold)
                            .padding(.leading, 16)

                        TextField(
                            "",
                            text: $fullName,
                            prompt: Text("Enter First and Last Name*").foregroundColor(
                                AppColors.placeholder
                            )
                        )
                        .font(AppTypography.regular(16))
                        .foregroundColor(AppColors.gold)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(
                            RoundedRectangle(
                                cornerRadius: 24,
                                style: .continuous
                            )
                            .fill(AppColors.field.opacity(0.72))
                            .overlay(
                                RoundedRectangle(
                                    cornerRadius: 24,
                                    style: .continuous
                                )
                                .stroke(AppColors.fieldStroke, lineWidth: 1)
                            )
                        )
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .focused($isNameFocused)
                        .onSubmit {
                            isNameFocused = false
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(AppTypography.regular(12))
                                .foregroundColor(AppColors.muted)
                                .padding(.leading, 16)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, OnboardingLayout.horizontalPadding)

                    Spacer()

                    PrimaryOnboardingButton(title: "Continue", action: action)
                        .frame(height: OnboardingLayout.buttonHeight)
                        .frame(maxWidth: .infinity)
                        .padding(
                            .horizontal,
                            OnboardingLayout.horizontalPadding
                        )

                    Spacer().frame(height: metrics.bottomInset)
                }
                .frame(
                    width: OnboardingLayout.screenWidth,
                    height: metrics.screenHeight
                )
                .offset(y: keyboardAwareOffset)
                .animation(.easeInOut(duration: 0.22), value: keyboardAwareOffset)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
            updateKeyboardHeight(from: notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
    }

    private var keyboardAwareOffset: CGFloat {
        guard isNameFocused, keyboardHeight > 0 else {
            return 0
        }

        return -min(170, max(112, keyboardHeight * 0.42))
    }

    private func updateKeyboardHeight(from notification: Notification) {
        guard
            let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        else {
            return
        }

        keyboardHeight = max(0, UIScreen.main.bounds.maxY - frame.minY)
    }
}

private struct BirthDateOnboardingPage: View {
    @Binding var month: String
    @Binding var day: Int
    @Binding var year: Int
    let action: () -> Void

    private let months = OnboardingDateDefaults.months
    private let days = Array(1...31)
    private let years = Array(1900...2026)

    var body: some View {
        OnboardingAdaptivePage { metrics in
            ZStack(alignment: .topLeading) {
                AppBackground(height: metrics.screenHeight)

                VStack(spacing: 0) {
                    Spacer().frame(height: metrics.logoTop)

                    LogoBadge()
                        .frame(width: metrics.logoSize, height: metrics.logoSize)

                    Spacer().frame(height: metrics.logoToTitle)

                    OnboardingTitle("When Were You Born?")

                    Spacer().frame(height: metrics.titleToBody)

                    OnboardingBody(
                        "Your date of birth helps us place you correctly\nin your family timeline."
                    )

                    Spacer().frame(height: metrics.birthBodyToPicker)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Date of Birth")
                            .font(AppTypography.medium(16))
                            .foregroundColor(AppColors.gold)
                            .padding(.leading, 17)

                        WheelDatePicker(
                            month: $month,
                            day: $day,
                            year: $year,
                            months: months,
                            days: days,
                            years: years
                        )
                        
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, OnboardingLayout.horizontalPadding)

                    Spacer()

                    PrimaryOnboardingButton(title: "Continue", action: action)
                        .frame(height: OnboardingLayout.buttonHeight)
                        .frame(maxWidth: .infinity)
                        .padding(
                            .horizontal,
                            OnboardingLayout.horizontalPadding
                        )

                    Spacer().frame(height: metrics.bottomInset)
                }
                .frame(
                    width: OnboardingLayout.screenWidth,
                    height: metrics.screenHeight
                )
            }
        }
    }
}

private struct PhotoIntroOnboardingPage: View {
    let action: () -> Void

    var body: some View {
        OnboardingAdaptivePage { metrics in
            ZStack(alignment: .topLeading) {
                AppBackground(height: metrics.screenHeight)

                VStack(spacing: 0) {
                    OnboardingHeroImage(assetName: "app_bg_onbording2")
                        .heroContentOffset(metrics.isCompact ? -34 : 0)
                        .frame(
                            width: OnboardingLayout.screenWidth,
                            height: metrics.heroHeight
                        )
                        .ignoresSafeArea()

                    Spacer().frame(height: metrics.heroToTitle)

                    OnboardingTitle("We Need Your Photo\nTo Begin")

                    Spacer().frame(height: 14)

                    OnboardingBody(
                        "To generate your family tree insights, we use your\nphoto as a starting point for analysis and\npersonalization."
                    )

                    Spacer()

                    PrimaryOnboardingButton(title: "Continue", action: action)
                        .frame(height: OnboardingLayout.buttonHeight)
                        .frame(maxWidth: .infinity)
                        .padding(
                            .horizontal,
                            OnboardingLayout.horizontalPadding
                        )

                    Spacer().frame(height: metrics.bottomInset)
                }
                .frame(
                    width: OnboardingLayout.screenWidth,
                    height: metrics.screenHeight
                )
            }
        }
    }
}

private struct UploadPhotoOnboardingPage: View {
    @Binding var selectedPhoto: UIImage?
    let action: () -> Void

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isShowingCamera = false

    var body: some View {
        OnboardingAdaptivePage { metrics in
            ZStack(alignment: .topLeading) {
                AppBackground(height: metrics.screenHeight)

                VStack(spacing: 0) {
                    Spacer().frame(height: metrics.logoTop)

                    LogoBadge()
                        .frame(width: metrics.logoSize, height: metrics.logoSize)

                    Spacer().frame(height: metrics.logoToTitle)

                    OnboardingTitle("Upload Your Photo")

                    Spacer().frame(height: metrics.titleToBody)

                    OnboardingBody(
                        "Please take or upload a clear photo of yourself. This\nhelps us create your initial family tree profile."
                    )

                    Spacer().frame(height: metrics.uploadBodyToTips)

                    Text("Tips for fast scanning:")
                        .font(AppTypography.regular(16))
                        .foregroundColor(AppColors.gold)

                    Spacer().frame(height: metrics.tipsTitleToList)

                    VStack(alignment: .leading, spacing: 16) {
                        ScanTip(
                            icon: "app_ic_light",
                            title: "Lighting",
                            subtitle: "Use front lighting to avoid side shadows"
                        )
                        ScanTip(
                            icon: "app_ic_pose",
                            title: "Pose",
                            subtitle: "Hold the camera at eye level, face forward"
                        )
                        ScanTip(
                            icon: "app_ic_glass",
                            title: "Glasses/accessories",
                            subtitle:
                                "Avoid glare, no hats, keep hair away from your face"
                        )
                    }
                    .frame(height: metrics.tipsListHeight)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, OnboardingLayout.horizontalPadding)

                    Spacer()

                    HStack(spacing: 16) {
                        PhotosPicker(
                            selection: $selectedPhotoItem,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            PrimaryOnboardingButtonLabel(title: "Select Photo")
                        }
                        .frame(height: OnboardingLayout.buttonHeight)
                        .frame(maxWidth: .infinity)

                        Button {
                            isShowingCamera = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                AppColors.greenTop,
                                                AppColors.greenBottom,
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )

                                Image(systemName: "camera.fill")
                                    .font(
                                        .system(size: 20, weight: .semibold)
                                    )
                                    .foregroundColor(AppColors.gold)
                            }
                            .frame(
                                width: OnboardingLayout.buttonHeight,
                                height: OnboardingLayout.buttonHeight
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, OnboardingLayout.horizontalPadding)

                    Spacer().frame(height: metrics.bottomInset)
                }
                .frame(
                    width: OnboardingLayout.screenWidth,
                    height: metrics.screenHeight
                )
            }
        }
        .sheet(isPresented: $isShowingCamera) {
            CameraPicker { image in
                selectedPhoto = image
                isShowingCamera = false
                action()
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
            guard
                let data = try? await item.loadTransferable(type: Data.self),
                let image = UIImage(data: data)
            else {
                return
            }

            selectedPhoto = image
            selectedPhotoItem = nil
            action()
        }
    }
}

private struct EthnicResultOnboardingPage: View {
    let selectedPhoto: UIImage?
    let isLoading: Bool
    let progress: Double
    let errorMessage: String?
    let onBack: () -> Void
    let action: () -> Void

    var body: some View {
        OnboardingAdaptivePage { metrics in
            ZStack(alignment: .topLeading) {
                AppBackground(height: metrics.screenHeight)

                VStack(spacing: 0) {
                    Spacer().frame(height: metrics.resultTop)

                    HStack {
                        if !isLoading {
                            HeaderBackTitle(title: "Ethnic Origin", action: onBack)
                        } else {
                            Text("Ethnic Origin")
                                .font(AppTypography.bold(24))
                                .foregroundColor(AppColors.gold)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 19)
                    .frame(height: 40)

                    Spacer().frame(height: metrics.resultHeaderToPhoto)

                    ZStack(alignment: .bottom) {
                        VintagePortraitCard(image: selectedPhoto)

                        if isLoading {
                            OnboardingAnalysisProgress(progress: progress)
                                .frame(
                                    width: OnboardingLayout.screenWidth - OnboardingLayout.horizontalPadding * 2
                                )
                                .padding(.bottom, metrics.resultProgressBottomPadding)
                        }
                    }
                    .frame(
                        width: OnboardingLayout.screenWidth,
                        height: metrics.resultPhotoHeight
                    )
                    .clipped()

                    Spacer()

                    if !isLoading, let errorMessage {
                        Text(errorMessage)
                            .font(AppTypography.regular(12))
                            .foregroundColor(AppColors.muted)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 28)
                            .padding(.bottom, 10)
                    }

                    PrimaryOnboardingButton(
                        title: buttonTitle,
                        action: action
                    )
                        .frame(height: OnboardingLayout.buttonHeight)
                        .frame(maxWidth: .infinity)
                        .padding(
                            .horizontal,
                            OnboardingLayout.horizontalPadding
                        )
                        .disabled(isLoading)
                        .opacity(isLoading ? 0.72 : 1)

                    Spacer().frame(height: metrics.bottomInset)
                }
                .frame(
                    width: OnboardingLayout.screenWidth,
                    height: metrics.screenHeight
                )
            }
        }
    }

    private var buttonTitle: String {
        if isLoading {
            return "Analyzing..."
        }

        return "Continue"
    }
}

private struct OnboardingAnalysisProgress: View {
    let progress: Double

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Analyzing...")
                    .font(AppTypography.regular(14))
                    .foregroundColor(AppColors.gold)

                Spacer()

                Text("\(Int(progress * 100))%")
                    .font(AppTypography.bold(14))
                    .foregroundColor(AppColors.gold)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColors.white.opacity(0.12))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppColors.greenTop,
                                    AppColors.greenBottom
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * min(max(progress, 0), 1))
                        .shadow(color: AppColors.greenTop.opacity(0.35), radius: 8, x: 0, y: 0)
                }
            }
            .frame(height: 6)
            .animation(.easeInOut(duration: 0.22), value: progress)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppColors.bgTop.opacity(0.88))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(AppColors.gold.opacity(0.32), lineWidth: 1)
                )
                .shadow(color: AppColors.black.opacity(0.36), radius: 14, x: 0, y: 6)
        )
    }
}

private struct CameraPicker: UIViewControllerRepresentable {
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

    final class Coordinator: NSObject, UINavigationControllerDelegate,
        UIImagePickerControllerDelegate
    {
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

private struct OnboardingHeroImage: View {
    let assetName: String
    @Environment(\.onboardingHeroContentOffset) private var contentOffset

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFill()
            .offset(y: contentOffset)
            .clipShape(
                RoundedCornerShape(
                    radius: 40,
                    corners: [.bottomLeft, .bottomRight]
                )
            )
            .clipped()
    }
}

private struct OnboardingHeroContentOffsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

private extension EnvironmentValues {
    var onboardingHeroContentOffset: CGFloat {
        get { self[OnboardingHeroContentOffsetKey.self] }
        set { self[OnboardingHeroContentOffsetKey.self] = newValue }
    }
}

private extension View {
    func heroContentOffset(_ offset: CGFloat) -> some View {
        environment(\.onboardingHeroContentOffset, offset)
    }
}

private struct EthnicHero: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            PhotoWallBackdrop()
                .frame(width: 493, height: 634)
                .offset(x: -50, y: -129)
                .clipShape(
                    RoundedCornerShape(
                        radius: 40,
                        corners: [.bottomLeft, .bottomRight]
                    )
                )
                .blur(radius: 1.6)
                .overlay(Color.black.opacity(0.38))
                .clipShape(
                    RoundedCornerShape(
                        radius: 40,
                        corners: [.bottomLeft, .bottomRight]
                    )
                )

            PhoneEthnicMockup()
                .designFrame(x: 72, y: 58, width: 248, height: 521)
        }
        .frame(width: 393, height: 505)
        .clipped()
    }
}

private struct PhoneEthnicMockup: View {
    var body: some View {
        PhoneShell {
            ZStack(alignment: .topLeading) {
                HeaderBackTitle(title: "Ethnic Origin", compact: true)
                    .designFrame(x: 17, y: 44, width: 170, height: 24)

                SettingsCircle(icon: "trash")
                    .designFrame(x: 206, y: 51, width: 24, height: 24)

                VintagePortraitCard(compact: true)
                    .designFrame(x: 19, y: 93, width: 210, height: 215)

                ScanBeam()
                    .designFrame(x: 8, y: 238, width: 232, height: 40)

                ResultPanel()
                    .designFrame(x: 19, y: 320, width: 210, height: 140)
            }
        }
    }
}

private struct PhoneShell<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.black)
                .shadow(color: .black.opacity(0.75), radius: 8, x: 0, y: 4)

            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x332D22), Color(hex: 0x1F1B15)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(PhotoWallBackdrop().opacity(0.12))
                .clipShape(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                )
                .padding(6)

            Capsule()
                .fill(Color.black)
                .frame(width: 76, height: 22)
                .position(x: 124, y: 19)

            content()
                .frame(width: 248, height: 521)
        }
        .frame(width: 248, height: 521)
        .clipped()
    }
}

private struct PhotoWallBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x6D614B), Color(hex: 0x25211A)],
                startPoint: .top,
                endPoint: .bottom
            )

            ForEach(0..<12) { index in
                PhotoFrame(index: index)
            }

            Rectangle()
                .fill(Color.black.opacity(0.18))
        }
    }
}

private struct PhotoFrame: View {
    let index: Int

    private var x: CGFloat {
        [-8, 74, 178, 314, 418, 34, 140, 266, 382, 96, 226, 344][index]
    }
    private var y: CGFloat {
        [12, -18, 34, 6, 70, 182, 148, 196, 164, 346, 320, 372][index]
    }
    private var width: CGFloat {
        [82, 96, 112, 90, 76, 72, 104, 94, 78, 112, 92, 88][index]
    }
    private var height: CGFloat {
        [110, 120, 132, 118, 104, 92, 122, 118, 98, 132, 120, 108][index]
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(hex: 0xB7A98E).opacity(0.5),
                        Color(hex: 0x2B261E).opacity(0.82),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(
                    systemName: index.isMultiple(of: 2)
                        ? "person.fill" : "person.2.fill"
                )
                .font(.system(size: min(width, height) * 0.28))
                .foregroundColor(Color(hex: 0x16130F).opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Color.black.opacity(0.45), lineWidth: 5)
            )
            .frame(width: width, height: height)
            .rotationEffect(
                .degrees([-8, 5, -3, 7, -4, 3, -7, 4, -5, 6, -4, 3][index])
            )
            .position(x: x, y: y)
    }
}

private struct SettingsCircle: View {
    var icon = "gearshape"

    var body: some View {
        Circle()
            .fill(AppColors.glassStrong)
            .overlay(
                Circle().stroke(AppColors.white.opacity(0.35), lineWidth: 0.8)
            )
            .overlay(
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.gold)
            )
    }
}

private struct LogoBadge: View {
    var body: some View {
        Image(DesignAsset.Loading.logo)
            .resizable()
            .scaledToFit()
            .accessibilityHidden(true)
    }
}

private struct PrimaryOnboardingButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PrimaryOnboardingButtonLabel(title: title)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private struct PrimaryOnboardingButtonLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(AppTypography.medium(18))
            .foregroundColor(AppColors.gold)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppColors.greenTop,
                                AppColors.greenBottom,
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(Color.white.opacity(0.21), lineWidth: 1)
                    )
            )
            .accessibilityLabel(title)
    }
}

private struct GenderButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTypography.medium(18))
                .foregroundColor(AppColors.gold)
                .frame(width: 170, height: 60)
                .contentShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(AppColors.glass)
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(
                            isSelected ? AppColors.gold : Color.clear,
                            lineWidth: 1
                        )
                )
        )
    }
}

private struct WheelDatePicker: View {
    @Binding var month: String
    @Binding var day: Int
    @Binding var year: Int
    let months: [String]
    let days: [Int]
    let years: [Int]

    var body: some View {
        ZStack {
            VStack(spacing: WheelPickerMetrics.rowHeight - 2) {
                DividerLine()
                DividerLine()
            }
            .frame(height: WheelPickerMetrics.rowHeight)
            .frame(maxWidth: .infinity)

            NativeWheelDatePicker(
                month: $month,
                day: $day,
                year: $year,
                months: months,
                days: days,
                years: years
            )
            .frame(width: 304, height: WheelPickerMetrics.height)
        }
    }
}

private enum WheelPickerMetrics {
    static let height: CGFloat = 142
    static let rowHeight: CGFloat = 39
}

private struct NativeWheelDatePicker: UIViewRepresentable {
    @Binding var month: String
    @Binding var day: Int
    @Binding var year: Int

    let months: [String]
    let days: [Int]
    let years: [Int]

    func makeUIView(context: Context) -> UIPickerView {
        let pickerView = UIPickerView()
        pickerView.backgroundColor = .clear
        pickerView.dataSource = context.coordinator
        pickerView.delegate = context.coordinator
        pickerView.clipsToBounds = true
        pickerView.subviews.forEach { $0.backgroundColor = .clear }
        selectCurrentRows(in: pickerView, animated: false)
        return pickerView
    }

    func updateUIView(_ pickerView: UIPickerView, context: Context) {
        context.coordinator.parent = self
        pickerView.subviews.forEach { $0.backgroundColor = .clear }
        selectCurrentRows(in: pickerView, animated: false)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    private func selectCurrentRows(in pickerView: UIPickerView, animated: Bool) {
        pickerView.selectRow(index(of: month, in: months), inComponent: 0, animated: animated)
        pickerView.selectRow(index(of: day, in: days), inComponent: 1, animated: animated)
        pickerView.selectRow(index(of: year, in: years), inComponent: 2, animated: animated)
    }

    private func index<Value: Equatable>(of value: Value, in values: [Value]) -> Int {
        values.firstIndex(of: value) ?? 0
    }

    final class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
        var parent: NativeWheelDatePicker

        init(parent: NativeWheelDatePicker) {
            self.parent = parent
        }

        func numberOfComponents(in pickerView: UIPickerView) -> Int {
            3
        }

        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            valuesCount(for: component)
        }

        func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
            WheelPickerMetrics.rowHeight
        }

        func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
            switch component {
            case 0:
                98
            case 1:
                78
            default:
                112
            }
        }

        func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
            let isSelected = pickerView.selectedRow(inComponent: component) == row
            let color = isSelected ? UIColor(hex: 0xF8DBB9) : UIColor(hex: 0x777777)
            let font = UIFont(name: "Alegreya-Regular", size: isSelected ? 23 : 21)
                ?? .systemFont(ofSize: isSelected ? 23 : 21)

            return NSAttributedString(
                string: title(for: row, component: component),
                attributes: [
                    .foregroundColor: color,
                    .font: font,
                    .kern: 0.7,
                ]
            )
        }

        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            switch component {
            case 0:
                parent.month = parent.months[row]
            case 1:
                parent.day = parent.days[row]
            default:
                parent.year = parent.years[row]
            }

            pickerView.reloadAllComponents()
        }

        private func valuesCount(for component: Int) -> Int {
            switch component {
            case 0:
                parent.months.count
            case 1:
                parent.days.count
            default:
                parent.years.count
            }
        }

        private func title(for row: Int, component: Int) -> String {
            switch component {
            case 0:
                parent.months[row]
            case 1:
                "\(parent.days[row])"
            default:
                "\(parent.years[row])"
            }
        }
    }
}

private extension UIColor {
    convenience init(hex: UInt, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

private struct WheelScrollColumn<Value: Hashable>: View {
    @Binding var selection: Value
    let values: [Value]
    let width: CGFloat
    let title: (Value) -> String

    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            ForEach(Array(values.enumerated()), id: \.element) { index, value in
                let offset = offset(for: index)

                Button {
                    select(value)
                } label: {
                    Text(title(value))
                        .font(AppTypography.regular(23))
                        .foregroundColor(color(for: value))
                        .frame(width: width, height: WheelPickerMetrics.rowHeight)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .offset(y: offset)
                .opacity(opacity(for: offset))
                .allowsHitTesting(abs(offset) <= WheelPickerMetrics.height / 2)
            }
        }
        .frame(width: width, height: WheelPickerMetrics.height)
        .clipped()
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 8)
                .updating($dragOffset) { value, state, _ in
                    state = limitedDragOffset(value.translation.height)
                }
                .onEnded { value in
                    settleDrag(value.predictedEndTranslation.height)
                }
        )
    }

    private var selectedIndex: Int {
        values.firstIndex(of: selection) ?? values.startIndex
    }

    private func offset(for index: Int) -> CGFloat {
        CGFloat(index - selectedIndex) * WheelPickerMetrics.rowHeight
            + dragOffset
    }

    private func opacity(for offset: CGFloat) -> Double {
        let visibleDistance = WheelPickerMetrics.height / 2
        let normalized = min(abs(offset) / visibleDistance, 1)
        return Double(1 - normalized * 0.45)
    }

    private func color(for value: Value) -> Color {
        value == selection ? AppColors.goldSoft : Color(hex: 0x777777)
    }

    private func select(_ value: Value) {
        guard selection != value else {
            return
        }

        withAnimation(.easeInOut(duration: 0.18)) {
            selection = value
        }
    }

    private func settleDrag(_ predictedTranslation: CGFloat) {
        guard !values.isEmpty else {
            return
        }

        let delta = Int(round(-predictedTranslation / WheelPickerMetrics.rowHeight))
        let lastIndex = values.index(before: values.endIndex)
        let nextIndex = min(max(selectedIndex + delta, values.startIndex), lastIndex)

        guard values.indices.contains(nextIndex) else {
            return
        }

        select(values[nextIndex])
    }

    private func limitedDragOffset(_ offset: CGFloat) -> CGFloat {
        guard !values.isEmpty else {
            return 0
        }

        let minOffset = -CGFloat(values.index(before: values.endIndex) - selectedIndex)
            * WheelPickerMetrics.rowHeight
        let maxOffset = CGFloat(selectedIndex) * WheelPickerMetrics.rowHeight

        return min(max(offset, minOffset), maxOffset)
    }
}

private struct DividerLine: View {
    var body: some View {
        Rectangle()
            .fill(Color(hex: 0x7B705E).opacity(0.7))
            .frame(maxWidth: .infinity, maxHeight: 1)
    }
}

private struct ScanTip: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(AppColors.gold)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(AppTypography.bold(14))
                    .foregroundColor(AppColors.gold)
                    .lineLimit(1)

                Text(subtitle)
                    .font(AppTypography.regular(14))
                    .foregroundColor(AppColors.gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }
}

private struct OnboardingTitle: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(AppTypography.bold(24))
            .foregroundColor(AppColors.gold)
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 38)
    }
}

private struct OnboardingBody: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(AppTypography.regular(16))
            .foregroundColor(AppColors.muted)
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, OnboardingLayout.horizontalPadding)
    }
}

private struct LegalText: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            Text("By Proceeding You Accept")
                .font(AppTypography.medium(12))
                .foregroundColor(AppColors.muted)

            HStack(spacing: 0) {
                Text("Our ")
                    .foregroundColor(AppColors.muted)

                Button {
                    openURL(AppConfiguration.Legal.termsOfUseURL)
                } label: {
                    Text("Terms Of Use")
                        .foregroundColor(AppColors.gold)
                }
                .buttonStyle(.plain)

                Text(" And ")
                    .foregroundColor(AppColors.muted)

                Button {
                    openURL(AppConfiguration.Legal.privacyPolicyURL)
                } label: {
                    Text("Privacy Policy")
                        .foregroundColor(AppColors.gold)
                }
                .buttonStyle(.plain)
            }
            .font(AppTypography.medium(12))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        }
        .multilineTextAlignment(.center)
    }
}

private struct HeaderBackTitle: View {
    let title: String
    var compact = false
    var action: (() -> Void)?

    var body: some View {
        HStack(spacing: compact ? 12 : 16) {
            Button {
                action?()
            } label: {
                Circle()
                    .fill(AppColors.glassStrong)
                    .overlay(
                        Circle().stroke(AppColors.white.opacity(0.35), lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: "chevron.left")
                            .font(.system(size: compact ? 11 : 18, weight: .medium))
                            .foregroundColor(AppColors.gold)
                    )
                    .frame(width: compact ? 24 : 40, height: compact ? 24 : 40)
            }
            .buttonStyle(.plain)
            .disabled(action == nil)

            Text(title)
                .font(AppTypography.bold(compact ? 14 : 24))
                .foregroundColor(AppColors.gold)
        }
    }
}

private struct VintagePortraitCard: View {
    var image: UIImage?
    var compact = false

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [
                        Color(hex: 0xC8B9A0), Color(hex: 0x776B58),
                        Color(hex: 0x29241D),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(spacing: compact ? 12 : 22) {
                    Image(systemName: "person.crop.rectangle")
                        .font(
                            .system(size: compact ? 82 : 168, weight: .light)
                        )
                        .foregroundColor(Color(hex: 0x2D271F).opacity(0.55))

                    Rectangle()
                        .fill(Color.black.opacity(0.22))
                        .frame(height: compact ? 1 : 2)
                        .padding(.horizontal, compact ? 24 : 44)
                }
            }

            Rectangle()
                .fill(Color.white.opacity(0.09))
                .blendMode(.screen)

            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.32)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .clipShape(
            RoundedRectangle(cornerRadius: compact ? 16 : 0, style: .continuous)
        )
    }
}

private struct ScanBeam: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.green.opacity(0), Color.green.opacity(0.62),
                    Color.green.opacity(0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Rectangle()
                .fill(Color.green)
                .frame(height: 3)
                .shadow(color: .green, radius: 8)
        }
    }
}

private struct ResultPanel: View {
    private let rows = [
        ("Russia", 45, Color(hex: 0xF8F8F8)),
        ("Belarus", 21, Color(hex: 0xC7233C)),
        ("Ukraine", 18, Color(hex: 0x2E8FE8)),
        ("Kazakhstan", 10, Color(hex: 0x00A5B7)),
        ("Israel", 6, Color(hex: 0x8ED1EF)),
    ]

    var body: some View {
        VStack(spacing: 7) {
            Text("Result:")
                .font(AppTypography.bold(9))
                .foregroundColor(AppColors.gold)

            ForEach(rows, id: \.0) { row in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(row.2)
                        .frame(width: 24, height: 12)

                    Text(row.0)
                        .font(AppTypography.regular(9))
                        .foregroundColor(AppColors.muted)

                    Spacer()

                    Text("\(row.1)%")
                        .font(AppTypography.regular(9))
                        .foregroundColor(AppColors.gold.opacity(0.72))
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(hex: 0x2A251D).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppColors.gold.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

private struct RoundedCornerShape: Shape {
    let radius: CGFloat
    let corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    OnboardingView(selectedScreen: .constant(.onboarding)) { _, _ in }
}
