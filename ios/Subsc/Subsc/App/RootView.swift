import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(ThemeStore.self) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Subscription.updatedAt) private var subscriptions: [Subscription]
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

    private var notificationSyncID: String {
        "\(scenePhase == .active):\(notificationFingerprint)"
    }

    var body: some View {
        TabView(selection: $selectedTab) {
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

        let result = await NotificationService.reconcile(subscriptions: subscriptions)
        if result.failed > 0 {
            operationError = "\(result.failed)件の通知を設定できませんでした。通知設定を確認してください。"
        }
    }
}

struct AppLiquidGlassBackground: View {
    @Environment(ThemeStore.self) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)

            LinearGradient(
                colors: [
                    theme.cardBaseColor.opacity(colorScheme == .dark ? 0.13 : 0.055),
                    theme.cardHighlightColor.opacity(colorScheme == .dark ? 0.08 : 0.025),
                    theme.cardAccentColor.opacity(colorScheme == .dark ? 0.1 : 0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(theme.cardAccentColor.opacity(colorScheme == .dark ? 0.1 : 0.065))
                .frame(width: 260, height: 260)
                .blur(radius: 68)
                .offset(x: 150, y: -280)

            Circle()
                .fill(theme.cardHighlightColor.opacity(colorScheme == .dark ? 0.075 : 0.04))
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
            .fill(Color(uiColor: .secondarySystemGroupedBackground))
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

    func glassListRow() -> some View {
        listRowBackground(GlassListRowBackground())
            .listRowSeparatorTint(Color(uiColor: .separator).opacity(0.42))
    }

    func liquidGlassScreen() -> some View {
        modifier(LiquidGlassScreenModifier())
    }
}
