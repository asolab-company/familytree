import PhotosUI
import SwiftUI
import UIKit

struct AddFamilyMemberView: View {
    @Binding var selectedScreen: AppScreen
    @ObservedObject var familyTreeStore: FamilyTreeStore
    private let headerTitle: String

    @State private var gender: FamilyMemberGender = .female
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var maidenName = ""
    @State private var placeOfBirth = ""
    @State private var placeOfDeath = ""
    @State private var relationship = ""
    @State private var showValidation = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var profileImage: UIImage?

    @State private var birthMonth = AddFamilyMemberDateDefaults.month
    @State private var birthDay = AddFamilyMemberDateDefaults.day
    @State private var birthYear = AddFamilyMemberDateDefaults.year
    @State private var deathMonth = AddFamilyMemberDateDefaults.month
    @State private var deathDay = AddFamilyMemberDateDefaults.day
    @State private var deathYear = AddFamilyMemberDateDefaults.year

    init(
        selectedScreen: Binding<AppScreen>,
        familyTreeStore: FamilyTreeStore
    ) {
        _selectedScreen = selectedScreen
        _familyTreeStore = ObservedObject(wrappedValue: familyTreeStore)

        let member = familyTreeStore.editingMember ?? familyTreeStore.rootMember
        headerTitle = member.isFilled ? "Edit Family Member" : "Add New Family Member"
        let birthDate = member.birthDate ?? AddFamilyMemberDateDefaults.currentDate
        let deathDate = member.deathDate ?? AddFamilyMemberDateDefaults.currentDate

        _gender = State(initialValue: FamilyMemberGender(rawValue: member.gender) ?? .female)
        _firstName = State(initialValue: member.firstName)
        _lastName = State(initialValue: member.lastName)
        _maidenName = State(initialValue: member.maidenName)
        _placeOfBirth = State(initialValue: member.placeOfBirth)
        _placeOfDeath = State(initialValue: member.placeOfDeath)
        _relationship = State(initialValue: member.relationship == "Root" || member.relationship == "Parent" ? "" : member.relationship)
        _birthMonth = State(initialValue: birthDate.month)
        _birthDay = State(initialValue: birthDate.day)
        _birthYear = State(initialValue: birthDate.year)
        _deathMonth = State(initialValue: deathDate.month)
        _deathDay = State(initialValue: deathDate.day)
        _deathYear = State(initialValue: deathDate.year)
        _profileImage = State(initialValue: member.imageData.flatMap { UIImage(data: $0) })
    }

    var body: some View {
        DesignAdaptiveScreenContainer { metrics in
            ZStack(alignment: .topLeading) {
                AddMemberBackground(height: metrics.visibleHeight)
                AddMemberScrollContent(
                    metrics: metrics,
                    gender: $gender,
                    firstName: $firstName,
                    lastName: $lastName,
                    maidenName: $maidenName,
                    placeOfBirth: $placeOfBirth,
                    placeOfDeath: $placeOfDeath,
                    relationship: $relationship,
                    birthMonth: $birthMonth,
                    birthDay: $birthDay,
                    birthYear: $birthYear,
                    deathMonth: $deathMonth,
                    deathDay: $deathDay,
                    deathYear: $deathYear,
                    selectedPhotoItem: $selectedPhotoItem,
                    profileImage: profileImage,
                    showValidation: showValidation,
                    cancelAction: close,
                    saveAction: save
                )
                AddMemberHeader(title: headerTitle, backAction: close)
            }
        }
        .onChange(of: selectedPhotoItem) { _, item in
            loadPhoto(from: item)
        }
    }

    private func close() {
        familyTreeStore.cancelEditing()
        selectedScreen = .familyTree
    }

    private func save() {
        let canSave = !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        guard canSave else {
            withAnimation(.easeInOut(duration: 0.2)) {
                showValidation = true
            }
            return
        }

        let existingMember = familyTreeStore.editingMember ?? familyTreeStore.rootMember
        let imageData = profileImage?.jpegData(compressionQuality: 0.82)
        let nextRelationship = relationship.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? existingMember.relationship
            : relationship

        familyTreeStore.save(
            FamilyTreeMember(
                id: existingMember.id,
                firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
                maidenName: maidenName.trimmingCharacters(in: .whitespacesAndNewlines),
                gender: gender.rawValue,
                birthDate: FamilyTreeDate(month: birthMonth, day: birthDay, year: birthYear),
                deathDate: placeOfDeath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil
                    : FamilyTreeDate(month: deathMonth, day: deathDay, year: deathYear),
                placeOfBirth: placeOfBirth.trimmingCharacters(in: .whitespacesAndNewlines),
                placeOfDeath: placeOfDeath.trimmingCharacters(in: .whitespacesAndNewlines),
                relationship: nextRelationship,
                imageData: imageData,
                parentIDs: existingMember.parentIDs
            )
        )

        selectedScreen = .familyTree
    }

