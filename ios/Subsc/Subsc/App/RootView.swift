import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(ThemeStore.self) private var theme
    @Environment(OnboardingStore.self) private var onboarding
    @Environment(LoanNotificationSettings.self) private var loanNotificationSettings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Subscription.updatedAt) private var subscriptions: [Subscription]
    @Query(sort: \Loan.updatedAt) private var loans: [Loan]
    @State private var selectedTab = 0
    @State private var operationError: String?

    private var notificationFingerprint: String {
        subscriptions.map {
            [
                $0.clientID,
                $0.updatedAt.timeIntervalSince1970.description,
                $0.stateRaw,
                $0.notificationsEnabled.description
            ].joined(separator: ":")
        }
        .joined(separator: "|")
    }

    /// 借入の変化も合図に含めます。**含めないと、借入を登録しても返済日の通知が予約されません。**
    /// 費目側が変わるまで再同期が起きないためです。
    private var loanFingerprint: String {
        loans.map {
            [
                $0.clientID,
                $0.updatedAt.timeIntervalSince1970.description,
                $0.isClosed.description
            ].joined(separator: ":")
        }
        .joined(separator: "|")
    }

    /// 通知設定を変えたら予約し直す必要があるため、合図に含めます。
    private var notificationSyncID: String {
        [
            "\(scenePhase == .active)",
            notificationFingerprint,
            loanFingerprint,
            "\(loanNotificationSettings.lead.rawValue)",
            "\(loanNotificationSettings.hour)"
        ].joined(separator: ":")
    }

    var body: some View {
        @Bindable var onboarding = onboarding

        return TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("ホーム", systemImage: "rectangle.grid.1x2.fill")
                }
                .tag(0)

            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape.fill")
                }
                .tag(1)
        }
        .tint(theme.buttonColor)
        .modifier(AdaptiveTabBarModifier())
        // **初回だけ全画面で被せます。** タブの上に出すことで、
        // 見終わった直後に説明された画面がそのまま現れます。
        .fullScreenCover(isPresented: $onboarding.isPresentingTutorial) {
            TutorialView(
                onFinish: { onboarding.markTutorialFinished() },
                onSkip: { onboarding.markTutorialSkipped() }
            )
        }
        .task(id: notificationSyncID) {
            guard scenePhase == .active else { return }
            await reconcileSubscriptions()
        }
        .alert(
            "データを同期できませんでした",
            isPresented: Binding(
                get: { operationError != nil },
                set: { if !$0 { operationError = nil } }
            )
        ) {
            Button("閉じる", role: .cancel) {}
        } message: {
            Text(operationError ?? "")
        }
    }

    private func reconcileSubscriptions() async {
        let didAdvanceRenewal = subscriptions.reduce(false) { changed, subscription in
            subscription.advanceRenewalDateIfNeeded() || changed
        }
        if didAdvanceRenewal {
            do {
                try modelContext.save()
            } catch {
                modelContext.rollback()
                operationError = "更新日の保存に失敗しました。通信状態とiCloudの状態を確認してください。"
            }
        }

        // 返済日を過ぎた回は、何もしなければ予定どおり返済されたものとして進めます。
        // **停止中の借入は繰り延べへ回します。** 止めているあいだに返済済みが積み上がると、
        // 一時停止が無意味になります。
        for loan in loans {
            if loan.isPaused {
                // 予定表を組み直せなくても、他の借入の処理は続けます。
                // 開くたびに呼ばれるので、次の起動でやり直せます。
                _ = try? LoanPaymentStore.deferPastDue(on: loan)
            } else {
                LoanPaymentStore.settlePastDue(on: loan)
            }
        }

        let result = await NotificationService.reconcile(
            subscriptions: subscriptions,
            loans: loans,
            loanLead: loanNotificationSettings.lead,
            loanHour: loanNotificationSettings.hour
        )
        if result.failed > 0 {
            operationError = "\(result.failed)件の通知を設定できませんでした。通知設定を確認してください。"
        } else if result.missing > 0 {
            // **予約できなかったことを黙って見過ごしません（2026-08-09）。**
            // iOSは1つのアプリに64件までしか予約を保持せず、超過分は例外にならずに
            // 捨てられます。実際にこれで「登録した費目の通知が来ない」が起きました。
            operationError = """
                \(result.missing)件の通知を予約できませんでした。\
                iOSが1つのアプリに保持できる通知は64件までです。\
                費目ごとの通知タイミングを減らすか、使っていない費目を停止してください。
                """
        }
    }
}

