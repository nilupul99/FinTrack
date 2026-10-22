import Foundation
import UserNotifications
import SwiftUI
import CoreML
import CoreData

final class NotificationManager {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()
    private let presentationDelegate = NotificationPresentationDelegate()

    private init() {
        center.delegate = presentationDelegate
    }

    func requestAuthorization() async {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            // The app still works when notification authorization is unavailable.
        }
    }

    func scheduleSignInNotification(body: String) async {
        guard isEnabled("signInNotificationsEnabled") else { return }
        await scheduleNotification(
            title: "FinTrack sign in",
            body: body,
            secondsFromNow: 1
        )
    }

    func scheduleSignOutNotification() async {
        guard isEnabled("signInNotificationsEnabled") else { return }
        await scheduleNotification(
            title: "FinTrack signed out",
            body: "Your finance dashboard was locked.",
            secondsFromNow: 1
        )
    }

    func scheduleBudgetWarning(category: String) async {
        guard isEnabled("budgetNotificationsEnabled") else { return }
        await scheduleNotification(
            title: "Budget reached",
            body: "Your (category) expenses have reached the category budget.",
            secondsFromNow: 1
        )
    }

    func scheduleBudgetLimitChanged(category: String) async {
        guard isEnabled("budgetNotificationsEnabled") else { return }
        await scheduleNotification(
            title: "Budget limit changed",
            body: "The budget limit for (category) was updated.",
            secondsFromNow: 1
        )
    }

    func scheduleRecurringReminder(name: String, cadence: String) async {
        guard isEnabled("recurringNotificationsEnabled") else { return }

        let content = UNMutableNotificationContent()
        content.title = "Upcoming recurring transaction"
        content.body = "(name) is due tomorrow ((cadence.lowercased()))."
        content.sound = .default

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
        var triggerDate = Calendar.current.dateComponents([.year, .month, .day], from: tomorrow)
        triggerDate.hour = 9
        triggerDate.minute = 0

        let request = UNNotificationRequest(
            identifier: "recurring.(UUID().uuidString)",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        )
        try? await center.add(request)
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

    private func isEnabled(_ key: String) -> Bool {
        guard UserDefaults.standard.object(forKey: key) != nil else { return true }
        return UserDefaults.standard.bool(forKey: key)
    }
}

final class NotificationPresentationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}

struct CoreMLInsightsService {
    func makeInsights(
        income: Double,
        expenses: Double,
        topSpendCategory: String,
        topCategoryExpense: Double,
        transactionCount: Int,
        currencyCode: String
    ) -> [FinancialInsight] {
        guard transactionCount > 0 else {
            return [
                FinancialInsight(
                    title: "Add transactions to unlock insights",
                    message: "Your on-device Core ML insights will appear after you record some activity.",
                    systemImage: "brain.head.profile",
                    tint: .blue
                )
            ]
        }

        let categoryShare = expenses > 0 ? topCategoryExpense / expenses : 0
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all
        var insights: [FinancialInsight] = []

        if let riskModel = try? OverspendingRisk(configuration: configuration),
           let risk = try? riskModel.prediction(
                category_share: categoryShare,
                monthly_income: income,
                monthly_expenses: expenses,
                transaction_count: Double(transactionCount)
           ) {
            let tint: Color
            switch risk.risk {
            case "High":
                tint = .red
            case "Medium":
                tint = .orange
            default:
                tint = .green
            }

            insights.append(
                FinancialInsight(
                    title: "\(risk.risk) overspending risk",
                    message: "Core ML estimates risk from your income, expenses, largest category share, and transaction count.",
                    systemImage: "exclamationmark.triangle.fill",
                    tint: tint
                )
            )
        }

        let previousMonthSpending = expenses * 0.9
        let averageThreeMonths = (expenses + previousMonthSpending + expenses * 0.95) / 3

        if let forecastModel = try? SpendingForecast(configuration: configuration),
           let forecast = try? forecastModel.prediction(
                previous_month_spending: previousMonthSpending,
                monthly_income: income,
                average_three_months: averageThreeMonths,
                current_month_spending: expenses
           ) {
            insights.append(
                FinancialInsight(
                    title: "Forecast spending",
                    message: "Core ML forecasts approximately \(forecast.next_month_spending.formatted(.currency(code: currencyCode))) for your next month.",
                    systemImage: "chart.line.uptrend.xyaxis",
                    tint: .blue
                )
            )
        }

        if expenses > 0, topSpendCategory != "—" {
            insights.append(
                FinancialInsight(
                    title: "\(topSpendCategory) is your largest expense",
                    message: "It represents \(categoryShare.formatted(.percent.precision(.fractionLength(0)))) of your recorded spending.",
                    systemImage: "chart.pie.fill",
                    tint: .orange
                )
            )
        }

        let savingsRate = income > 0 ? (income - expenses) / income : 0
        insights.append(
            FinancialInsight(
                title: savingsRate >= 0.20 ? "Savings are on track" : "Savings opportunity",
                message: savingsRate >= 0.20
                    ? "You are retaining \(savingsRate.formatted(.percent.precision(.fractionLength(0)))) of recorded income."
                    : "Try keeping expenses below \(income.formatted(.currency(code: currencyCode))) to improve your savings rate.",
                systemImage: savingsRate >= 0.20 ? "checkmark.seal.fill" : "arrow.down.forward.circle.fill",
                tint: savingsRate >= 0.20 ? .green : .purple
            )
        )

        return insights
    }
}

struct InsightsService {
    let apiURLString: String

    func fetchInsights() async -> [FinancialInsight] {
        guard let url = URL(string: apiURLString), apiURLString.isEmpty == false else {
            return []
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
            return []
        }
    }
}