    private func loadPhoto(from item: PhotosPickerItem?) {
        guard let item else {
            return
        }

        Task {
            defer { selectedPhotoItem = nil }

            guard
                let data = try? await item.loadTransferable(type: Data.self),
                let image = UIImage(data: data)
            else {
                return
            }

            profileImage = image
        }
    }
}

private enum FamilyMemberGender: String, CaseIterable {
    case male = "Male"
    case female = "Female"
}

private enum AddFamilyMemberDateDefaults {
    private static let components = Calendar.current.dateComponents([.day, .month, .year], from: Date())
    static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    static let month = months[max(0, min((components.month ?? 1) - 1, months.count - 1))]
    static let day = components.day ?? 1
    static let year = components.year ?? 2026
    static let currentDate = FamilyTreeDate(month: month, day: day, year: year)
}

private struct AddMemberBackground: View {
    var height: CGFloat = AppMetrics.designHeight

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: AppColors.bgTop, location: 0),
                .init(color: AppColors.bgTop, location: 0.2548),
                .init(color: AppColors.bgBottom, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: AppMetrics.designWidth, height: height)
        .ignoresSafeArea()
    }
}

private struct AddMemberHeader: View {
    let title: String
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
                 

                    Image(DesignAsset.AddMember.backArrow)
                        .resizable()
                        .scaledToFit()
                     
                }
                .frame(width: 40, height: 40)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .designFrame(x: 19, y: 67, width: 40, height: 40)

            Text(title)
                .font(AppTypography.bold(24))
                .foregroundColor(AppColors.gold)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(width: 260, height: 29, alignment: .leading)
                .position(x: 75 + 130, y: 70 + 14.5)
        }
        .frame(width: AppMetrics.designWidth, height: 136, alignment: .topLeading)
    }
}

private struct AddMemberScrollContent: View {
    let metrics: DesignAdaptiveMetrics

    @Binding var gender: FamilyMemberGender
    @Binding var firstName: String
    @Binding var lastName: String
    @Binding var maidenName: String
    @Binding var placeOfBirth: String
    @Binding var placeOfDeath: String
    @Binding var relationship: String
    @Binding var birthMonth: String
    @Binding var birthDay: Int
    @Binding var birthYear: Int
    @Binding var deathMonth: String
    @Binding var deathDay: Int
    @Binding var deathYear: Int
    @Binding var selectedPhotoItem: PhotosPickerItem?

    let profileImage: UIImage?
    let showValidation: Bool
    let cancelAction: () -> Void
    let saveAction: () -> Void

    @State private var isDateWheelDragging = false

    var body: some View {
        let isCompact = metrics.isCompactHeight
        let fieldSpacing = isCompact ? 10.0 : 12.0
        let dateToFieldSpacing = isCompact ? 13.0 : 17.0
        let bottomPadding = isCompact ? max(120.0, metrics.scrollBottomPadding) : 32.0

        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                AddMemberAvatar(
                    selectedPhotoItem: $selectedPhotoItem,
                    profileImage: profileImage
                )
                    .padding(.top, isCompact ? 124 : 144)

                AddMemberGenderSelector(gender: $gender)
                    .padding(.top, isCompact ? 18 : 25)

                VStack(spacing: 0) {
                    AddMemberTextField(
                        title: "First Name*",
                        placeholder: "Enter First Name*",
                        text: $firstName,
                        isInvalid: showValidation && firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )

                    AddMemberTextField(
                        title: "Last Name*",
                        placeholder: "Enter Last Name*",
                        text: $lastName,
                        isInvalid: showValidation && lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                    .padding(.top, fieldSpacing)

                    AddMemberTextField(
                        title: "Maiden Name (for married women)",
                        placeholder: "Enter Maiden Name (for married women)",
                        text: $maidenName
                    )
                    .padding(.top, fieldSpacing)

                    AddMemberDateSection(
                        title: "Date of Birth",
                        month: $birthMonth,
                        day: $birthDay,
                        year: $birthYear,
                        onInteractionChanged: { isDateWheelDragging = $0 }
                    )
                    .padding(.top, fieldSpacing)

                    AddMemberTextField(
                        title: "Place of Birth",
                        placeholder: "Enter Place of Birth",
                        text: $placeOfBirth
                    )
                    .padding(.top, dateToFieldSpacing)

                    AddMemberDateSection(
                        title: "Date of Death",
                        month: $deathMonth,
                        day: $deathDay,
                        year: $deathYear,
                        onInteractionChanged: { isDateWheelDragging = $0 }
                    )
                    .padding(.top, fieldSpacing)

                    AddMemberTextField(
                        title: "Place of Death",
                        placeholder: "Enter Place of Death",
                        text: $placeOfDeath
                    )
                    .padding(.top, dateToFieldSpacing)

                    AddMemberRelationshipField(selection: $relationship)
                        .padding(.top, fieldSpacing)

                    AddMemberActions(cancelAction: cancelAction, saveAction: saveAction)
                        .padding(.top, isCompact ? 20 : 28)
                        .padding(.bottom, bottomPadding)
                }
                .padding(.top, isCompact ? 14 : 17)
                .padding(.horizontal, 19)
            }
            .frame(width: AppMetrics.designWidth)
        }
        .frame(width: AppMetrics.designWidth, height: metrics.visibleHeight)
        .scrollDisabled(isDateWheelDragging)
        .scrollDismissesKeyboard(.interactively)
        .scrollBounceBehavior(.basedOnSize)
    }
}

