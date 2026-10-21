import SwiftUI

/// Small form to fix what the model read (title, date, time, place, amount) before swiping.
struct EditSheet: View {
    let onSave: (ActionResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var result: ActionResult
    @State private var hasDate: Bool
    @State private var day: Date
    @State private var hasTime: Bool
    @State private var time: Date
    @State private var location: String
    @State private var amount: Decimal

    init(result: ActionResult, onSave: @escaping (ActionResult) -> Void) {
        self.onSave = onSave
        _result = State(initialValue: result)
        _hasDate = State(initialValue: result.date != nil)
        _day = State(initialValue: result.day() ?? Date())
        _hasTime = State(initialValue: result.hourAndMinute != nil)
        _time = State(initialValue: result.dayAndTime() ?? Date())
        _location = State(initialValue: result.location ?? "")
        _amount = State(initialValue: result.amount ?? 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $result.title)
                if result.type != .place { dateSection }
                if result.type != .receipt {
                    TextField("Place or address", text: $location)
                }
                if result.type == .receipt { amountSection }
            }
            .navigationTitle(CardText.typeLabel(result.type))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(edited)
                        dismiss()
                    }
                    .disabled(result.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder private var dateSection: some View {
        Toggle("Date", isOn: $hasDate.animation())
        if hasDate {
            DatePicker("Day", selection: $day, displayedComponents: .date)
            if result.type == .event {
                Toggle("Time", isOn: $hasTime.animation())
                if hasTime {
                    DatePicker("Starts", selection: $time, displayedComponents: .hourAndMinute)
                }
            }
        }
    }

    @ViewBuilder private var amountSection: some View {
        TextField("Amount", value: $amount, format: .number)
            .keyboardType(.decimalPad)
        Picker("Currency", selection: $result.currency) {
            Text("Unknown").tag(Currency?.none)
            ForEach(Currency.allCases, id: \.self) { Text($0.rawValue).tag(Currency?.some($0)) }
        }
    }

    /// The form's values written back in the result's string formats.
    private var edited: ActionResult {
        var edited = result
        edited.title = result.title.trimmingCharacters(in: .whitespaces)
        edited.date = hasDate ? ActionResult.dateString(from: day) : nil
        edited.time = hasDate && hasTime ? ActionResult.timeString(from: time) : nil
        let trimmedLocation = location.trimmingCharacters(in: .whitespaces)
        edited.location = trimmedLocation.isEmpty ? nil : trimmedLocation
        edited.amount = amount > 0 ? amount : nil
        return edited
    }
}
