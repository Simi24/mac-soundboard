/// Mono Freeverb (Jezar at Dreampoint, public domain algorithm):
/// 8 parallel lowpass combs into 4 series allpasses.
public final class Freeverb: AudioProcessor {
    // Original tunings in samples at 44.1 kHz, mutually prime-ish to avoid
    // resonances lining up. Scaled to the actual sample rate.
    private static let combTunings = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617]
    private static let allpassTunings = [556, 441, 341, 225]
    private static let inputGain: Float = 0.015
    private static let wetScale: Float = 3

    private let combs: [LowpassCombFilter]
    private let allpasses: [AllpassDiffuser]
    private let wet: Float
    private let dry: Float

    /// - Parameters:
    ///   - roomSize: 0…1, tail length.
    ///   - damping: 0…1, how fast the treble dies in the tail.
    public init(roomSize: Float, damping: Float, wet: Float, dry: Float, sampleRate: Double) {
        let scale = sampleRate / 44_100
        let feedback = roomSize * 0.28 + 0.7
        combs = Self.combTunings.map {
            LowpassCombFilter(length: Int(Double($0) * scale), feedback: feedback, damping: damping * 0.4)
        }
        allpasses = Self.allpassTunings.map { AllpassDiffuser(length: Int(Double($0) * scale)) }
        self.wet = wet * Self.wetScale
        self.dry = dry
    }

    public func process(_ buffer: UnsafeMutableBufferPointer<Float>) {
        for i in buffer.indices {
            let input = buffer[i]
            let excitation = input * Self.inputGain
            var tail: Float = 0
            for comb in combs { tail += comb.process(excitation) }
            for allpass in allpasses { tail = allpass.process(tail) }
            buffer[i] = tail * wet + input * dry
        }
    }

    public func reset() {
        for comb in combs { comb.reset() }
        for allpass in allpasses { allpass.reset() }
    }
}
