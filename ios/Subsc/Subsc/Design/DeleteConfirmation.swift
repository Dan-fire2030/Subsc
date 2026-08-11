import SwiftUI

/// 削除の確認を、**押したものの近くに吹き出しで**出します。
///
/// 以前は `confirmationDialog` を使っていましたが、押した場所と関係のない位置に出るため、
/// **どのボタンに対する確認なのかが画面から読み取れませんでした**（2026-08-11に変更）。
///
/// **`presentationCompactAdaptation(.popover)` をここで必ず付けます。**
/// これが無いとiPhoneでは吹き出しがシートへ化けます。呼び出し側ごとに書くと
/// 必ずどこかで忘れるので、修飾子の中に閉じ込めています。
///
/// 削除以外の確認（テーマを既定に戻す、操作の失敗の知らせ）には使いません。
/// あれらは特定のボタンに紐づかない、または画面全体に関わる知らせです。
private struct DeleteConfirmationModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String
    let onDelete: () -> Void

    func body(content: Content) -> some View {
        content.popover(
            isPresented: $isPresented,
            attachmentAnchor: .rect(.bounds),
            arrowEdge: .top
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.headline)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Button("キャンセル", role: .cancel) {
                        isPresented = false
                    }
                    .buttonStyle(.bordered)

                    Button("削除", role: .destructive) {
                        // **先に閉じてから消します。** 閉じる前に対象が消えると、
                        // 吹き出しが自分の元にしていた行を失って残ります。
                        isPresented = false
                        onDelete()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(20)
            .frame(idealWidth: 280)
            .presentationCompactAdaptation(.popover)
        }
    }
}

extension View {
    /// 削除の確認の吹き出しを、この要素を元にして出します。
    ///
    /// - Parameters:
    ///   - isPresented: 出すかどうか
    ///   - title: 見出し。何を消すのかが分かる言葉にします
    ///   - message: 取り消せないことを伝える本文
    ///   - onDelete: 「削除」を選んだときに走る処理
    func deleteConfirmation(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        onDelete: @escaping () -> Void
    ) -> some View {
        modifier(
            DeleteConfirmationModifier(
                isPresented: isPresented,
                title: title,
                message: message,
                onDelete: onDelete
            )
        )
    }
}
