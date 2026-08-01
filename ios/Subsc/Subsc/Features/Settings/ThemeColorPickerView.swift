import SwiftUI

/// ボタンとカードで同じ選択UIを使い、テーマの統一感を保ちます。
struct ThemeColorPickerView: View {
    @Environment(ThemeStore.self) private var theme

    private enum ThemeColorTarget {
        case button
        case card

        var navigationTitle: String {
            switch self {
            case .button: "ボタンの色"
            case .card: "カードの色"
            }
        }
    }

    private enum Layout {
        static let presetCircleSize: CGFloat = 24
        static let presetBorderWidth: CGFloat = 0.8
    }

    private let target: ThemeColorTarget

    private init(target: ThemeColorTarget) {
        self.target = target
    }

    /// 呼び出し側が保存先の分岐を持たずに、ボタン用の画面を作れるようにします。
    static func buttonColor() -> ThemeColorPickerView {
        ThemeColorPickerView(target: .button)
    }

    /// 呼び出し側が保存先の分岐を持たずに、カード用の画面を作れるようにします。
    static func cardColor() -> ThemeColorPickerView {
        ThemeColorPickerView(target: .card)
    }

    var body: some View {
        List {
            Section("プレビュー") {
                preview
                    .frame(maxWidth: .infinity)
            }
            .glassListRow()

            Section("プリセット") {
                ForEach(ThemeColorPreset.allCases, id: \.self) { preset in
                    Button {
                        selectedHex = preset.rawValue
                    } label: {
                        HStack {
                            Circle()
                                .fill(ColorHex.color(from: preset.rawValue))
                                .frame(
                                    width: Layout.presetCircleSize,
                                    height: Layout.presetCircleSize
                                )
                                .overlay {
                                    Circle()
                                        .stroke(
                                            .primary.opacity(0.18),
                                            lineWidth: Layout.presetBorderWidth
                                        )
                                }
                                .accessibilityHidden(true)
                            Text(preset.title)
                                .foregroundStyle(.primary)
                            Spacer()
                            if ThemeColorPreset.preset(for: selectedHex) == preset {
                                Image(systemName: "checkmark")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(theme.buttonColor)
                                    .accessibilityHidden(true)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .accessibilityAddTraits(
                        ThemeColorPreset.preset(for: selectedHex) == preset ? .isSelected : []
                    )
                }
            }
            .glassListRow()

            Section("その他の色") {
                ColorPicker("自由に色を選ぶ", selection: customColor, supportsOpacity: false)
            }
            .glassListRow()
        }
        .liquidGlassScreen()
        .navigationTitle(target.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var preview: some View {
        switch target {
        case .button:
            ButtonThemePreview(color: theme.buttonColor)
        case .card:
            CardThemePreview(colors: theme.cardGradientColors)
        }
    }

    /// `ColorPicker`が扱う`Color`と、保存用の16進文字列を選択対象ごとに変換します。
    private var customColor: Binding<Color> {
        Binding(
            get: { ColorHex.color(from: selectedHex) },
            set: { selectedHex = ColorHex.string(from: $0) }
        )
    }

    /// カード色は利用者が選んだ値をそのまま保存し、表示時だけ補正します。
    private var selectedHex: String {
        get {
            switch target {
            case .button: theme.buttonHex
            case .card: theme.cardHex
            }
        }
        nonmutating set {
            switch target {
            case .button: theme.buttonHex = newValue
            case .card: theme.cardHex = newValue
            }
        }
    }
}

private struct CardThemePreview: View {
    private enum Layout {
        static let height: CGFloat = 120
        static let cornerRadius: CGFloat = 24
        static let padding: CGFloat = 18
    }

    let colors: [Color]

    var body: some View {
        ZStack(alignment: .leading) {
            LinearGradient(
                colors: colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("2026年8月")
                    .font(.subheadline.weight(.semibold))
                Text("¥12,340")
                    .font(.title.bold())
            }
            .foregroundStyle(.white)
            .padding(Layout.padding)
        }
        .frame(height: Layout.height)
        .clipShape(
            RoundedRectangle(
                cornerRadius: Layout.cornerRadius,
                style: .continuous
            )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("カード色のプレビュー")
    }
}

private struct ButtonThemePreview: View {
    private enum Layout {
        static let height: CGFloat = 120
        static let padding: CGFloat = 18
        static let contentSpacing: CGFloat = 18
        static let tabItemSpacing: CGFloat = 24
    }

    let color: Color

    var body: some View {
        VStack(spacing: Layout.contentSpacing) {
            Button("サンプルボタン") {}
                .buttonStyle(.borderedProminent)
                .tint(color)

            HStack(spacing: Layout.tabItemSpacing) {
                Label("ホーム", systemImage: "house.fill")
                    .foregroundStyle(color)
                Label("一覧", systemImage: "list.bullet")
                    .foregroundStyle(.secondary)
                Label("設定", systemImage: "gearshape.fill")
                    .foregroundStyle(color)
            }
            .font(.caption)
            .labelStyle(.titleAndIcon)
        }
        .padding(Layout.padding)
        .frame(maxWidth: .infinity, minHeight: Layout.height)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("ボタン色のプレビュー")
    }
}
