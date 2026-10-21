/// What happened when an action ran: a short message for the toast.
struct ActionOutcome: Sendable, Equatable {
    /// One line for the user, e.g. "Added to Calendar: Feria del Libro, Sat 25 Oct".
    let message: String
}
