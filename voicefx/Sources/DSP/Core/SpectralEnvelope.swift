import Foundation

/// Smooth spectral envelope (the formants) of a magnitude spectrum, by cepstral
/// liftering: log-magnitude → inverse FFT gives the cepstrum, where the slowly
/// varying envelope sits at low quefrencies and the pitch harmonics at the
/// pitch period. Keep only quefrencies below `lifter`, FFT back, exponentiate.
///
/// `lifter` must stay below the shortest pitch period in samples (2 ms ≈ 96
/// samples at 48 kHz, i.e. voices up to 500 Hz), or the harmonics leak into
/// the envelope.
public final class SpectralEnvelope {
    private let size: Int
    private let lifter: Int
    private let fft: FFT
    private var real: [Float]
    private var imag: [Float]

    public init(frameSize: Int, lifter: Int) {
        size = frameSize
        self.lifter = lifter
        fft = FFT(size: frameSize)
        real = [Float](repeating: 0, count: frameSize)
        imag = [Float](repeating: 0, count: frameSize)
    }

    /// - Parameters:
    ///   - magnitude: `frameSize/2 + 1` positive-frequency magnitudes.
    ///   - envelope: receives `frameSize/2 + 1` envelope values.
    public func estimate(_ magnitude: [Float], into envelope: inout [Float]) {
        let half = size / 2
        // Log-magnitude of the full (Hermitian-symmetric) spectrum.
        for k in 0...half {
            let value = log(magnitude[k] + 1e-9)
            real[k] = value
            if k > 0 && k < half { real[size - k] = value }
        }
        for k in 0..<size { imag[k] = 0 }

        fft.inverse(real: &real, imag: &imag)
        // Lifter: the cepstrum is symmetric, keep both ends.
        for q in (lifter + 1)..<(size - lifter) { real[q] = 0 }
        for q in 0..<size { imag[q] = 0 }
        fft.forward(real: &real, imag: &imag)

        for k in 0...half { envelope[k] = exp(real[k]) }
    }
}
