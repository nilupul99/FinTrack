import SwiftUI
import CoreData

func makeTransactionFetchRequest() -> NSFetchRequest<NSManagedObject> {
    let request = NSFetchRequest<NSManagedObject>(entityName: "Transaction")
    request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
    return request
}

struct TransactionRowData: Identifiable, Equatable {
    let id = UUID()
    let merchant: String
    let category: String
    let amount: Double
    let symbolName: String
    let tint: Color
}

extension TransactionRowData {
    init(managedObject: NSManagedObject) {
        let amount = managedObject.value(forKey: "amount") as? Double ?? 0
        let category = managedObject.value(forKey: "category") as? String ?? "Other"

        self.init(
            merchant: managedObject.value(forKey: "title") as? String ?? "Transaction",
            category: category,
            amount: amount,
            symbolName: Self.symbolName(for: category),
            tint: amount >= 0 ? .green : .orange
        )
    }

    private static func symbolName(for category: String) -> String {
        switch category {
        case "Food":
            "fork.knife"
        case "Transport":
            "car.fill"
        case "Bills":
            "bolt.fill"
        case "Salary":
            "banknote.fill"
        default:
            "tag.fill"
        }
    }
}

struct ReceiptScanResult: Identifiable {
    let id = UUID()
    let merchant: String
    let total: Double
    let date: Date
    let itemCount: Int
}

struct FinancialInsight: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let systemImage: String
    let tint: Color

    static let sample = [
        FinancialInsight(title: "Dining is trending up", message: "Food spending is 12% higher than your average month. Consider moving $80 from shopping.", systemImage: "fork.knife.circle.fill", tint: .orange),
        FinancialInsight(title: "Savings pace improved", message: "You are saving 18% of income this month, up from 14% last month.", systemImage: "arrow.up.forward.circle.fill", tint: .green),
        FinancialInsight(title: "Recurring bills ahead", message: "Three recurring payments are due in the next 7 days.", systemImage: "calendar.badge.clock", tint: .blue)
    ]
}

enum SampleData {
    static let transactions = [
        TransactionRowData(merchant: "Coffee House", category: "Dining", amount: -6.80, symbolName: "cup.and.saucer.fill", tint: .brown),
        TransactionRowData(merchant: "Salary", category: "Income", amount: 2850.00, symbolName: "banknote.fill", tint: .green),
        TransactionRowData(merchant: "Metro Card", category: "Transport", amount: -24.00, symbolName: "tram.fill", tint: .orange)
    ]
}

struct InsightsAPIResponse: Decodable {
    let insights: [InsightPayload]
}

struct InsightPayload: Decodable {
    let title: String
    let message: String
    let systemImage: String?
}

enum AuthRoute {
    case welcome
    case login
    case signUp
    case faceID
}

extension String {
    var normalizedEmail: String {
        trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
