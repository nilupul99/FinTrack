import SwiftUI
import CoreData

func makeFetchRequest(entityName: String, sortKey: String = "createdAt") -> NSFetchRequest<NSManagedObject> {
    let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
    request.sortDescriptors = [NSSortDescriptor(key: sortKey, ascending: false)]
    return request
}

func makeTransactionFetchRequest() -> NSFetchRequest<NSManagedObject> {
    makeFetchRequest(entityName: "Transaction")
}

enum FinancialMath {
    /// Goals count all activity in a matching category, regardless of whether
    /// the transaction is income or an expense.
    static func goalContribution(for amount: Double) -> Double {
        abs(amount)
    }

    static func budgetSpending(for amount: Double) -> Double {
        max(-amount, 0)
    }

    static func signedRecurringAmount(amount: Double, isExpense: Bool) -> Double {
        isExpense ? -abs(amount) : abs(amount)
    }
}

@MainActor
func markNewlyAchievedGoals(
    in viewContext: NSManagedObjectContext,
    userEmail: String
) -> [String] {
    let transactionRequest = NSFetchRequest<NSManagedObject>(entityName: "Transaction")
    transactionRequest.predicate = NSPredicate(format: "userEmail == %@", userEmail)

    let goalRequest = NSFetchRequest<NSManagedObject>(entityName: "Goal")
    goalRequest.predicate = NSPredicate(format: "userEmail == %@", userEmail)

    guard
        let transactions = try? viewContext.fetch(transactionRequest),
        let goals = try? viewContext.fetch(goalRequest)
    else {
        return []
    }

    return goals.compactMap { goal in
        let category = goal.value(forKey: "category") as? String ?? ""
        let categoryTotal = transactions
            .filter { $0.value(forKey: "category") as? String == category }
            .reduce(0) {
                $0 + FinancialMath.goalContribution(
                    for: $1.value(forKey: "amount") as? Double ?? 0
                )
            }
        let target = goal.value(forKey: "target") as? Double ?? 0
        let isAchieved = goal.value(forKey: "isAchieved") as? Bool ?? false

        guard categoryTotal >= target, target > 0 else {
            if isAchieved {
                goal.setValue(false, forKey: "isAchieved")
            }
            return nil
        }

        guard isAchieved == false else {
            return nil
        }

        goal.setValue(true, forKey: "isAchieved")
        return goal.value(forKey: "title") as? String ?? "Goal"
    }
}

struct TransactionRowData: Identifiable, Equatable {
    let id = UUID()
    let merchant: String
    let category: String
    let amount: Double
    let symbolName: String
    let tint: Color
}

struct RecurringTransactionData: Identifiable, Codable {
    let id: UUID
    let userEmail: String
    let name: String
    let category: String
    let amount: Double
    let cadence: String
    let isExpense: Bool
    let createdAt: Date

    var signedAmount: Double {
        FinancialMath.signedRecurringAmount(amount: amount, isExpense: isExpense)
    }
}

enum RecurringTransactionStore {
    static func load(from encodedTransactions: String) -> [RecurringTransactionData] {
        guard
            let data = encodedTransactions.data(using: .utf8),
            let transactions = try? JSONDecoder().decode([RecurringTransactionData].self, from: data)
        else {
            return []
        }

        return transactions
    }

    static func encode(_ transactions: [RecurringTransactionData]) -> String {
        guard
            let data = try? JSONEncoder().encode(transactions),
            let encodedTransactions = String(data: data, encoding: .utf8)
        else {
            return ""
        }

        return encodedTransactions
    }
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
    let recognizedText: String

    init(
        merchant: String,
        total: Double,
        date: Date,
        itemCount: Int,
        recognizedText: String = ""
    ) {
        self.merchant = merchant
        self.total = total
        self.date = date
        self.itemCount = itemCount
        self.recognizedText = recognizedText
    }
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