private struct AddMemberAvatar: View {
    @Binding var selectedPhotoItem: PhotosPickerItem?
    let profileImage: UIImage?

    var body: some View {
        ZStack(alignment: .topLeading) {
            ZStack {
                if let profileImage {
                    Image(uiImage: profileImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 88, height: 88)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(AppColors.glass)

                    Image(DesignAsset.FamilyTree.profile)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                }
            }
            .frame(width: 88, height: 88)
            .clipShape(Circle())
            .shadow(color: AppColors.black.opacity(0.7), radius: 8, x: 0, y: 0)

            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Image(DesignAsset.FamilyTree.add)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .offset(x: 64, y: 64)
        }
        .frame(width: 88, height: 88, alignment: .topLeading)
    }
}

private struct AddMemberGenderSelector: View {
    @Binding var gender: FamilyMemberGender

    var body: some View {
        HStack(spacing: 16) {
            ForEach(FamilyMemberGender.allCases, id: \.self) { option in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        gender = option
                    }
                } label: {
                    Text(option.rawValue)
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
                                .stroke(option == gender ? AppColors.gold : Color.clear, lineWidth: 1)
                        )
                )
            }
        }
        .frame(width: 356, height: 60)
    }
}

private struct AddMemberTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var isInvalid: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(title)
                .font(AppTypography.regular(16))
                .foregroundColor(AppColors.gold)
                .frame(height: 19, alignment: .leading)

            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(AppTypography.regular(16))
                        .foregroundColor(AppColors.placeholder)
                        .padding(.horizontal, 16)
                        .allowsHitTesting(false)
                }

                TextField("", text: $text)
                    .font(AppTypography.regular(16))
                    .foregroundColor(AppColors.gold)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 16)
            }
            .frame(width: 356, height: 48)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(AppColors.field)
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(isInvalid ? Color.red.opacity(0.8) : AppColors.fieldStroke, lineWidth: 1)
                    )
            )
        }
        .frame(width: 356, alignment: .leading)
    }
}

private struct AddMemberDateSection: View {
    let title: String
    @Binding var month: String
    @Binding var day: Int
    @Binding var year: Int
    let onInteractionChanged: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(AppTypography.regular(16))
                .foregroundColor(AppColors.gold)
                .frame(height: 19, alignment: .leading)

            AppWheelDatePicker(
                month: $month,
                day: $day,
                year: $year,
                months: AddFamilyMemberDateDefaults.months,
                onInteractionChanged: onInteractionChanged
            )
            .frame(width: 356, height: 142)
        }
        .frame(width: 356, alignment: .leading)
    }
}

private struct AddMemberRelationshipField: View {
    @Binding var selection: String

    private let options = [
        "Parent",
        "Child",
        "Sibling",
        "Spouse",
        "Grandparent",
        "Other"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("Family Relationships")
                .font(AppTypography.regular(16))
                .foregroundColor(AppColors.gold)
                .frame(height: 19, alignment: .leading)

            Menu {
                ForEach(options, id: \.self) { option in
                    Button(option) {
                        selection = option
                    }
                }
            } label: {
                HStack {
                    Text(selection.isEmpty ? "Select Relationship" : selection)
                        .font(AppTypography.regular(16))
                        .foregroundColor(selection.isEmpty ? AppColors.placeholder : AppColors.gold)

                    Spacer()

                    Image(DesignAsset.AddMember.downArrow)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 12, height: 24)
                        .rotationEffect(.degrees(90))
                }
                .padding(.horizontal, 16)
                .frame(width: 356, height: 48)
                .contentShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(AppColors.field)
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(AppColors.fieldStroke, lineWidth: 1)
                    )
            )
        }
        .frame(width: 356, alignment: .leading)
    }
}

private struct AddMemberActions: View {
    let cancelAction: () -> Void
    let saveAction: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(action: cancelAction) {
                Text("Cancel")
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
                            .stroke(AppColors.white.opacity(0.21), lineWidth: 1)
                    )
            )

            Button(action: saveAction) {
                Text("Save")
                    .font(AppTypography.medium(18))
                    .foregroundColor(AppColors.gold)
                    .frame(width: 170, height: 60)
                    .contentShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            }
            .buttonStyle(.plain)
            .background(GradientPrimaryButtonShape())
        }
        .frame(width: 356, height: 60)
    }
}

#Preview("Add Member") {
    AddFamilyMemberView(
        selectedScreen: .constant(.addFamilyMember),
        familyTreeStore: FamilyTreeStore()
    )
}

#Preview("Add Member Bottom") {
    AddFamilyMemberView(
        selectedScreen: .constant(.addFamilyMember),
        familyTreeStore: FamilyTreeStore()
    )
}
