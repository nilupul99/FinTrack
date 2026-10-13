import SwiftUI

struct BudgetScreen: View {
    @State private var isShowingCreateBudget = false
    @State private var isShowingAddCategory = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    BudgetProgressCard()

                    SectionHeader(title: "Categories", actionTitle: "Add") {
                        isShowingAddCategory = true
                    }

                    VStack(spacing: 12) {
                        BudgetCategoryRow(name: "Food", spent: 420, limit: 600, tint: .orange, icon: "fork.knife")
                        BudgetCategoryRow(name: "Transport", spent: 180, limit: 300, tint: .blue, icon: "car.fill")
                        BudgetCategoryRow(name: "Shopping", spent: 510, limit: 450, tint: .pink, icon: "bag.fill")
                        BudgetCategoryRow(name: "Bills", spent: 730, limit: 900, tint: .purple, icon: "bolt.fill")
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Budget")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { isShowingCreateBudget = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Create Budget")
                }
            }
            .sheet(isPresented: $isShowingCreateBudget) {
                CreateBudgetScreen()
            }
            .sheet(isPresented: $isShowingAddCategory) {
                AddCategoryScreen()
            }
        }
    }
}

struct BudgetCategoryRow: View {
    let name: String
    let spent: Double
    let limit: Double
    let tint: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                    .frame(width: 42, height: 42)
                    .background(tint.opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(.headline)
                    HStack(spacing: 3) {
                        CurrencyText(amount: spent)
                        Text("of")
                        CurrencyText(amount: limit)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(spent / limit, format: .percent.precision(.fractionLength(0)))")
                    .font(.subheadline.bold())
                    .foregroundStyle(tint)
            }

            ProgressView(value: min(spent / limit, 1))
                .tint(tint)
        }
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct CreateBudgetScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = "Monthly Budget"
    @State private var amount = "2500"
    @State private var month = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Budget") {
                    TextField("Name", text: $name)
                    TextField("Limit", text: $amount)
                        .keyboardType(.decimalPad)
                    DatePicker("Month", selection: $month, displayedComponents: [.date])
                }
            }
            .navigationTitle("Create Budget")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { dismiss() }
                }
            }
        }
    }
}

struct AddCategoryScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var limit = ""
    @State private var color = "Blue"

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    TextField("Name", text: $name)
                    TextField("Monthly Limit", text: $limit)
                        .keyboardType(.decimalPad)
                    Picker("Color", selection: $color) {
                        Text("Blue").tag("Blue")
                        Text("Green").tag("Green")
                        Text("Orange").tag("Orange")
                        Text("Pink").tag("Pink")
                    }
                }
            }
            .navigationTitle("Add Category")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { dismiss() }
                }
            }
        }
    }
}
