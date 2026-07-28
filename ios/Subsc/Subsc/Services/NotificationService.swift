import Foundation
import UserNotifications

@MainActor
enum NotificationService {
    private static let identifierPrefix = "subsc-"
    private static let maximumPendingRequests = 64
    private static let renewalCyclesPerSubscription = 12

    struct SyncResult: Equatable {
        let scheduled: Int
        let failed: Int
    }

    private struct Candidate {
        let identifier: String
        let date: Date
        let title: String
        let body: String
    }

    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    static func reschedule(for subscription: Subscription) async {
        await cancel(clientID: subscription.clientID)

        guard subscription.notificationsEnabled, subscription.state == .active else {
            return
        }
        let candidates = notificationCandidates(for: subscription, now: .now)
        _ = await add(candidates: Array(candidates.prefix(maximumPendingRequests)))
    }

    static func reconcile(
        subscriptions: [Subscription],
        now: Date = .now
    ) async -> SyncResult {
        guard !Task.isCancelled else {
            return SyncResult(scheduled: 0, failed: 0)
        }
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        guard !Task.isCancelled else {
            return SyncResult(scheduled: 0, failed: 0)
        }
        let identifiers = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        let candidates = subscriptions
            .filter { $0.notificationsEnabled && $0.state == .active }
            .flatMap { notificationCandidates(for: $0, now: now) }
            .sorted { $0.date < $1.date }

        return await add(candidates: Array(candidates.prefix(maximumPendingRequests)))
    }

    static func cancel(clientID: String) async {
        let center = UNUserNotificationCenter.current()
        let prefix = "\(identifierPrefix)\(clientID)-"
        let pending = await center.pendingNotificationRequests()
        let identifiers = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private static func notificationCandidates(
        for subscription: Subscription,
        now: Date
    ) -> [Candidate] {
        let calendar = Calendar.current
        let renewalDates = subscription.upcomingRenewalDates(
            onOrAfter: now,
            limit: renewalCyclesPerSubscription,
            calendar: calendar
        )

        return renewalDates.flatMap { renewalDate -> [Candidate] in
            var targetComponents = calendar.dateComponents(
                [.year, .month, .day],
                from: renewalDate
            )
            targetComponents.hour = subscription.notificationHour
            targetComponents.minute = subscription.notificationMinute
            guard let targetDate = calendar.date(from: targetComponents) else { return [] }

            let cycleKey = targetDate.formatted(
                .iso8601.year().month().day().time(includingFractionalSeconds: false)
            )
            let offsets: [(String, Date)] =
                subscription.leadDays.compactMap { day in
                    calendar.date(byAdding: .day, value: -day, to: targetDate)
                        .map { ("day-\(day)", $0) }
                } +
                subscription.leadHours.compactMap { hour in
                    calendar.date(byAdding: .hour, value: -hour, to: targetDate)
                        .map { ("hour-\(hour)", $0) }
                }

            return offsets.compactMap { suffix, date in
                guard date > now else { return nil }
                return Candidate(
                    identifier: "\(identifierPrefix)\(subscription.clientID)-\(cycleKey)-\(suffix)",
                    date: date,
                    title: "\(subscription.name)の更新予定",
                    body: "\(targetDate.formatted(date: .abbreviated, time: .shortened))に更新されます。"
                )
            }
        }
    }

    private static func add(candidates: [Candidate]) async -> SyncResult {
        let center = UNUserNotificationCenter.current()
        var scheduled = 0
        var failed = 0

        for candidate in candidates {
            guard !Task.isCancelled else { break }
            let content = UNMutableNotificationContent()
            content.title = candidate.title
            content.body = candidate.body
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: candidate.date
                ),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: candidate.identifier,
                content: content,
                trigger: trigger
            )
            do {
                try await center.add(request)
                scheduled += 1
            } catch {
                failed += 1
            }
        }
        return SyncResult(scheduled: scheduled, failed: failed)
    }
}
