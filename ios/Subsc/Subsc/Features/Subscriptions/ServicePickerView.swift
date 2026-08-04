import SwiftUI

/// よく使うサービスから1件選んで、費目のフォームへ流し込むための一覧です。
///
/// **選んだ時点では保存しません。** フォームへ値を入れるだけで、金額や更新日は
/// 利用者が入れてから保存します。名前も色も、あとから自由に直せます。
struct ServicePickerView: View {
    /// 選ばれたサービスを親へ返します。
    let onSelect: (CatalogService) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var sections: [CatalogSection] {
        ServiceCatalog.sections(from: ServiceCatalog.search(query))
    }

    var body: some View {
        NavigationStack {
            List {
                if sections.isEmpty {
                    // 検索に合わなくても手入力で追加できることを、ここで伝えます。
                    ContentUnavailableView {
                        Label("見つかりませんでした", systemImage: "magnifyingglass")
                    } description: {
                        Text("一覧に無いサービスは、閉じて費目名を直接入力してください。")
                    }
                } else {
                    ForEach(sections) { section in
                        Section(section.category) {
                            ForEach(section.services) { service in
                                row(for: service)
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "サービス名で探す")
            .navigationTitle("サービスから選ぶ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
    }

    private func row(for service: CatalogService) -> some View {
        Button {
            onSelect(service)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                initialTile(for: service)
                VStack(alignment: .leading, spacing: 2) {
                    Text(service.name)
                        .foregroundStyle(.primary)
                    Text(service.costType.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        // **既定のボタン色を使いません。** サービス名が青字になり、リンクに見えます。
        .buttonStyle(.plain)
        .accessibilityIdentifier("service-catalog-row-\(service.name)")
    }

    /// ロゴの代わりに頭文字を出します。**商標の画像は同梱しません。**
    /// 一覧行（`SubscriptionRow`）と同じ見せ方なので、選んだあとの印象も揃います。
    private func initialTile(for service: CatalogService) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(ColorHex.color(from: service.colorHex))
            .frame(width: 32, height: 32)
            .overlay {
                Text(String(service.name.prefix(1)))
                    .font(.caption.weight(.bold))
                    // 黄色系のブランド色では白が読めないため、明度で黒へ切り替えます。
                    .foregroundStyle(
                        ColorHex.prefersDarkText(on: service.colorHex) ? .black : .white
                    )
            }
            .accessibilityHidden(true)
    }
}
