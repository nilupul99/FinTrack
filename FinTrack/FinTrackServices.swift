import Foundation
import UserNotifications
import SwiftUI

final class NotificationManager {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()

    private init() { }

    func requestAuthorization() async {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            // The app still works when notification authorization is unavailable.
        }
    }

    func scheduleNotification(title: String, body: String, secondsFromNow: TimeInterval) async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(secondsFromNow, 1), repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        try? await center.add(request)
    }
}

struct InsightsService {
    let apiURLString: String

    func fetchInsights() async -> [FinancialInsight] {
        guard let url = URL(string: apiURLString), apiURLString.isEmpty == false else {
            return FinancialInsight.sample
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(InsightsAPIResponse.self, from: data)
            return response.insights.map { item in
                FinancialInsight(
                    title: item.title,
                    message: item.message,
                    systemImage: item.systemImage ?? "sparkles",
                    tint: .blue
                )
            }
        } catch {
            return FinancialInsight.sample
        }
    }
}
