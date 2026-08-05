import SwiftUI

/// ページャが表示する1ページぶんの入力です。`step` は基準の期間からの相対位置。
struct ReportPageData: Identifiable, Equatable {
    let step: Int
    let report: PaymentReport
    let periodLabel: String

    var id: Int { step }
}

enum ReportPagerConfiguration {
    /// 基準の期間から前後に用意する期間の数です。
    ///
    /// 慣性スクロールは「指を離したあとに滑った先」へ吸着するため、
    /// 滑る余地となるページをあらかじめ並べておく必要があります。
    /// 3枚しか無いと1枚めくった時点で行き止まりになり、勢いが打ち消されます。
    static let stepReach = 60

    static let stepRange = -stepReach...stepReach
}

/// 前後の期間を横スワイプで見せるページャです。
///
/// 弾いた勢いのぶんだけ滑って、いちばん近い期間に吸着します（慣性スライド）。
/// そのため `.paging`（1ページずつ確定）ではなく `.viewAligned` を使います。
///
/// **スクロール位置はこの型の内側に閉じ込めています。** 位置を親に持たせると、
/// 慣性で流れている最中にページが通過するたびにカード全体が作り直され、
/// 減速と吸着が中断されてページの途中で止まってしまいます。
/// ページの中身は `makePage` から都度受け取るので、`LazyHStack` が実際に必要とした
/// ぶんだけしか集計が走りません。
struct ReportPager: View {
    let makePage: (Int) -> ReportPageData
    let pageHeight: CGFloat
    let periodUnit: String
    let reduceMotion: Bool
    let costTypeFilter: CostTypeFilter
    let period: ReportPeriod
    /// 相棒の黒猫です。今の期間のページ（`step == 0`）にだけ渡します。
    let catMood: CatMood
    let accessibilityValue: (ReportPageData) -> String
    let onReturnToCurrentPeriod: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("hasUsedReportPaging") private var hasUsedReportPaging = false
    @State private var selectedStep: Int? = 0
    @State private var feedbackTrigger = 0
    /// グラフを拡大して見ているあいだ真になります。真のあいだページ送りを止めます。
    ///
    /// **ジェスチャーの優先度では解決できません。** 横スクロールが内部で使うパン認識器は
    /// SwiftUIのジェスチャーより先にタッチを掴むため、`highPriorityGesture` にしても
    /// グラフ側のドラッグは指を離すまで解決されず、そのままページが送られてしまいます。
    /// スクロール自体を止めれば競合が消え、ドラッグはグラフだけが受け取ります。
    @State private var blocksPaging = false

    private var currentStep: Int { selectedStep ?? 0 }

    /// `step == 0` は基準の期間そのものなので、現在地の判定は位置だけで決まります。
    private var isViewingCurrentPeriod: Bool { currentStep == 0 }

    var body: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(ReportPagerConfiguration.stepRange, id: \.self) { step in
                        let page = makePage(step)
                        ReportPage(
                            report: page.report,
                            periodLabel: page.periodLabel,
                            reduceMotion: reduceMotion,
                            costTypeFilter: costTypeFilter,
                            period: period,
                            catMood: step == 0 ? catMood : nil,
                            blocksPaging: $blocksPaging
                        )
                        .containerRelativeFrame(.horizontal)
                        .id(step)
                        .accessibilityHidden(step != currentStep)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollPosition(id: $selectedStep)
            // limitBehavior の既定（.automatic）は1回のスワイプを1ページに制限してしまい、
            // 勢いよく弾いても隣で止まる。慣性を活かすため制限を外します。
            .scrollTargetBehavior(.viewAligned(limitBehavior: .never))
            .scrollDisabled(blocksPaging)
            .scrollIndicators(.hidden)
            // 期間の単位や絞り込みが変わるとグラフは作り直されます。
            // 止めたままになる事故を防ぐため、ここで必ず解除します。
            .onChange(of: period) { blocksPaging = false }
            .onChange(of: costTypeFilter) { blocksPaging = false }
            .frame(height: pageHeight)
            .clipped()
            .onChange(of: currentStep) {
                // 慣性で流れている最中に状態を書き換えるとスクロールが途切れるため、
                // 案内の非表示だけを、まだ消していないときに限って行います。
                if !hasUsedReportPaging {
                    hasUsedReportPaging = true
                }
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
        .accessibilityValue(accessibilityValue(makePage(currentStep)))
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
                    .foregroundStyle(BlackCatPalette.textMuted)
                    .accessibilityHidden(true)
            } else {
                Label("左右にスワイプ", systemImage: "hand.draw")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(BlackCatPalette.textMuted)
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
        .foregroundStyle(BlackCatPalette.text)
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
        .foregroundStyle(BlackCatPalette.text)
        .modifier(ReportControlButtonModifier())
        .accessibilityLabel(title)
        .disabled(!canShift(by: shift))
    }

    private func canShift(by value: Int) -> Bool {
        ReportPagerConfiguration.stepRange.contains(currentStep + value)
    }

    /// ボタンとVoiceOverからのページ送りです。スワイプと同じ位置へアニメーションで寄せます。
    private func shiftPage(by value: Int) {
        guard canShift(by: value) else { return }
        scroll(to: currentStep + value)
    }

    private func returnToCurrentPeriod() {
        onReturnToCurrentPeriod()
        scroll(to: 0)
    }

    /// ボタン・VoiceOver からの移動だけがここを通ります。
    /// スワイプはスクロールビュー自身が処理するので、触覚は指の操作と競合しません。
    private func scroll(to step: Int) {
        guard step != currentStep else { return }
        hasUsedReportPaging = true
        feedbackTrigger += 1
        if reduceMotion {
            selectedStep = step
        } else {
            withAnimation(.snappy) {
                selectedStep = step
            }
        }
    }
}
