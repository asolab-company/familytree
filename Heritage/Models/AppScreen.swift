import Foundation
import Combine
import UIKit

enum AppScreen: Hashable {
    case onboarding
    case familyTree
    case scan
    case tools
    case addFamilyMember
    case settings
    case paywall
    case heritagePaywall
    case photoRestoration
    case nameOrigins

    var requiresPremium: Bool {
        switch self {
        case .photoRestoration, .nameOrigins:
            true
        case .onboarding, .familyTree, .scan, .tools, .addFamilyMember, .settings, .paywall, .heritagePaywall:
            false
        }
    }
}

@MainActor
final class AppFlowViewModel: ObservableObject {
    @Published var currentScreen: AppScreen
    @Published var heritageAnalysisResult: HeritageAnalysisResult?
    let familyTreeStore = FamilyTreeStore()

    private let userDefaults: UserDefaults
    private let onboardingCompletedKey = "heritage.onboarding.completed"
    private var pendingOnboardingScan: PendingOnboardingScan?
    private var paywallReturnScreen: AppScreen = .familyTree
    private var paywallSuccessScreen: AppScreen?

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        currentScreen = userDefaults.bool(forKey: onboardingCompletedKey)
            ? .familyTree
            : .onboarding
    }

    func open(_ screen: AppScreen) {
        currentScreen = screen
    }

    func open(_ screen: AppScreen, hasPremiumAccess: Bool) {
        if screen == .paywall {
            presentMainPaywall(returnTo: currentScreen)
            return
        }

        if screen.requiresPremium && !hasPremiumAccess {
            presentMainPaywall(returnTo: currentScreen, successScreen: screen)
            return
        }

        currentScreen = screen
    }

    func dismissMainPaywall() {
        currentScreen = paywallReturnScreen
        paywallSuccessScreen = nil
    }

    func finishMainPaywallWithPremium() {
        currentScreen = paywallSuccessScreen ?? paywallReturnScreen
        paywallSuccessScreen = nil
    }

    func finishOnboarding(with result: HeritageAnalysisResult, photo: UIImage?) {
        userDefaults.set(true, forKey: onboardingCompletedKey)
        heritageAnalysisResult = result
        if let photo {
            pendingOnboardingScan = PendingOnboardingScan(image: photo, result: result)
        } else {
            pendingOnboardingScan = nil
        }
        currentScreen = .heritagePaywall
    }

    func finishOnboardingPaywallWithoutPremium() {
        pendingOnboardingScan = nil
        currentScreen = .familyTree
    }

    func finishOnboardingPaywallWithPremium() {
        if let pendingOnboardingScan {
            _ = try? ScanHistoryStore().add(
                image: pendingOnboardingScan.image,
                result: pendingOnboardingScan.result
            )
        }
        pendingOnboardingScan = nil
        currentScreen = .familyTree
    }

    private func presentMainPaywall(
        returnTo: AppScreen,
        successScreen: AppScreen? = nil
    ) {
        paywallReturnScreen = returnTo == .paywall ? paywallReturnScreen : returnTo
        paywallSuccessScreen = successScreen
        currentScreen = .paywall
    }
}

private struct PendingOnboardingScan {
    let image: UIImage
    let result: HeritageAnalysisResult
}

struct FamilyTreeDate: Codable, Equatable {
    var month: String
    var day: Int
    var year: Int
}

struct FamilyTreeMember: Identifiable, Codable, Equatable {
    var id: UUID
    var firstName: String
    var lastName: String
    var maidenName: String
    var gender: String
    var birthDate: FamilyTreeDate?
    var deathDate: FamilyTreeDate?
    var placeOfBirth: String
    var placeOfDeath: String
    var relationship: String
    var imageData: Data?
    var parentIDs: [UUID]

    var isFilled: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || imageData != nil
    }

    var displayName: String {
        let name = [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return name.isEmpty ? "Parent" : name
    }

    static func placeholder(id: UUID = UUID(), gender: String = "Female") -> FamilyTreeMember {
        FamilyTreeMember(
            id: id,
            firstName: "",
            lastName: "",
            maidenName: "",
            gender: gender,
            birthDate: nil,
            deathDate: nil,
            placeOfBirth: "",
            placeOfDeath: "",
            relationship: "Parent",
            imageData: nil,
            parentIDs: []
        )
    }
}

