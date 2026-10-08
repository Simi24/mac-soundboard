import Foundation

public enum Window {
    /// Periodic Hann window: copies offset by N/4 sum to a constant 2,
    /// which is what overlap-add at 4× oversampling relies on.
    public static func hann(_ size: Int) -> [Float] {
        (0..<size).map { Float(0.5 - 0.5 * cos(2 * Double.pi * Double($0) / Double(size))) }
    }
}
