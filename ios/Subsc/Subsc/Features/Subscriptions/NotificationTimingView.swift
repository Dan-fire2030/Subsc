import SwiftUI

/// 更新日の何日前・何時間前に通知するかを選ぶ画面です。`SubscriptionFormView` から遷移します。
struct NotificationTimingView: View {
    @Binding var leadDays: Set<Int>
    @Binding var leadHours: Set<Int>
    let dayOptions: [Int]
    let hourOptions: [Int]
    @Environment(ThemeStore.self) private var theme

    var body: some View {
        List {
            Section("日単位") {
                ForEach(dayOptions, id: \.self) { day in
                    Button {
                        toggle(day, in: &leadDays)
                    } label: {
                        HStack {
                            Text(day == 0 ? "当日" : "\(day)日前")
                                .foregroundStyle(.primary)
                            Spacer()
                            if leadDays.contains(day) {
                                Image(systemName: "checkmark")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(theme.buttonColor)
                            }
                        }
                    }
                }
            }
            .glassListRow()

            Section("時間単位") {
                ForEach(hourOptions, id: \.self) { hour in
                    Button {
                        toggle(hour, in: &leadHours)
                    } label: {
                        HStack {
                            Text("\(hour)時間前")
                                .foregroundStyle(.primary)
                            Spacer()
                            if leadHours.contains(hour) {
                                Image(systemName: "checkmark")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(theme.buttonColor)
                            }
                        }
                    }
                }
            }
            .glassListRow()
        }
        .liquidGlassScreen()
        .navigationTitle("通知タイミング")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggle(_ value: Int, in values: inout Set<Int>) {
        if values.contains(value) {
            values.remove(value)
        } else {
            values.insert(value)
        }
    }
}