struct FamilyTreeState: Codable, Equatable {
    var rootID: UUID
    var members: [FamilyTreeMember]
}

@MainActor
final class FamilyTreeStore: ObservableObject {
    @Published private(set) var state: FamilyTreeState
    @Published var editingMemberID: UUID?

    private let storageKey = "heritage.family-tree.state"

    init(userDefaults: UserDefaults = .standard) {
        if let data = userDefaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(FamilyTreeState.self, from: data) {
            state = decoded
            if let rootIndex = state.members.firstIndex(where: { $0.id == state.rootID }),
               !state.members[rootIndex].isFilled {
                state.members[rootIndex].relationship = "Root"
            }
        } else {
            var root = FamilyTreeMember.placeholder(gender: "Female")
            root.relationship = "Root"
            state = FamilyTreeState(rootID: root.id, members: [root])
        }
    }

    var rootMember: FamilyTreeMember {
        member(for: state.rootID) ?? state.members[0]
    }

    var editingMember: FamilyTreeMember? {
        guard let editingMemberID else {
            return nil
        }

        return member(for: editingMemberID)
    }

    func member(for id: UUID) -> FamilyTreeMember? {
        state.members.first { $0.id == id }
    }

    func beginEditing(_ id: UUID) {
        editingMemberID = id
    }

    func cancelEditing() {
        editingMemberID = nil
    }

    func save(_ member: FamilyTreeMember) {
        if let index = state.members.firstIndex(where: { $0.id == member.id }) {
            state.members[index] = member
        } else {
            state.members.append(member)
        }

        ensureParentPlaceholders(for: member.id)
        editingMemberID = nil
        persist()
    }

    func addParentsIfNeeded(for id: UUID) {
        ensureParentPlaceholders(for: id)
        persist()
    }

    func deleteMemberBranch(_ id: UUID) {
        guard let index = state.members.firstIndex(where: { $0.id == id }) else {
            return
        }

        let selectedMember = state.members[index]
        let relatedParentIDs = parentSubtreeIDs(from: selectedMember.parentIDs)
        state.members.removeAll { relatedParentIDs.contains($0.id) }

        if let replacementIndex = state.members.firstIndex(where: { $0.id == id }) {
            let relationship = state.members[replacementIndex].relationship
            let gender = state.members[replacementIndex].gender
            var placeholder = FamilyTreeMember.placeholder(id: id, gender: gender)
            placeholder.relationship = relationship
            state.members[replacementIndex] = placeholder
        }

        for memberIndex in state.members.indices {
            state.members[memberIndex].parentIDs.removeAll { relatedParentIDs.contains($0) }
        }

        editingMemberID = nil
        persist()
    }

    func maxAncestorDepth(from id: UUID? = nil) -> Int {
        let startID = id ?? state.rootID
        guard let member = member(for: startID), !member.parentIDs.isEmpty else {
            return 0
        }

        return 1 + (member.parentIDs.map { maxAncestorDepth(from: $0) }.max() ?? 0)
    }

    private func ensureParentPlaceholders(for id: UUID) {
        guard let index = state.members.firstIndex(where: { $0.id == id }),
              state.members[index].isFilled,
              state.members[index].parentIDs.isEmpty
        else {
            return
        }

        let father = FamilyTreeMember.placeholder(gender: "Male")
        let mother = FamilyTreeMember.placeholder(gender: "Female")
        state.members.append(father)
        state.members.append(mother)
        state.members[index].parentIDs = [father.id, mother.id]
    }

    private func parentSubtreeIDs(from ids: [UUID]) -> Set<UUID> {
        var collected = Set<UUID>()

        func collect(_ id: UUID) {
            guard collected.insert(id).inserted,
                  let member = member(for: id)
            else {
                return
            }

            member.parentIDs.forEach(collect)
        }

        ids.forEach(collect)
        return collected
    }

    private func persist(userDefaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(state) else {
            return
        }

        userDefaults.set(data, forKey: storageKey)
    }
}
