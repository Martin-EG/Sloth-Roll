/// Turns one reviewed `ActionResult` into a real action (calendar event, Maps, expense).
protocol ActionPerformer: Sendable {
    /// Runs the action for the screenshot `assetID`. Throws `ActionError` with a user-facing
    /// message when it can't (permission denied, missing date, ...).
    func perform(_ result: ActionResult, assetID: String) async throws -> ActionOutcome
}
