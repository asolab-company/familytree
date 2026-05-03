import SwiftUI
import UIKit

struct FamilyTreeView: View {
    @Binding var selectedScreen: AppScreen
    @ObservedObject var familyTreeStore: FamilyTreeStore
    @State private var selectedActionMemberID: UUID?

    var body: some View {
        MainTabShell(
            selectedScreen: $selectedScreen,
            selectedTab: .familyTree,
            title: "Family Tree",
            subtitle: "Your story begins with family",
            backgroundAssetName: DesignAsset.FamilyTree.backgroundMask
        ) {
            FamilyTreeCanvas(
                store: familyTreeStore,
                selectedActionMemberID: $selectedActionMemberID,
                nodeAction: handleNodeTap,
                editAction: editMember,
                deleteAction: deleteMember
            )
        }
    }

    private func handleNodeTap(_ member: FamilyTreeMember) {
        if member.isFilled {
            familyTreeStore.addParentsIfNeeded(for: member.id)
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedActionMemberID = selectedActionMemberID == member.id ? nil : member.id
            }
        } else {
            familyTreeStore.beginEditing(member.id)
            selectedScreen = .addFamilyMember
        }
    }

    private func editMember(_ member: FamilyTreeMember) {
        selectedActionMemberID = nil
        familyTreeStore.beginEditing(member.id)
        selectedScreen = .addFamilyMember
    }

    private func deleteMember(_ member: FamilyTreeMember) {
        withAnimation(.easeInOut(duration: 0.2)) {
            familyTreeStore.deleteMemberBranch(member.id)
            selectedActionMemberID = nil
        }
    }
}

private struct FamilyTreeCanvas: View {
    @ObservedObject var store: FamilyTreeStore
    @Binding var selectedActionMemberID: UUID?
    let nodeAction: (FamilyTreeMember) -> Void
    let editAction: (FamilyTreeMember) -> Void
    let deleteAction: (FamilyTreeMember) -> Void

    private let nodeSize = CGSize(width: 104, height: 132)
    private let verticalSpacing: CGFloat = 178

    var body: some View {
        let maxDepth = max(store.maxAncestorDepth(), 1)
        let canvasWidth = max(AppMetrics.designWidth, CGFloat(1 << maxDepth) * 164)
        let rootY = max(CGFloat(maxDepth) * verticalSpacing + 220, 392)
        let canvasHeight = max(AppMetrics.designHeight, rootY + 230)
        let layout = FamilyTreeLayout(
            store: store,
            rootID: store.state.rootID,
            maxDepth: maxDepth,
            rootX: canvasWidth / 2,
            rootY: rootY,
            verticalSpacing: verticalSpacing
        )

        ScrollViewReader { proxy in
            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    FamilyTreeConnectionLines(layout: layout)

                    ForEach(layout.nodes) { node in
                        if let member = store.member(for: node.memberID) {
                            FamilyProfileNode(member: member) {
                                nodeAction(member)
                            }
                            .frame(width: nodeSize.width, height: nodeSize.height, alignment: .topLeading)
                            .position(x: node.position.x, y: node.position.y)
                            .id(member.id)
                        }
                    }

                    if let selectedActionMemberID,
                       let member = store.member(for: selectedActionMemberID),
                       member.isFilled,
                       let node = layout.nodes.first(where: { $0.memberID == selectedActionMemberID }) {
                        FamilyTreeEditPanel(
                            editAction: { editAction(member) },
                            deleteAction: { deleteAction(member) }
                        )
                        .position(x: node.position.x + 78, y: node.position.y)
                        .transition(.opacity.combined(with: .scale(scale: 0.94)))
                    }
                }
                .frame(width: canvasWidth, height: canvasHeight)
            }
            .frame(width: AppMetrics.designWidth, height: AppMetrics.designHeight)
            .onAppear {
                proxy.scrollTo(store.state.rootID, anchor: .center)
            }
            .onChange(of: store.state.members) { _, _ in
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(store.state.rootID, anchor: .center)
                }
            }
        }
    }
}

private struct FamilyTreeLayout {
    let nodes: [FamilyTreePositionedNode]
    let connections: [FamilyTreeConnection]

