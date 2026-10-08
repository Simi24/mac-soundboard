import Darwin
@testable import DSP

/// Test signal helpers. Analysis uses our own FFT, which FFTTests verifies
/// against a naive DFT first.
enum Signals {
    static let sampleRate = 48_000.0

    static func sine(_ frequency: Double, seconds: Double, amplitude: Float = 0.5) -> [Float] {
        let count = Int(seconds * sampleRate)
        return (0..<count).map { amplitude * Float(sin(2 * Double.pi * frequency * Double($0) / sampleRate)) }
    }

    static func impulse(count: Int) -> [Float] {
        var signal = [Float](repeating: 0, count: count)
        signal[0] = 1
        return signal
    }

    static func noise(count: Int, amplitude: Float) -> [Float] {
        var generator = SystemRandomNumberGenerator()
        return (0..<count).map { _ in Float.random(in: -amplitude...amplitude, using: &generator) }
    }

    /// Runs a processor over the signal in 256-sample blocks, like CoreAudio does.
    static func run(_ processor: AudioProcessor, _ signal: [Float], block: Int = 256) -> [Float] {
        var output = signal
        output.withUnsafeMutableBufferPointer { all in
            var start = 0
            while start < all.count {
                let end = min(start + block, all.count)
                processor.process(UnsafeMutableBufferPointer(rebasing: all[start..<end]))
                start = end
            }
        }
        return output
    }

    static func rms(_ signal: ArraySlice<Float>) -> Float {
        (signal.reduce(0) { $0 + $1 * $1 } / Float(signal.count)).squareRoot()
    }

    /// Magnitude spectrum of the last `size` samples (Hann windowed).
    static func spectrum(_ signal: [Float], size: Int = 8192) -> [Float] {
        let window = Window.hann(size)
        var real = (0..<size).map { signal[signal.count - size + $0] * window[$0] }
        var imag = [Float](repeating: 0, count: size)
        FFT(size: size).forward(real: &real, imag: &imag)
        return (0...size / 2).map { (real[$0] * real[$0] + imag[$0] * imag[$0]).squareRoot() }
    }

    static func dominantFrequency(_ signal: [Float], size: Int = 8192) -> Double {
        let bins = spectrum(signal, size: size)
        let peak = bins.indices.max { bins[$0] < bins[$1] }!
        return Double(peak) * sampleRate / Double(size)
    }

    static func level(_ signal: [Float], at frequency: Double, size: Int = 8192) -> Float {
        let bins = spectrum(signal, size: size)
        let center = Int((frequency * Double(size) / sampleRate).rounded())
        return bins[max(0, center - 2)...min(bins.count - 1, center + 2)].max()!
    }
}

extension Signals {
    /// A crude vowel: harmonics of `pitch` shaped by one formant (resonance)
    /// centered on `formant`, Lorentzian with the given bandwidth.
    static func vowel(pitch: Double, formant: Double, bandwidth: Double = 150, seconds: Double) -> [Float] {
        let count = Int(seconds * sampleRate)
        let harmonics = Array(stride(from: pitch, to: 8000, by: pitch))
        let amplitudes = harmonics.map { 1 / (1 + pow(($0 - formant) / bandwidth, 2)) }
        let scale = 0.5 / amplitudes.reduce(0, +)
        return (0..<count).map { n in
            let t = Double(n) / sampleRate
            return Float(scale * zip(harmonics, amplitudes).reduce(0) { $0 + $1.1 * sin(2 * Double.pi * $1.0 * t) })
        }
    }
}
