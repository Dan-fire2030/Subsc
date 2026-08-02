import SwiftUI

/// 試算3種を使えるかどうかの判定です。
///
/// **判定をここ1箇所に集約しておくための型です。** 収益化の方針（SPEC 8節）では、
/// リリース3ヶ月後に継続率を見てから、試算3種を買い切りのProへ切り出すかを決めます。
/// そのとき差し替えるのは `isUnlocked` の中身だけで済むようにしてあります。
///
/// **登録・残高・返済予定表の閲覧は恒久的に無料**です。ここで判定するのは試算だけで、
/// あとから無料の機能を制限しないという約束を、型の置き場所でも表しています。
enum LoanSimulationAccess {
    /// 1.0.0 では全機能を無料で提供します。**課金の実装は含めません。**
    static var isUnlocked: Bool { true }

    /// 使えないときに見せる説明です。いまは到達しませんが、判定と対で置いておきます。
    static let lockedDescription = "この試算はProで使えます。"
}

/// 試算画面への入口です。
///
/// **判定を通る場所をこの1つに絞る**ため、入口はすべてこの型を経由させます。
/// 入口ごとに `isUnlocked` を書くと、Proへ切り出すときに書き漏らしが出ます。
struct LoanSimulationLink<Destination: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        if LoanSimulationAccess.isUnlocked {
            NavigationLink {
                destination()
            } label: {
                Label(title, systemImage: systemImage)
            }
        } else {
            LabeledContent {
                Text("Pro")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            } label: {
                Label(title, systemImage: systemImage)
                    .foregroundStyle(.secondary)
            }
            .accessibilityHint(LoanSimulationAccess.lockedDescription)
        }
    }
}
