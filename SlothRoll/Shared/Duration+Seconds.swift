/// Convenience for showing and logging durations as fractional seconds.
extension Duration {
    var seconds: Double {
        let (whole, attoseconds) = components
        return Double(whole) + Double(attoseconds) / 1e18
    }
}