struct AppLiquidGlassBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    /// 地へうっすら掛ける光の色です。
    ///
    /// **金目で固定します（2026-08-06）。** もとは「カードの色」設定から取っていましたが、
    /// カードに色を持たせる設定そのものを削除したため、選ぶ余地がなくなりました。
    /// 既定値がもともと金目だったので、色を変えていない利用者の見た目は変わりません。
    private var glow: Color { BlackCatPalette.accent }

    var body: some View {
        ZStack {
            // **地は黒猫の墨（ダーク）／白磁（ライト）です。**
            // OS標準のグループ背景より一段深く沈めることで、猫のシルエットと
            // カードの面が浮きます。操作部品のLiquid Glassはこの地の上で成立します。
            BlackCatPalette.background

            LinearGradient(
                colors: [
                    glow.opacity(colorScheme == .dark ? 0.13 : 0.055),
                    glow.opacity(colorScheme == .dark ? 0.08 : 0.025),
                    glow.opacity(colorScheme == .dark ? 0.1 : 0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(glow.opacity(colorScheme == .dark ? 0.1 : 0.065))
                .frame(width: 260, height: 260)
                .blur(radius: 68)
                .offset(x: 150, y: -280)

            Circle()
                .fill(glow.opacity(colorScheme == .dark ? 0.075 : 0.04))
                .frame(width: 290, height: 290)
                .blur(radius: 76)
                .offset(x: -170, y: 220)
        }
        .ignoresSafeArea()
    }
}

struct GlassListRowBackground: View {
    var body: some View {
        Rectangle()
            // 浮いた面です。地との差だけで段差を作り、境界線も影も持ちません。
            .fill(BlackCatPalette.surface)
    }
}

private struct GlassSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    .regular,
                    in: .rect(cornerRadius: cornerRadius)
                )
        } else {
            content
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.62), .white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.75
                        )
                }
                .shadow(color: .black.opacity(0.045), radius: 7, y: 3)
        }
    }
}

private struct AdaptiveTabBarModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .tabBarMinimizeBehavior(.onScrollDown)
        } else {
            content
                .toolbarBackground(.ultraThinMaterial, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
        }
    }
}

private struct LiquidGlassScreenModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .scrollContentBackground(.hidden)
                .background(AppLiquidGlassBackground())
                .scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            content
                .scrollContentBackground(.hidden)
                .background(AppLiquidGlassBackground())
                .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

private struct ProminentGlassButtonModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glassProminent)
        } else {
            content
                .buttonStyle(.borderedProminent)
        }
    }
}

private struct AdaptiveSheetBackgroundModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
        } else {
            content
                .presentationBackground(.ultraThinMaterial)
        }
    }
}

private struct AdaptiveNavigationBarModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
        } else {
            content
                .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

extension View {
    func glassSurface(cornerRadius: CGFloat = 18) -> some View {
        modifier(GlassSurfaceModifier(cornerRadius: cornerRadius))
    }

    func prominentGlassButton() -> some View {
        modifier(ProminentGlassButtonModifier())
    }

    func adaptiveSheetBackground() -> some View {
        modifier(AdaptiveSheetBackgroundModifier())
    }

    func adaptiveNavigationBar() -> some View {
        modifier(AdaptiveNavigationBarModifier())
    }

    /// 一覧の行の見た目です。
    ///
    /// **箱で囲わず、区切り線も引きません（2026-08-06）。** 行を丸い面で囲むと
    /// 1行ごとにカードが並んでいるように見え、線を引くと線が情報として読まれます。
    /// 行の区別は**左端の色の印と余白**が担います。
    func glassListRow() -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    func liquidGlassScreen() -> some View {
        modifier(LiquidGlassScreenModifier())
    }
}
