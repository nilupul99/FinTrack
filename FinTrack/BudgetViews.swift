import SwiftUI
import CoreData

struct BudgetScreen: View {
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("activeUserEmail") private var activeUserEmail = ""
    @State private var isShowingCreateBudget = false
    @FetchRequest private var savedTransactions: FetchedResults<NSManagedObject>
    @FetchRequest private var savedBudgets: FetchedResults<NSManagedObject>

    init() {
        _savedTransactions = FetchRequest(
            fetchRequest: makeTransactionFetchRequest(),
            animation: .default
        )
        _savedBudgets = FetchRequest(
            fetchRequest: makeFetchRequest(entityName: "Budget"),
            animation: .default
        )
    }

    private var budgets: [NSManagedObject] {
        savedBudgets.filter { $0.value(forKey: "userEmail") as? String == activeUserEmail }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if budgets.isEmpty {
                        ContentUnavailableView(
                            "No Budgets Yet",
                            systemImage: "chart.pie",
                            description: Text("Create a category budget to begin tracking expenses.")
                        )
                        .padding(.vertical, 48)
                    } else {
                        Text("Category Budgets")
                            .font(.headline)

                        VStack(spacing: 12) {
                            ForEach(budgets, id: \.objectID) { budget in
                                NavigationLink {
                                    EditBudgetScreen(budget: budget)
                                } label: {
                                    BudgetCategoryRow(
                                        category: budget.value(forKey: "category") as? String ?? "Other",
                                        spent: spent(for: budget),
                                        limit: budget.value(forKey: "limit") as? Double ?? 0
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Budget")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingCreateBudget = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Create Budget")
                }
            }
            .sheet(isPresented: $isShowingCreateBudget) {
                CreateBudgetScreen(
                    userEmail: activeUserEmail,
                    viewContext: viewContext
                )
            }
        }
    }

    private func spent(for budget: NSManagedObject) -> Double {
        let category = budget.value(forKey: "category") as? String ?? ""

        return savedTransactions.reduce(0) { total, transaction in
            guard
                transaction.value(forKey: "userEmail") as? String == activeUserEmail,
                transaction.value(forKey: "category") as? String == category
            else {
                return total
            }

            let amount = transaction.value(forKey: "amount") as? Double ?? 0
            return total + (amount < 0 ? -amount : 0)
        }
    }
}

struct BudgetCategoryRow: View {
    let category: String
    let spent: Double
    let limit: Double

    private var remaining: Double {
        max(limit - spent, 0)
    }

    private var progress: Double {
        guard limit > 0 else { return 0 }
        return min(spent / limit, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(category)
                        .font(.headline)
                    HStack(spacing: 3) {
                        CurrencyText(amount: spent)
                        Text("spent of")
                        CurrencyText(amount: limit)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                CurrencyText(amount: remaining)
                    .font(.subheadline.bold())
                    .foregroundStyle(remaining == 0 ? .red : .green)
            }

            ProgressView(value: progress)
                .tint(remaining == 0 ? .red : .blue)

            Text(remaining == 0 ? "Budget reached" : "Remaining")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct CreateBudgetScreen: View {
    let userEmail: String
    let viewContext: NSManagedObjectContext
    @Environment(\.dismiss) private var dismiss
    @State private var category = "Food"
    @State private var amount = ""
    @State private var isShowingValidationAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Category Budget") {
                    CategoryPicker(category: $category)
                    TextField("Budget Amount", text: $amount)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Create Budget")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: saveBudget)
                }
            }
            .alert("Enter a valid budget amount.", isPresented: $isShowingValidationAlert) {
                Button("OK", role: .cancel) { }
            }
        }
    }

    private func saveBudget() {
        guard let limit = Double(amount), limit > 0, userEmail.isEmpty == false else {
            isShowingValidationAlert = true
            return
        }

        let request = NSFetchRequest<NSManagedObject>(entityName: "Budget")
        request.fetchLimit = 1
        request.predicate = NSPredicate(
            format: "userEmail == %@ AND category == %@",
            userEmail,
            category
        )

        let budget: NSManagedObject
        if let existingBudget = try? viewContext.fetch(request).first {
            budget = existingBudget
        } else {
            budget = NSEntityDescription.insertNewObject(forEntityName: "Budget", into: viewContext)
            budget.setValue(userEmail, forKey: "userEmail")
            budget.setValue(category, forKey: "category")
            budget.setValue(Date(), forKey: "createdAt")
        }

        budget.setValue(limit, forKey: "limit")

        do {
            try viewContext.save()
            dismiss()
        } catch {
            viewContext.rollback()
            isShowingValidationAlert = true
        }
    }
}

struct EditBudgetScreen: View {
    let budget: NSManagedObject
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @State private var category: String
    @State private var amount: String
    @State private var isShowingValidationAlert = false

    init(budget: NSManagedObject) {
        self.budget = budget
        _category = State(initialValue: budget.value(forKey: "category") as? String ?? "Food")
        let limit = budget.value(forKey: "limit") as? Double ?? 0
        _amount = State(initialValue: String(format: "%.2f", limit))
    }

    var body: some View {
        Form {
            Section("Category Budget") {
                CategoryPicker(category: $category)
                TextField("Budget Amount", text: $amount)
                    .keyboardType(.decimalPad)
            }

            Section {
                Button("Delete Budget", role: .destructive, action: deleteBudget)
            }
        }
        .navigationTitle("Edit Budget")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: saveBudget)
            }
        }
        .alert("Enter a valid budget amount.", isPresented: $isShowingValidationAlert) {
            Button("OK", role: .cancel) { }
        }
    }

    private func saveBudget() {
        guard let limit = Double(amount), limit > 0 else {
            isShowingValidationAlert = true
            return
        }

        let previousCategory = budget.value(forKey: "category") as? String ?? ""
        let previousLimit = budget.value(forKey: "limit") as? Double ?? 0
        budget.setValue(category, forKey: "category")
        budget.setValue(limit, forKey: "limit")

        do {
            try viewContext.save()
            if previousCategory != category || previousLimit != limit {
                Task {
                    await NotificationManager.shared.scheduleBudgetLimitChanged(category: category)
                }
            }
            dismiss()
        } catch {
            viewContext.rollback()
            isShowingValidationAlert = true
        }
    }

    private func deleteBudget() {
        viewContext.delete(budget)

        do {
            try viewContext.save()
            dismiss()
        } catch {
            viewContext.rollback()
            isShowingValidationAlert = true
        }
    }
}
