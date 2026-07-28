import SwiftUI

struct ReportCard: View {
    let subscriptions: [Subscription]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var pageHeight = 316
    @State private var period: ReportPeriod = .month
    @State private var cursor = Date.now
    @State private var dragOffset: CGFloat = 0
    @State private var dragProgress: CGFloat = 0
    @State private var isSettling = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("集計期間", selection: $period) {
                ForEach(ReportPeriod.allCases) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .padding(3)
            .background(.ultraThinMaterial, in: Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .stroke(.white.opacity(0.3), lineWidth: 0.7)
            }
            .accessibilityLabel("レポート期間")

            GeometryReader { proxy in
                let width = proxy.size.width

                HStack(spacing: 0) {
                    ForEach(-1...1, id: \.self) { step in
                        let pageCursor = shiftedCursor(by: step)
                        ReportPage(
                            report: report(at: pageCursor),
                            periodLabel: periodLabel(for: pageCursor),
                            reduceMotion: reduceMotion
                        )
                        .frame(width: width)
                    }
                }
                .offset(x: -width + dragOffset)
                .contentShape(Rectangle())
                .simultaneousGesture(pageDragGesture(pageWidth: width))
            }
            .frame(height: pageHeight)
            .clipped()

            HStack(spacing: 12) {
                Image(systemName: "chevron.left")
                Text("前の\(periodUnit)")
                Spacer()
                LiquidPageIndicator(
                    progress: dragProgress,
                    reduceMotion: reduceMotion
                )
                Spacer()
                Text("次の\(periodUnit)")
                Image(systemName: "chevron.right")
            }
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.78))
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background {
            LiquidGlassCardBackground()
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.72), .white.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.9
                )
        }
        .shadow(color: .blue.opacity(0.22), radius: 22, y: 10)
        .onChange(of: period) {
            dragOffset = 0
            dragProgress = 0
            isSettling = false
        }
        .accessibilityElement(children: .contain)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                settlePage(by: 1, pageWidth: 1)
            case .decrement:
                settlePage(by: -1, pageWidth: 1)
            @unknown default:
                break
            }
        }
    }

    private var periodUnit: String {
        period == .month ? "月" : "年"
    }

    private func report(at date: Date) -> PaymentReport {
        ReportCalculator.report(
            subscriptions: subscriptions,
            period: period,
            cursor: date
        )
    }

    private func shiftedCursor(by value: Int) -> Date {
        ReportCalculator.shifted(cursor, period: period, by: value)
    }

    private func periodLabel(for date: Date) -> String {
        if period == .month {
            return date.formatted(.dateTime.year().month(.wide))
        }
        return date.formatted(.dateTime.year())
    }

    private func pageDragGesture(pageWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard !isSettling,
                      abs(value.translation.width) > abs(value.translation.height) else {
                    return
                }
                dragOffset = max(-pageWidth, min(pageWidth, value.translation.width))
                dragProgress = max(-1, min(1, -value.translation.width / pageWidth))
            }
            .onEnded { value in
                guard !isSettling,
                      abs(value.translation.width) > abs(value.translation.height) else {
                    snapBack()
                    return
                }

                let projected = value.predictedEndTranslation.width
                let threshold = pageWidth * 0.18
                if value.translation.width < -threshold || projected < -pageWidth * 0.42 {
                    settlePage(by: 1, pageWidth: pageWidth)
                } else if value.translation.width > threshold || projected > pageWidth * 0.42 {
                    settlePage(by: -1, pageWidth: pageWidth)
                } else {
                    snapBack()
                }
            }
    }

    private func snapBack() {
        withAnimation(reduceMotion ? nil : .interactiveSpring(response: 0.34, dampingFraction: 0.86)) {
            dragOffset = 0
            dragProgress = 0
        }
    }

    private func settlePage(by value: Int, pageWidth: CGFloat) {
        guard !isSettling else { return }
        isSettling = true

        if reduceMotion {
            cursor = shiftedCursor(by: value)
            dragOffset = 0
            dragProgress = 0
            isSettling = false
            return
        }

        withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.88)) {
            dragOffset = value > 0 ? -pageWidth : pageWidth
            dragProgress = CGFloat(value)
        } completion: {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                cursor = shiftedCursor(by: value)
                dragOffset = 0
                dragProgress = 0
                isSettling = false
            }
        }
    }
}

private struct LiquidGlassCardBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.38, blue: 0.92),
                    Color(red: 0.29, green: 0.20, blue: 0.82),
                    Color(red: 0.05, green: 0.61, blue: 0.88)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(.cyan.opacity(0.52))
                .frame(width: 190, height: 190)
                .blur(radius: 42)
                .offset(x: 130, y: -145)

            Circle()
                .fill(.purple.opacity(0.4))
                .frame(width: 170, height: 170)
                .blur(radius: 46)
                .offset(x: -140, y: 150)

            Rectangle()
                .fill(.ultraThinMaterial)
        }
    }
}

private struct LiquidPageIndicator: View {
    let progress: CGFloat
    let reduceMotion: Bool

    private var clampedProgress: CGFloat {
        max(-1, min(1, progress))
    }

    private var stretch: CGFloat {
        guard !reduceMotion else { return 0 }
        return sin(abs(clampedProgress) * .pi) * 9
    }

    var body: some View {
        ZStack {
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(.white.opacity(0.28))
                        .frame(width: 5, height: 5)
                }
            }

