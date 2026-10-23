import SwiftUI
import CoreData

struct GoalsScreen: View {
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("activeUserEmail") private var activeUserEmail = ""
    @State private var isShowingAddGoal = false
    @FetchRequest private var savedTransactions: FetchedResults<NSManagedObject>
    @FetchRequest private var savedGoals: FetchedResults<NSManagedObject>

    init() {
        _savedTransactions = FetchRequest(
            fetchRequest: makeTransactionFetchRequest(),
            animation: .default
        )
        _savedGoals = FetchRequest(
            fetchRequest: makeFetchRequest(entityName: "Goal"),
            animation: .default
        )
    }

    private var goals: [NSManagedObject] {
        savedGoals.filter { $0.value(forKey: "userEmail") as? String == activeUserEmail }
    }

    private func savedAmount(for category: String) -> Double {
        savedTransactions.reduce(0) { total, transaction in
            guard
                transaction.value(forKey: "userEmail") as? String == activeUserEmail,
                transaction.value(forKey: "category") as? String == category
            else {
                return total
            }

            return total + (transaction.value(forKey: "amount") as? Double ?? 0)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if goals.isEmpty {
                        ContentUnavailableView(
                            "No Goals Yet",
                            systemImage: "target",
                            description: Text("Create a savings goal to track it from your transactions.")
                        )
                        .padding(.vertical, 48)
                    } else {
                        ForEach(goals, id: \.objectID) { goal in
                            NavigationLink {
                                EditGoalScreen(goal: goal)
                            } label: {
                                GoalCard(
                                    title: goal.value(forKey: "title") as? String ?? "Goal",
                                    category: goal.value(forKey: "category") as? String ?? "Other",
                                    saved: max(savedAmount(for: goal.value(forKey: "category") as? String ?? ""), 0),
                                    target: goal.value(forKey: "target") as? Double ?? 0,
                                    isAchieved: goal.value(forKey: "isAchieved") as? Bool ?? false
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Goals")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingAddGoal = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Goal")
                }
            }
            .sheet(isPresented: $isShowingAddGoal) {
                AddGoalScreen(
                    userEmail: activeUserEmail,
                    viewContext: viewContext
                )
            }
        }
    }
}

struct GoalCard: View {
    let title: String
    let category: String
    let saved: Double
    let target: Double
    let isAchieved: Bool

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(saved / target, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: isAchieved ? "checkmark.seal.fill" : "target")
                    .foregroundStyle(isAchieved ? .green : .blue)
                    .frame(width: 44, height: 44)
                    .background((isAchieved ? Color.green : Color.blue).opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 3) {
                        CurrencyText(amount: saved)
                        Text("saved")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                if isAchieved {
                    Text("Achieved")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                }
            }

            ProgressView(value: progress)
                .tint(isAchieved ? .green : .blue)

            HStack(spacing: 3) {
                Text("Target:")
                CurrencyText(amount: target)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct AddGoalScreen: View {
    let userEmail: String
    let viewContext: NSManagedObjectContext
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var category = "Salary"
    @State private var target = ""
    @State private var isShowingValidationAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal") {
                    TextField("Title", text: $title)
                    CategoryPicker(category: $category)
                    TextField("Target Amount", text: $target)
                        .keyboardType(.decimalPad)
                }

                Section {
                    Text("A goal is achieved when transactions in its category reach its target.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: saveGoal)
                }
            }
            .alert("Enter a title and a valid target amount.", isPresented: $isShowingValidationAlert) {
                Button("OK", role: .cancel) { }
            }
        }
    }

    private func saveGoal() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            trimmedTitle.isEmpty == false,
            let targetAmount = Double(target),
            targetAmount > 0,
            userEmail.isEmpty == false
        else {
            isShowingValidationAlert = true
            return
        }

        let goal = NSEntityDescription.insertNewObject(forEntityName: "Goal", into: viewContext)
        goal.setValue(trimmedTitle, forKey: "title")
        goal.setValue(category, forKey: "category")
        goal.setValue(targetAmount, forKey: "target")
        goal.setValue(false, forKey: "isAchieved")
        goal.setValue(Date(), forKey: "createdAt")
        goal.setValue(userEmail, forKey: "userEmail")

        do {
            try viewContext.save()
            dismiss()
        } catch {
            viewContext.rollback()
            isShowingValidationAlert = true
        }
    }
}

struct EditGoalScreen: View {
    let goal: NSManagedObject
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @State private var title: String
    @State private var category: String
    @State private var target: String
    @State private var isShowingValidationAlert = false

    init(goal: NSManagedObject) {
        self.goal = goal
        _title = State(initialValue: goal.value(forKey: "title") as? String ?? "")
        _category = State(initialValue: goal.value(forKey: "category") as? String ?? "Salary")
        let targetAmount = goal.value(forKey: "target") as? Double ?? 0
        _target = State(initialValue: String(format: "%.2f", targetAmount))
    }

    var body: some View {
        Form {
            Section("Goal") {
                TextField("Title", text: $title)
                CategoryPicker(category: $category)
                TextField("Target Amount", text: $target)
                    .keyboardType(.decimalPad)
            }

            Section {
                Button("Delete Goal", role: .destructive, action: deleteGoal)
            }
        }
        .navigationTitle("Edit Goal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: saveGoal)
            }
        }
        .alert("Enter a title and a valid target amount.", isPresented: $isShowingValidationAlert) {
            Button("OK", role: .cancel) { }
        }
    }

    private func saveGoal() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTitle.isEmpty == false,
              let targetAmount = Double(target),
              targetAmount > 0 else {
            isShowingValidationAlert = true
            return
        }

        goal.setValue(trimmedTitle, forKey: "title")
        goal.setValue(category, forKey: "category")
        goal.setValue(targetAmount, forKey: "target")
        goal.setValue(false, forKey: "isAchieved")

        do {
            _ = markNewlyAchievedGoals(
                in: viewContext,
                userEmail: goal.value(forKey: "userEmail") as? String ?? ""
            )
            try viewContext.save()
            dismiss()
        } catch {
            viewContext.rollback()
            isShowingValidationAlert = true
        }
    }

    private func deleteGoal() {
        viewContext.delete(goal)

        do {
            try viewContext.save()
            dismiss()
        } catch {
            viewContext.rollback()
            isShowingValidationAlert = true
        }
    }
}
