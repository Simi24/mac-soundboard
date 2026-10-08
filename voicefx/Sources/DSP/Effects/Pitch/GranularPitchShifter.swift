import Foundation

/// Time-domain pitch shifter: two read taps sweep a delay line at speed
/// `ratio`, each faded by a Hann window, half a window apart so one tap is
/// always loud while the other jumps back. Cheap and low latency, slightly
/// warbly on sustained notes.
public final class GranularPitchShifter: AudioProcessor {
    private let line: DelayLine
    private let windowSamples: Float
    private let phaseStep: Float
    private var phase: Float = 0

    public init(semitones: Double, windowSeconds: Double = 0.05, sampleRate: Double) {
        let ratio = pow(2, semitones / 12)
        let window = windowSeconds * sampleRate
        windowSamples = Float(window)
        line = DelayLine(maxDelay: Int(window) + 1)
        // Tap delay d = phase·W. Read speed is 1 − dd/dt, we want it to be
        // `ratio`, so the phase moves by (1 − ratio)/W per sample.
        phaseStep = Float((1 - ratio) / window)
    }

    public func process(_ buffer: UnsafeMutableBufferPointer<Float>) {
        for i in buffer.indices {
            line.write(buffer[i])
            let phaseB = wrapped(phase + 0.5)
            // Hann windows offset by half a period sum to exactly 1.
            buffer[i] = line.read(delay: phase * windowSamples) * hann(phase)
                + line.read(delay: phaseB * windowSamples) * hann(phaseB)
            phase = wrapped(phase + phaseStep)
        }
    }

    public func reset() {
        line.reset()
        phase = 0
    }

    @inline(__always)
    private func hann(_ p: Float) -> Float {
        0.5 - 0.5 * cos(2 * Float.pi * p)
    }

    @inline(__always)
    private func wrapped(_ p: Float) -> Float {
        p - p.rounded(.down)
    }
}
