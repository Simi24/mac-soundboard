/// Feedback delay. Long delays give a slapback echo; very short ones
/// (a few ms) act as a comb filter and give a metallic resonance.
public final class Echo: AudioProcessor {
    private let line: DelayLine
    private let delaySamples: Float
    private let feedback: Float
    private let mix: Float

    public init(delaySeconds: Double, feedback: Float, mix: Float, sampleRate: Double) {
        let samples = max(1, Int(delaySeconds * sampleRate))
        line = DelayLine(maxDelay: samples)
        delaySamples = Float(samples)
        self.feedback = feedback
        self.mix = mix
    }

    public func process(_ buffer: UnsafeMutableBufferPointer<Float>) {
        for i in buffer.indices {
            let x = buffer[i]
            // Read before writing: delay N−1 relative to the last write is x[n−N].
            let delayed = line.read(delay: delaySamples - 1)
            line.write(x + delayed * feedback)
            buffer[i] = x + delayed * mix
        }
    }

    public func reset() {
        line.reset()
    }
}
