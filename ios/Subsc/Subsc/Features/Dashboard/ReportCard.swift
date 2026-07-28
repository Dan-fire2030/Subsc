import SwiftUI

struct ReportCard: View {
    let subscriptions: [Subscription]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var period: ReportPeriod = .month
    @State private var cursor = Date.now

    private var pages: [ReportPageData] {
        (-1...1).map { step in
            let pageCursor = shiftedCursor(by: step)
            return ReportPageData(
                step: step,
                report: report(at: pageCursor),
                periodLabel: periodLabel(for: pageCursor)
            )
        }
    }

    private var pageHeight: CGFloat {
        if dynamicTypeSize >= .accessibility3 {
            return 660
        }
        return dynamicTypeSize.isAccessibilitySize ? 520 : 264
    }

    var body: some View {
        let reportPages = pages
        let currentReport = reportPages.first { $0.step == 0 }?.report ??
            PaymentReport(total: 0, entries: [])

        VStack(alignment: .leading, spacing: 12) {
            Picker("集計期間", selection: $period) {
                ForEach(ReportPeriod.allCases) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .padding(3)
            .background(.black.opacity(0.12), in: Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .stroke(.white.opacity(0.3), lineWidth: 0.7)
            }
            .accessibilityLabel("レポート期間")

            ReportPager(
                pages: reportPages,
                pageHeight: pageHeight,
                periodUnit: periodUnit,
                reduceMotion: reduceMotion,
                accessibilityValue: accessibilityValue(for: currentReport)
            ) { step in
                cursor = shiftedCursor(by: step)
            }
            .id(period)
        }
        .padding(14)
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
            cursor = .now
        }
    }

    private var periodUnit: String {
        period == .month ? "月" : "年"
    }

    private func accessibilityValue(for report: PaymentReport) -> String {
        let total = report.total.formatted(
            .currency(code: "JPY").precision(.fractionLength(0))
        )
        return "\(periodLabel(for: cursor))、利用コスト\(total)、\(report.entries.count)件"
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

}

private struct ReportPageData: Identifiable, Equatable {
    let step: Int
    let report: PaymentReport
    let periodLabel: String

    var id: Int { step }
}

private struct ReportPager: View {
    let pages: [ReportPageData]
    let pageHeight: CGFloat
    let periodUnit: String
    let reduceMotion: Bool
    let accessibilityValue: String
    let onShift: (Int) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("hasUsedReportPaging") private var hasUsedReportPaging = false
    @State private var selectedStep: Int? = 0
    @State private var feedbackTrigger = 0

    var body: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(pages) { page in
                        ReportPage(
                            report: page.report,
                            periodLabel: page.periodLabel,
                            reduceMotion: reduceMotion
                        )
                        .containerRelativeFrame(.horizontal)
                        .id(page.step)
                        .accessibilityHidden(page.step != 0)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollPosition(id: $selectedStep)
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .frame(height: pageHeight)
            .clipped()
            .onChange(of: selectedStep) {
                completeSwipeIfNeeded()
            }

            HStack(spacing: 12) {
                pageButton(
                    title: "前の\(periodUnit)",
                    systemImage: "chevron.left",
                    shift: -1
                )

                Spacer()

                if dynamicTypeSize.isAccessibilitySize {
                    Image(systemName: "hand.draw")
                        .foregroundStyle(.white.opacity(0.9))
                        .accessibilityHidden(true)
                } else if hasUsedReportPaging {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.white.opacity(0.42))
                        Circle()
                            .fill(.white)
                        Circle()
                            .fill(.white.opacity(0.42))
                    }
                    .frame(width: 42, height: 8)
                    .accessibilityHidden(true)
                } else {
                    Label("左右にスワイプ", systemImage: "hand.draw")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .accessibilityHidden(true)
                }

                Spacer()

                pageButton(
                    title: "次の\(periodUnit)",
                    systemImage: "chevron.right",
                    shift: 1
                )
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("利用コストレポート")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("上下にスワイプして前後の\(periodUnit)へ移動できます")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                shiftPage(by: 1)
            case .decrement:
                shiftPage(by: -1)
            @unknown default:
                break
            }
        }
        .accessibilityAction(named: "前の\(periodUnit)") {
            shiftPage(by: -1)
        }
        .accessibilityAction(named: "次の\(periodUnit)") {
            shiftPage(by: 1)
        }
        .sensoryFeedback(.selection, trigger: feedbackTrigger)
    }

    private func pageButton(
        title: String,
        systemImage: String,
        shift: Int
    ) -> some View {
        Button {
            shiftPage(by: shift)
        } label: {
            HStack(spacing: 5) {
                if shift < 0 {
                    Image(systemName: systemImage)
                }
                if !dynamicTypeSize.isAccessibilitySize {
                    Text(title)
                }
                if shift > 0 {
                    Image(systemName: systemImage)
                }
            }
                .font(.caption.weight(.semibold))
                .frame(minWidth: 44, minHeight: 44)
                .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 0 : 10)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(.black.opacity(0.16), in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .stroke(.white.opacity(0.32), lineWidth: 0.7)
        }
        .accessibilityLabel(title)
    }

    private func completeSwipeIfNeeded() {
        guard let selectedStep, selectedStep != 0 else { return }
        shiftPage(by: selectedStep)
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            self.selectedStep = 0
        }
    }

    private func shiftPage(by value: Int) {
        onShift(value)
        hasUsedReportPaging = true
        feedbackTrigger += 1
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

            LinearGradient(
                colors: [.black.opacity(0.02), .black.opacity(0.16)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

private struct ReportPage: View {
    let report: PaymentReport
    let periodLabel: String
    let reduceMotion: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var chartHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 340 : 130
    }

    var body: some View {
        VStack(alignment: .leading, spacing: dynamicTypeSize.isAccessibilitySize ? 14 : 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(periodLabel)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))

                Text(report.total, format: .currency(code: "JPY").precision(.fractionLength(0)))
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .contentTransition(.numericText(value: report.total))

                Text("\(report.entries.count)件のサービス")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.84))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 14 : 12)
            .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 11 : 8)
            .background(
                .black.opacity(0.16),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
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
                    VStack(spacing: dynamicTypeSize.isAccessibilitySize ? 12 : 8) {
                        Image(systemName: "chart.bar")
                            .font(dynamicTypeSize.isAccessibilitySize ? .title : .title2)
                        Text(
                            dynamicTypeSize.isAccessibilitySize
                                ? "登録はありません"
                                : "この期間の利用データはありません"
                        )
                        .font(
                            dynamicTypeSize.isAccessibilitySize
                                ? .body.weight(.semibold)
                                : .callout.weight(.semibold)
                        )
                        .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("この期間の利用コストはありません")
                } else {
                    GlassBarChart(
                        entries: report.entries,
                        reduceMotion: reduceMotion
                    )
                }
            }
            .frame(maxWidth: .infinity, minHeight: chartHeight, maxHeight: chartHeight)
            .padding(dynamicTypeSize.isAccessibilitySize ? 10 : 8)
            .background(
                .black.opacity(0.14),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
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
        dynamicTypeSize.isAccessibilitySize ? 1 : 2
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
                .background(.black.opacity(0.16), in: Capsule(style: .continuous))
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var fraction: Double {
        max(0.06, min(1, entry.amount / maximumAmount))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                : AnyLayout(HStackLayout(spacing: 8))

            layout {
                Text(entry.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)

                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer(minLength: 6)
                }

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
        .frame(minHeight: 36)
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
