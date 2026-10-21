import SwiftData
import SwiftUI

/// Expenses saved from receipts, newest first, with a total per currency on top.
struct ExpenseListView: View {
    let viewModel: ExpensesViewModel

    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]

    var body: some View {
        Group {
            if expenses.isEmpty {
                ContentUnavailableView(
                    "No expenses yet", systemImage: "receipt",
                    description: Text("Swipe right on a receipt card to add it here."))
            } else {
                List {
                    Section("Total") {
                        ForEach(viewModel.totals(of: expenses)) { total in
                            LabeledContent(
                                total.currency?.rawValue ?? "No currency",
                                value: viewModel.amountText(total.amount, currency: total.currency))
                            .font(.headline)
                        }
                    }
                    Section("Expenses") {
                        ForEach(expenses) { expense in
                            row(expense)
                        }
                        .onDelete { offsets in
                            offsets.map { expenses[$0] }.forEach(viewModel.delete)
                        }
                    }
                }
                .monospacedDigit()
            }
        }
        .navigationTitle("Expenses")
    }

    private func row(_ expense: Expense) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.title)
                Text(expense.date, format: .dateTime.day().month(.abbreviated).year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(viewModel.amountText(expense.amount, currency: expense.currency))
        }
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview {
    let container = Persistence.makeContainer(inMemory: true)
    container.mainContext.insert(
        Expense(title: "OXXO", amount: 249.5, currency: .mxn, date: .now, sourceAssetID: "a"))
    container.mainContext.insert(
        Expense(title: "Uber", amount: 12, currency: .usd, date: .now, sourceAssetID: "b"))
    return NavigationStack {
        ExpenseListView(viewModel: ExpensesViewModel(context: container.mainContext))
    }
    .modelContainer(container)
}
#endif
