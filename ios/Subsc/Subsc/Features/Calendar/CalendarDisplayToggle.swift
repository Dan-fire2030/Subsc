import SwiftUI

/// マスに金額と件数を出すかどうかを切り替えるボタンです。
///
/// **1つのボタンで2つをまとめて切り替えます。** 別々にすると、
/// 片方だけ出ている中途半端な状態が生まれ、選ぶ手間も増えます。
///
/// iOS 26 では Liquid Glass の面で、iOS 17〜25 では従来の縁付きボタンで描きます。
/// **自前でガラスを作りません。** OSの更新に追従できなくなるためです。
struct CalendarDisplayToggle: View {
    let showsAmounts: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(
                "金額",
                systemImage: showsAmounts ? "yensign.circle.fill" : "yensign.circle"
            )
            .font(BlackCatType.label)
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, BlackCatSpacing.m)
            .padding(.vertical, BlackCatSpacing.xs)
        }
        .foregroundStyle(showsAmounts ? BlackCatPalette.accent : BlackCatPalette.textMuted)
        .modifier(GlassPillModifier())
        // 見た目が小さくても、触れる大きさは指のサイズを守ります。
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel("マスに金額と件数を出す")
        .accessibilityValue(showsAmounts ? "オン" : "オフ")
        .accessibilityAddTraits(showsAmounts ? [.isSelected] : [])
    }
}

/// 丸いガラスの面です。iOS 26 でだけ Liquid Glass を使います。
private struct GlassPillModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: .capsule)
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
                .overlay {
                    Capsule().stroke(BlackCatPalette.border, lineWidth: 0.75)
                }
        }
    }
}
