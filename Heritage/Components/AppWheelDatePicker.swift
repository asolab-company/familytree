import SwiftUI

struct AppWheelDatePicker: View {
    @Binding var month: String
    @Binding var day: Int
    @Binding var year: Int

    var months: [String] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    var days: [Int] = Array(1...31)
    var years: [Int] = Array(1900...Calendar.current.component(.year, from: Date()))
    var onInteractionChanged: (Bool) -> Void = { _ in }

    var body: some View {
        ZStack {
            VStack(spacing: AppWheelPickerMetrics.rowHeight - 5) {
                AppWheelDividerLine()
                AppWheelDividerLine()
            }
            .frame(height: AppWheelPickerMetrics.rowHeight)
            .frame(maxWidth: .infinity)

            HStack(spacing: 8) {
                AppWheelScrollColumn(selection: $month, values: months, width: 86, onInteractionChanged: onInteractionChanged) { $0 }
                AppWheelScrollColumn(selection: $day, values: days, width: 62, onInteractionChanged: onInteractionChanged) { "\($0)" }
                AppWheelScrollColumn(selection: $year, values: years, width: 92, onInteractionChanged: onInteractionChanged) { "\($0)" }
            }
            .frame(height: AppWheelPickerMetrics.height)
        }
        .frame(height: AppWheelPickerMetrics.height)
    }
}

private enum AppWheelPickerMetrics {
    static let height: CGFloat = 142
    static let rowHeight: CGFloat = 34
}

private struct AppWheelScrollColumn<Value: Hashable>: View {
    @Binding var selection: Value
    let values: [Value]
    let width: CGFloat
    let onInteractionChanged: (Bool) -> Void
    let title: (Value) -> String

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            ForEach(Array(values.enumerated()), id: \.element) { index, value in
                let offset = offset(for: index)

                Button {
                    select(value)
                } label: {
                    Text(title(value))
                        .font(font(for: offset))
                        .foregroundColor(color(for: value))
                        .tracking(0.7)
                        .frame(width: width, height: AppWheelPickerMetrics.rowHeight)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .offset(y: offset)
                .opacity(opacity(for: offset))
                .allowsHitTesting(abs(offset) <= AppWheelPickerMetrics.height / 2)
            }
        }
        .frame(width: width, height: AppWheelPickerMetrics.height)
        .clipped()
        .contentShape(Rectangle())
        .highPriorityGesture(
            DragGesture(minimumDistance: 3)
                .onChanged { _ in
                    onInteractionChanged(true)
                }
                .onChanged { value in
                    dragOffset = limitedDragOffset(value.translation.height)
                }
                .onEnded { value in
                    settleDrag(dampedTranslation(for: value))
                    onInteractionChanged(false)
                }
        )
    }

    private var selectedIndex: Int {
        values.firstIndex(of: selection) ?? values.startIndex
    }

    private func offset(for index: Int) -> CGFloat {
        CGFloat(index - selectedIndex) * AppWheelPickerMetrics.rowHeight + dragOffset
    }

    private func font(for offset: CGFloat) -> Font {
        abs(offset) < 1 ? AppTypography.regular(23) : AppTypography.regular(21)
    }

    private func opacity(for offset: CGFloat) -> Double {
        let visibleDistance = AppWheelPickerMetrics.height / 2
        let normalized = min(abs(offset) / visibleDistance, 1)
        return Double(1 - normalized * 0.7)
    }

    private func color(for value: Value) -> Color {
        value == selection ? AppColors.gold : AppColors.muted
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

        let delta = Int(round(-predictedTranslation / AppWheelPickerMetrics.rowHeight))
        let lastIndex = values.index(before: values.endIndex)
        let nextIndex = min(max(selectedIndex + delta, values.startIndex), lastIndex)

        guard values.indices.contains(nextIndex) else {
            return
        }

        withAnimation(.easeOut(duration: 0.2)) {
            selection = values[nextIndex]
            dragOffset = 0
        }
    }

    private func dampedTranslation(for value: DragGesture.Value) -> CGFloat {
        let velocityProjection = value.predictedEndTranslation.height - value.translation.height
        return value.translation.height + velocityProjection * 0.22
    }

    private func limitedDragOffset(_ offset: CGFloat) -> CGFloat {
        guard !values.isEmpty else {
            return 0
        }

        let minOffset = -CGFloat(values.index(before: values.endIndex) - selectedIndex) * AppWheelPickerMetrics.rowHeight
        let maxOffset = CGFloat(selectedIndex) * AppWheelPickerMetrics.rowHeight

        return min(max(offset, minOffset), maxOffset)
    }
}

private struct AppWheelDividerLine: View {
    var body: some View {
        Rectangle()
            .fill(Color(hex: 0x7B705E).opacity(0.7))
            .frame(maxWidth: .infinity, maxHeight: 1)
    }
}
