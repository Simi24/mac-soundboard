/// Multiplies the signal by a sine carrier: every frequency f becomes the pair
/// f ± carrier, which destroys the harmonic structure of the voice ("robot").
public final class RingModulator: AudioProcessor {
    private var carrier: SineOscillator
    private let mix: Float

    public init(frequency: Double, mix: Float, sampleRate: Double) {
        carrier = SineOscillator(frequency: frequency, sampleRate: sampleRate)
        self.mix = mix
    }

    public func process(_ buffer: UnsafeMutableBufferPointer<Float>) {
        for i in buffer.indices {
            let x = buffer[i]
            buffer[i] = x * (1 - mix) + x * carrier.next() * mix
        }
    }

    public func reset() {
        carrier.reset()
    }
}
