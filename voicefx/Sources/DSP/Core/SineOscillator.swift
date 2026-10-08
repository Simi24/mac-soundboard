import Foundation

/// Phase-accumulator sine. The phase is kept in Double and wrapped, so it
/// never loses precision over hours of runtime.
public struct SineOscillator {
    private var phase: Double = 0
    private let increment: Double

    public init(frequency: Double, sampleRate: Double) {
        increment = frequency / sampleRate
    }

    @inline(__always)
    public mutating func next() -> Float {
        let value = Float(sin(2 * Double.pi * phase))
        phase += increment
        if phase >= 1 { phase -= 1 }
        return value
    }

    public mutating func reset() {
        phase = 0
    }
}
