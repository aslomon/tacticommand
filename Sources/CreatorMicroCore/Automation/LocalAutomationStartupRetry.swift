public enum LocalAutomationStartupRetry {
    public static let delaysNanoseconds: [UInt64] = [
        50_000_000,
        100_000_000,
        200_000_000,
        250_000_000,
        400_000_000,
    ]
}
