import SwiftUI

/// ページャが表示する1ページぶんの入力です。`step` は現在の期間からの相対位置（-1／0／+1）。
struct ReportPageData: Identifiable, Equatable {
    let step: Int
    let report: PaymentReport
    let periodLabel: String

    var id: Int { step }
}

/// 前後の期間を横スワイプで見せるページャです。
/// スワイプが終わったらカーソル自体を動かし、選択位置を常に中央（`step == 0`）へ戻すことで、
/// 何回スワイプしてもページを3枚だけ保てるようにしています。
struct ReportPager: View {
    let pages: [ReportPageData]
    let pageHeight: CGFloat
    let periodUnit: String
    let reduceMotion: Bool
    let isViewingCurrentPeriod: Bool
    let accessibilityValue: String
    let onShift: (Int) -> Void
    let onReturnToCurrentPeriod: () -> Void

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

                pagerCenter

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
        .accessibilityAction(named: "今\(periodUnit)へ戻る") {
            returnToCurrentPeriod()
        }
        .sensoryFeedback(.selection, trigger: feedbackTrigger)
    }

    /// 現在の期間から離れているときは復帰ボタンを、初回だけスワイプ案内を出します。
    @ViewBuilder
    private var pagerCenter: some View {
        if !isViewingCurrentPeriod {
            returnToCurrentPeriodButton
        } else if !hasUsedReportPaging {
            if dynamicTypeSize.isAccessibilitySize {
                Image(systemName: "hand.draw")
                    .foregroundStyle(.white.opacity(0.9))
                    .accessibilityHidden(true)
            } else {
                Label("左右にスワイプ", systemImage: "hand.draw")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .accessibilityHidden(true)
            }
        }
    }

    private var returnToCurrentPeriodButton: some View {
        Button {
            returnToCurrentPeriod()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "arrow.uturn.backward")
                if !dynamicTypeSize.isAccessibilitySize {
                    Text("今\(periodUnit)")
                }
            }
            .font(.caption.weight(.semibold))
            .frame(minWidth: 44, minHeight: 44)
            .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 0 : 10)
            .contentShape(.rect)
        }
        .foregroundStyle(.white)
        .modifier(ReportControlButtonModifier())
        .accessibilityLabel("今\(periodUnit)へ戻る")
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
        .foregroundStyle(.white)
        .modifier(ReportControlButtonModifier())
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

    private func returnToCurrentPeriod() {
        onReturnToCurrentPeriod()
        hasUsedReportPaging = true
        feedbackTrigger += 1
    }
}
