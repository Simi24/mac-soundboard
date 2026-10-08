import Foundation

/// Adaptive downward expander: pulls the mic's hiss down between words.
///
/// It tracks the noise floor as the slowly rising minimum of the signal
/// envelope, so it adapts to any mic without a hand-set threshold. Anything
/// within `marginDB` of that floor is attenuated (expansion 1:3, at most
/// `maxReductionDB`); speech is far louder and passes untouched. The gain opens
/// in ~1 ms and closes over ~80 ms, so word tails are not chopped.
public final class NoiseGate: AudioProcessor {
    private let attack: Float       // envelope rise coefficient
    private let release: Float      // envelope fall coefficient
    private let open: Float         // gain rise coefficient
    private let close: Float        // gain fall coefficient
    private let floorRise: Float    // per-sample multiplier, ≈ +6 dB/s
    private let margin: Float
    private let minimumGain: Float
    private let thresholdRange: ClosedRange<Float>

    private static let initialFloor: Float = pow(10, -50 / 20)
    private static let lowestFloor: Float = pow(10, -80 / 20)

    private var envelope = initialFloor
    private var noiseFloor = initialFloor
    private var gain: Float = 1

    public init(marginDB: Float = 12, maxReductionDB: Float = 30, sampleRate: Double) {
        func coefficient(_ seconds: Double) -> Float { Float(1 - exp(-1 / (seconds * sampleRate))) }
        attack = coefficient(0.001)
        release = coefficient(0.08)
        open = coefficient(0.001)
        close = coefficient(0.08)
        floorRise = Float(pow(10, 6 / 20 / sampleRate))
        margin = pow(10, marginDB / 20)
        minimumGain = pow(10, -maxReductionDB / 20)
        thresholdRange = pow(10, -60 / 20)...pow(10, -30 / 20)
    }

    public func process(_ buffer: UnsafeMutableBufferPointer<Float>) {
        for i in buffer.indices {
            let level = abs(buffer[i])
            envelope += (level - envelope) * (level > envelope ? attack : release)
            // Clamped from below: after digital silence the floor must be able to climb back in seconds.
            noiseFloor = min(envelope, max(noiseFloor, Self.lowestFloor) * floorRise)

            let threshold = min(max(noiseFloor * margin, thresholdRange.lowerBound), thresholdRange.upperBound)
            var target: Float = 1
            if envelope < threshold {
                let ratio = envelope / threshold
                target = max(ratio * ratio, minimumGain)  // 1:3 expansion: gain ∝ level²
            }
            gain += (target - gain) * (target > gain ? open : close)
            buffer[i] *= gain
        }
    }

    public func reset() {
        envelope = Self.initialFloor
        noiseFloor = Self.initialFloor
        gain = 1
    }
}
