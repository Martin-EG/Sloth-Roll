import EventKit
import Foundation

/// Adds an event to the default calendar with write-only access (the app never reads events).
actor EventAction: ActionPerformer {
    private let store = EKEventStore()

    func perform(_ result: ActionResult, assetID: String) async throws -> ActionOutcome {
        let draft = try EventDraft(result)
        try await requestAccess()

        let event = EKEvent(eventStore: store)
        event.title = draft.title
        event.startDate = draft.start
        event.endDate = draft.end
        event.isAllDay = draft.isAllDay
        event.location = draft.location
        // Write-only access can still use the default calendar for new events.
        event.calendar = store.defaultCalendarForNewEvents
        do {
            try store.save(event, span: .thisEvent)
        } catch {
            Log.actions.error("event_save_failed error=\(String(describing: error), privacy: .public)")
            throw ActionError.saveFailed(reason: String(describing: error))
        }
        Log.actions.info("event_added all_day=\(draft.isAllDay)")

        let day = draft.start.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        return ActionOutcome(message: "Added to Calendar: \(draft.title), \(day)")
    }

    private func requestAccess() async throws(ActionError) {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .writeOnly, .fullAccess:
            return
        case .notDetermined:
            let granted = (try? await store.requestWriteOnlyAccessToEvents()) ?? false
            guard granted else { throw .calendarAccessDenied }
        default:
            throw .calendarAccessDenied
        }
    }
}
