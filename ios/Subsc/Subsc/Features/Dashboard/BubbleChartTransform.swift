import SwiftUI

/// バブルの拡大率と平行移動を、画面から外れない範囲へ収めます。
///
/// **ビューから切り離してあります。** 倍率と位置の境目は指の動きで決まるため、
/// シミュレーターの合成タッチでは確かめられません（`.spec/KNOWLEDGE.md`）。
/// 値の計算だけでも単体で押さえられるようにしています。
enum BubbleChartTransform {
    static let minimumScale: CGFloat = 1
    static let maximumScale: CGFloat = 4

    static func clampedScale(_ proposedScale: CGFloat) -> CGFloat {
        min(maximumScale, max(minimumScale, proposedScale))
    }

    /// 等倍では必ず中央へ戻し、拡大中も全体が画面外へ流れ切らない範囲に留めます。
    static func clampedOffset(_ proposedOffset: CGSize, in size: CGSize, scale: CGFloat) -> CGSize {
        guard scale > minimumScale else { return .zero }
        let maximumX = max(0, size.width * (scale - minimumScale) / 2)
        let maximumY = max(0, size.height * (scale - minimumScale) / 2)
        return CGSize(
            width: min(maximumX, max(-maximumX, proposedOffset.width)),
            height: min(maximumY, max(-maximumY, proposedOffset.height))
        )
    }
}