            Capsule(style: .continuous)
                .fill(.white.opacity(0.96))
                .frame(width: 9 + stretch, height: 9)
                .shadow(color: .white.opacity(0.72), radius: 6)
                .offset(x: clampedProgress * 17)
        }
        .frame(width: 67, height: 28)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.72), .white.opacity(0.16)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        }
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        .accessibilityHidden(true)
    }
}

private struct ReportPage: View {
    let report: PaymentReport
    let periodLabel: String
    let reduceMotion: Bool
    @ScaledMetric(relativeTo: .body) private var chartHeight = 178

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(periodLabel)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78))

                Text(report.total, format: .currency(code: "JPY").precision(.fractionLength(0)))
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .contentTransition(.numericText(value: report.total))

                Text("\(report.entries.count)件のサービス")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.58), .white.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            }

            Group {
                if report.entries.isEmpty {
                    ContentUnavailableView(
                        "この期間の支払いはありません",
                        systemImage: "chart.bar"
                    )
                    .foregroundStyle(.white)
                } else {
                    GlassBarChart(
                        entries: report.entries,
                        reduceMotion: reduceMotion
                    )
                }
            }
            .frame(maxWidth: .infinity, minHeight: chartHeight, maxHeight: chartHeight)
            .padding(10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.5), .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

private struct GlassBarChart: View {
    let entries: [ReportEntry]
    let reduceMotion: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsAllEntries = false

    private var maximumAmount: Double {
        max(entries.map(\.amount).max() ?? 1, 1)
    }

    private var visibleEntryCount: Int {
        dynamicTypeSize.isAccessibilitySize ? 1 : 3
    }

    var body: some View {
        VStack(spacing: 6) {
            ForEach(entries.prefix(visibleEntryCount)) { entry in
                GlassBarRow(
                    entry: entry,
                    maximumAmount: maximumAmount
                )
            }

            if entries.count > visibleEntryCount {
                Button {
                    showsAllEntries = true
                } label: {
                    HStack(spacing: 6) {
                        Text("ほか\(entries.count - visibleEntryCount)件")
                        Text("すべて見る")
                            .fontWeight(.semibold)
                        Image(systemName: "chevron.up")
                            .font(.caption2.weight(.bold))
                    }
                    .font(.caption)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(.white.opacity(0.3), lineWidth: 0.7)
                }
                .accessibilityHint("サービス別料金の詳細を開きます")
            } else {
                Spacer(minLength: 0)
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.38), value: entries)
        .sheet(isPresented: $showsAllEntries) {
            ReportBreakdownSheet(entries: entries)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
    }
}

private struct GlassBarRow: View {
    let entry: ReportEntry
    let maximumAmount: Double

    private var fraction: Double {
        max(0.06, min(1, entry.amount / maximumAmount))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text(entry.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer(minLength: 6)

                Text(
                    entry.amount,
                    format: .currency(code: "JPY").precision(.fractionLength(0))
                )
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.92))
                .monospacedDigit()
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(.white.opacity(0.11))
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(.white.opacity(0.2), lineWidth: 0.6)
                        }

                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: entry.colorHex).opacity(0.96),
                                    Color(hex: entry.colorHex).opacity(0.62),
                                    .white.opacity(0.72)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * fraction)
                        .overlay(alignment: .top) {
                            Capsule(style: .continuous)
                                .fill(.white.opacity(0.28))
                                .frame(height: 2)
                                .padding(.horizontal, 3)
                        }
                        .shadow(
                            color: Color(hex: entry.colorHex).opacity(0.42),
                            radius: 6,
                            y: 2
                        )
                }
            }
            .frame(height: 12)
        }
        .frame(height: 36)
        .accessibilityElement(children: .combine)
    }
}

private struct ReportBreakdownSheet: View {
    let entries: [ReportEntry]
    @Environment(\.dismiss) private var dismiss

    private var total: Double {
        entries.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.04, green: 0.34, blue: 0.82),
                        Color(red: 0.25, green: 0.15, blue: 0.68),
                        Color(red: 0.03, green: 0.52, blue: 0.72)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("合計")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.72))
                            Text(
                                total,
                                format: .currency(code: "JPY").precision(.fractionLength(0))
                            )
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(
                            .ultraThinMaterial,
                            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(.white.opacity(0.38), lineWidth: 0.8)
                        }

                        ForEach(entries) { entry in
                            BreakdownRow(
                                entry: entry,
                                total: total
                            )
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("サービス別料金")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
            }
        }
    }
}

private struct BreakdownRow: View {
    let entry: ReportEntry
    let total: Double

    private var ratio: Double {
        guard total > 0 else { return 0 }
        return entry.amount / total
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: entry.colorHex),
                            Color(hex: entry.colorHex).opacity(0.55),
                            .white.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 38, height: 38)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.white.opacity(0.48), lineWidth: 0.7)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(
                    ratio,
                    format: .percent.precision(.fractionLength(1))
                )
                .font(.caption)
                .foregroundStyle(.white.opacity(0.68))
            }

            Spacer(minLength: 8)

            Text(
                entry.amount,
                format: .currency(code: "JPY").precision(.fractionLength(0))
            )
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .monospacedDigit()
        }
        .padding(13)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.28), lineWidth: 0.7)
        }
        .accessibilityElement(children: .combine)
    }
}