    init(
        store: FamilyTreeStore,
        rootID: UUID,
        maxDepth: Int,
        rootX: CGFloat,
        rootY: CGFloat,
        verticalSpacing: CGFloat
    ) {
        var nodes: [FamilyTreePositionedNode] = []
        var connections: [FamilyTreeConnection] = []

        func walk(id: UUID, x: CGFloat, y: CGFloat, generation: Int) {
            nodes.append(FamilyTreePositionedNode(memberID: id, position: CGPoint(x: x, y: y)))

            guard let member = store.member(for: id), member.parentIDs.count == 2 else {
                return
            }

            let nextGeneration = generation + 1
            let offsetPower = max(maxDepth - nextGeneration, 0)
            let horizontalOffset = max(CGFloat(1 << offsetPower) * 82, 98)
            let parentY = y - verticalSpacing

            let leftParent = member.parentIDs[0]
            let rightParent = member.parentIDs[1]
            let leftPoint = CGPoint(x: x - horizontalOffset, y: parentY)
            let rightPoint = CGPoint(x: x + horizontalOffset, y: parentY)

            connections.append(
                FamilyTreeConnection(
                    child: CGPoint(x: x, y: y),
                    leftParent: leftPoint,
                    rightParent: rightPoint
                )
            )

            walk(id: leftParent, x: leftPoint.x, y: leftPoint.y, generation: nextGeneration)
            walk(id: rightParent, x: rightPoint.x, y: rightPoint.y, generation: nextGeneration)
        }

        walk(id: rootID, x: rootX, y: rootY, generation: 0)
        self.nodes = nodes
        self.connections = connections
    }
}

private struct FamilyTreePositionedNode: Identifiable {
    var id: UUID { memberID }
    let memberID: UUID
    let position: CGPoint
}

private struct FamilyTreeConnection: Identifiable {
    let id = UUID()
    let child: CGPoint
    let leftParent: CGPoint
    let rightParent: CGPoint
}

private struct FamilyTreeConnectionLines: View {
    let layout: FamilyTreeLayout

    var body: some View {
        Canvas { context, _ in
            var path = Path()

            for connection in layout.connections {
                let parentCenterY = connection.leftParent.y + 44
                let childTopY = connection.child.y - 66

                path.move(to: CGPoint(x: connection.leftParent.x, y: parentCenterY))
                path.addLine(to: CGPoint(x: connection.rightParent.x, y: parentCenterY))

                path.move(to: CGPoint(x: connection.child.x, y: parentCenterY))
                path.addLine(to: CGPoint(x: connection.child.x, y: childTopY))
            }

            context.stroke(path, with: .color(AppColors.gold.opacity(0.82)), lineWidth: 1)
        }
    }
}

private struct FamilyProfileNode: View {
    let member: FamilyTreeMember
    let action: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Button(action: action) {
                FamilyProfileAvatar(member: member)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .offset(x: 8, y: 0)

            Button(action: action) {
                Image(DesignAsset.FamilyTree.add)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .offset(x: 68, y: 60)

            VStack(spacing: 2) {
                Text(displayName)
                    .font(AppTypography.regular(16))
                    .foregroundColor(AppColors.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if let subtitle {
                    Text(subtitle)
                        .font(AppTypography.regular(14))
                        .foregroundColor(AppColors.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(width: 104)
            .offset(x: 0, y: 92)
        }
    }

    private var displayName: String {
        if !member.isFilled {
            return member.relationship == "Root" ? "Me" : "Parent"
        }

        return member.displayName
    }

    private var subtitle: String? {
        guard member.isFilled, let birthYear = member.birthDate?.year else {
            return nil
        }

        if let deathYear = member.deathDate?.year {
            return "\(birthYear) - \(deathYear)"
        }

        return "\(birthYear)"
    }
}

private struct FamilyTreeEditPanel: View {
    let editAction: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            FamilyTreeEditPanelButton(
                assetName: DesignAsset.FamilyTree.edit,
                action: editAction
            )

            FamilyTreeEditPanelButton(
                assetName: DesignAsset.FamilyTree.delete,
                action: deleteAction
            )
        }
        .padding(.vertical, 4)
        .frame(width: 48, height: 96)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(AppColors.black.opacity(0.44))
        )
    }
}

private struct FamilyTreeEditPanelButton: View {
    let assetName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
             

                Image(assetName)
                    .resizable()
                    .scaledToFit()
               
            }
            .frame(width: 40, height: 40)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

private struct FamilyProfileAvatar: View {
    let member: FamilyTreeMember

    var body: some View {
        ZStack {
            Circle()
                .fill(AppColors.glass)
                .overlay(Circle().stroke(AppColors.gold, lineWidth: 1))
                .shadow(color: AppColors.black.opacity(0.7), radius: 8, x: 0, y: 0)

            if let imageData = member.imageData,
               let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 88, height: 88)
                    .clipShape(Circle())
            } else {
                Image(DesignAsset.FamilyTree.profile)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
            }
        }
        .frame(width: 88, height: 88)
    }
}

#Preview {
    FamilyTreeView(
        selectedScreen: .constant(.familyTree),
        familyTreeStore: FamilyTreeStore()
    )
    .environmentObject(StoreKitPremiumStore())
}
