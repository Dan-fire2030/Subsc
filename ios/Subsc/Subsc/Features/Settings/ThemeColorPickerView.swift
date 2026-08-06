import SwiftUI

/// ボタンの色を選ぶ画面です。
///
/// **カードの色を選ぶ用途は削除しました（2026-08-06）。**
/// もともと選択対象で分岐する作りでしたが、対象が1つになったので分岐を畳んでいます。
struct ThemeColorPickerView: View {
    @Environment(ThemeStore.self) private var theme

    private enum Layout {
        static let presetCircleSize: CGFloat = 24
        static let presetBorderWidth: CGFloat = 0.8
    }

    /// 呼び出し側の記述を変えずに済むよう、名前付きの作り方は残しています。
    static func buttonColor() -> ThemeColorPickerView {
        ThemeColorPickerView()
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
                                    .foregroundStyle(ThemeStore.fixedButtonColor)
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
        .navigationTitle("ボタンの色")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var preview: some View {
        ButtonThemePreview(color: theme.buttonColor)
    }

    /// `ColorPicker`が扱う`Color`と、保存用の16進文字列を変換します。
    private var customColor: Binding<Color> {
        Binding(
            get: { ColorHex.color(from: selectedHex) },
            set: { selectedHex = ColorHex.string(from: $0) }
        )
    }

    /// 利用者が選んだ値をそのまま保存し、表示時だけ補正します。
    private var selectedHex: String {
        get { theme.buttonHex }
        nonmutating set { theme.buttonHex = newValue }
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
