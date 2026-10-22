import CreateML
import Foundation

let projectURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputURL = projectURL.appendingPathComponent("FinTrack", isDirectory: true)
let trainingDataURL = projectURL
    .appendingPathComponent("Tools", isDirectory: true)
    .appendingPathComponent("TrainingData", isDirectory: true)
try FileManager.default.createDirectory(at: trainingDataURL, withIntermediateDirectories: true)

func writeCSV(named name: String, header: String, rows: [String]) throws -> URL {
    let url = trainingDataURL.appendingPathComponent(name)
    try ([header] + rows).joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    return url
}

var riskRows: [String] = []
var forecastRows: [String] = []
var riskIncome: [Double] = []
var riskExpenses: [Double] = []
var riskCategoryShare: [Double] = []
var riskTransactionCount: [Double] = []
var riskLabels: [String] = []
var forecastIncome: [Double] = []
var forecastPreviousMonth: [Double] = []
var forecastCurrentMonth: [Double] = []
var forecastAverageThreeMonths: [Double] = []
var forecastNextMonth: [Double] = []

for index in 0..<240 {
    let income = 1_500.0 + Double((index * 113) % 4_500)
    let expenses = 400.0 + Double((index * 173) % 6_000)
    let categoryShare = 0.15 + Double((index * 17) % 70) / 100
    let transactionCount = 6 + Double((index * 7) % 38)
    let risk: String

    if expenses / income > 0.85 || categoryShare > 0.60 {
        risk = "High"
    } else if expenses / income > 0.60 || categoryShare > 0.42 {
        risk = "Medium"
    } else {
        risk = "Low"
    }

    riskRows.append("\(income),\(expenses),\(categoryShare),\(transactionCount),\(risk)")
    riskIncome.append(income)
    riskExpenses.append(expenses)
    riskCategoryShare.append(categoryShare)
    riskTransactionCount.append(transactionCount)
    riskLabels.append(risk)

    let previousMonth = 400.0 + Double((index * 89) % 4_800)
    let currentMonth = 450.0 + Double((index * 127) % 5_100)
    let averageThreeMonths = (previousMonth + currentMonth + Double((index * 47) % 4_600)) / 3
    let predictedNextMonth = currentMonth * 0.55 + previousMonth * 0.25 + averageThreeMonths * 0.20
    forecastRows.append("\(income),\(previousMonth),\(currentMonth),\(averageThreeMonths),\(predictedNextMonth)")
    forecastIncome.append(income)
    forecastPreviousMonth.append(previousMonth)
    forecastCurrentMonth.append(currentMonth)
    forecastAverageThreeMonths.append(averageThreeMonths)
    forecastNextMonth.append(predictedNextMonth)
}

let riskDataURL = try writeCSV(
    named: "overspending_risk.csv",
    header: "monthly_income,monthly_expenses,category_share,transaction_count,risk",
    rows: riskRows
)
let forecastDataURL = try writeCSV(
    named: "spending_forecast.csv",
    header: "monthly_income,previous_month_spending,current_month_spending,average_three_months,next_month_spending",
    rows: forecastRows
)

let riskData = try MLDataTable(dictionary: [
    "monthly_income": riskIncome,
    "monthly_expenses": riskExpenses,
    "category_share": riskCategoryShare,
    "transaction_count": riskTransactionCount,
    "risk": riskLabels
])
let forecastData = try MLDataTable(dictionary: [
    "monthly_income": forecastIncome,
    "previous_month_spending": forecastPreviousMonth,
    "current_month_spending": forecastCurrentMonth,
    "average_three_months": forecastAverageThreeMonths,
    "next_month_spending": forecastNextMonth
])
let riskClassifier = try MLClassifier(trainingData: riskData, targetColumn: "risk")
let spendingRegressor = try MLRegressor(trainingData: forecastData, targetColumn: "next_month_spending")

let metadata = MLModelMetadata(
    author: "FinTrack",
    shortDescription: "Synthetic demonstration model. Replace with real, consented financial data before release.",
    version: "1.0"
)

try riskClassifier.write(to: outputURL.appendingPathComponent("OverspendingRisk.mlmodel"), metadata: metadata)
try spendingRegressor.write(to: outputURL.appendingPathComponent("SpendingForecast.mlmodel"), metadata: metadata)

print("Created OverspendingRisk.mlmodel and SpendingForecast.mlmodel")
