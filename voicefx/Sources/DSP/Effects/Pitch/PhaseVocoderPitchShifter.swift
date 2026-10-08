import Foundation

/// Frequency-domain pitch shifter (phase vocoder).
///
/// Every `hop` samples: window the last `frameSize` input samples, FFT, and
/// estimate each bin's *true* frequency from how much its phase advanced since
/// the previous frame. Move every bin to `k·ratio` with its frequency scaled
/// by `ratio`, rebuild consistent phases, inverse FFT and overlap-add.
///
/// With `formantRatio`, pitch and formants move independently: each bin is
/// split into excitation (magnitude / spectral envelope) and envelope; only the
/// excitation is pitch-shifted, then the envelope is re-applied stretched by
/// `formantRatio`. 1 keeps the formants (natural voice, higher or lower);
/// nil lets them follow the pitch (chipmunk/demon).
///
/// Each synthesized frame is rescaled to the energy of the frame it came from:
/// this simple vocoder loses the phase relationship between neighbouring bins,
/// which otherwise makes the output level drift by several dB with the shift.
///
/// Latency is `frameSize − hop` samples (768 = 16 ms at 48 kHz by default).
public final class PhaseVocoderPitchShifter: AudioProcessor {
    private let ratio: Float
    private let frameSize: Int
    private let hop: Int
    private let oversampling: Int
    private let latency: Int
    private let binWidth: Float           // Hz per bin
    private let expectedAdvance: Float    // phase advance of a bin-centered sine over one hop
    private let fft: FFT
    private let window: [Float]
    private let formantRatio: Float?
    private let envelopeEstimator: SpectralEnvelope

    private var inputFIFO: [Float]
    private var outputFIFO: [Float]
    private var outputAccumulator: [Float]
    private var real: [Float]
    private var imag: [Float]
    private var lastPhase: [Float]
    private var phaseSum: [Float]
    private var analysisMagnitude: [Float]
    private var analysisFrequency: [Float]
    private var synthesisMagnitude: [Float]
    private var synthesisFrequency: [Float]
    private var envelope: [Float]
    private var cursor: Int
    private var frameEnergy: Float = 0

    public init(
        semitones: Double,
        formantRatio: Double? = nil,
        frameSize: Int = 1024,
        oversampling: Int = 4,
        sampleRate: Double
    ) {
        ratio = Float(pow(2, semitones / 12))
        self.formantRatio = formantRatio.map(Float.init)
        envelopeEstimator = SpectralEnvelope(frameSize: frameSize, lifter: Int(sampleRate * 0.002))
        self.frameSize = frameSize
        self.oversampling = oversampling
        hop = frameSize / oversampling
        latency = frameSize - hop
        binWidth = Float(sampleRate) / Float(frameSize)
        expectedAdvance = 2 * Float.pi * Float(hop) / Float(frameSize)
        fft = FFT(size: frameSize)
        window = Window.hann(frameSize)

        let bins = frameSize / 2 + 1
        inputFIFO = [Float](repeating: 0, count: frameSize)
        outputFIFO = [Float](repeating: 0, count: frameSize)
        outputAccumulator = [Float](repeating: 0, count: frameSize * 2)
        real = [Float](repeating: 0, count: frameSize)
        imag = [Float](repeating: 0, count: frameSize)
        lastPhase = [Float](repeating: 0, count: bins)
        phaseSum = [Float](repeating: 0, count: bins)
        analysisMagnitude = [Float](repeating: 0, count: bins)
        analysisFrequency = [Float](repeating: 0, count: bins)
        synthesisMagnitude = [Float](repeating: 0, count: bins)
        synthesisFrequency = [Float](repeating: 0, count: bins)
        envelope = [Float](repeating: 1, count: bins)
        cursor = latency
    }

    public func process(_ buffer: UnsafeMutableBufferPointer<Float>) {
        for i in buffer.indices {
            inputFIFO[cursor] = buffer[i]
            buffer[i] = outputFIFO[cursor - latency]
            cursor += 1
            if cursor == frameSize {
                cursor = latency
                processFrame()
            }
        }
    }

    public func reset() {
        zero(&inputFIFO)
        zero(&outputFIFO)
        zero(&outputAccumulator)
        zero(&lastPhase)
        zero(&phaseSum)
        cursor = latency
    }

    private func zero(_ buffer: inout [Float]) {
        for i in buffer.indices { buffer[i] = 0 }
    }

    private func processFrame() {
        analyze()
        shift()
        synthesize()

        for k in 0..<hop { outputFIFO[k] = outputAccumulator[k] }
        for k in 0..<frameSize { outputAccumulator[k] = outputAccumulator[k + hop] }
        for k in frameSize..<frameSize + hop { outputAccumulator[k] = 0 }
        for k in 0..<latency { inputFIFO[k] = inputFIFO[k + hop] }
    }

    /// Magnitude and true frequency of each positive-frequency bin.
    private func analyze() {
        frameEnergy = 0
        for k in 0..<frameSize {
            real[k] = inputFIFO[k] * window[k]
            imag[k] = 0
            frameEnergy += real[k] * real[k]
        }
        fft.forward(real: &real, imag: &imag)

        for k in 0...frameSize / 2 {
            let phase = atan2(imag[k], real[k])
            // Deviation of the measured phase advance from the bin-center one,
            // folded into ±π, tells how far the partial sits from the bin center.
            let deviation = wrapToPi(phase - lastPhase[k] - Float(k) * expectedAdvance)
            lastPhase[k] = phase
            let binOffset = deviation * Float(oversampling) / (2 * Float.pi)
            analysisMagnitude[k] = (real[k] * real[k] + imag[k] * imag[k]).squareRoot()
            analysisFrequency[k] = (Float(k) + binOffset) * binWidth
        }
    }

    /// Move bin k to bin k·ratio, scaling its frequency by the same amount.
    private func shift() {
        let bins = frameSize / 2 + 1
        for k in 0..<bins {
            synthesisMagnitude[k] = 0
            synthesisFrequency[k] = 0
        }
        if formantRatio != nil {
            envelopeEstimator.estimate(analysisMagnitude, into: &envelope)
        }
        for k in 0..<bins {
            let target = Int(Float(k) * ratio)
            guard target < bins else { break }
            let excitation = formantRatio == nil ? analysisMagnitude[k] : analysisMagnitude[k] / envelope[k]
            synthesisMagnitude[target] += excitation
            synthesisFrequency[target] = analysisFrequency[k] * ratio
        }
        if let formantRatio {
            for k in 0..<bins {
                synthesisMagnitude[k] *= envelopeValue(atBin: Float(k) / formantRatio)
            }
        }
    }

    /// Linear interpolation of the envelope between bins (clamped at Nyquist).
    @inline(__always)
    private func envelopeValue(atBin position: Float) -> Float {
        let last = envelope.count - 1
        guard position < Float(last) else { return envelope[last] }
        let lower = Int(position)
        let fraction = position - Float(lower)
        return envelope[lower] + (envelope[lower + 1] - envelope[lower]) * fraction
    }

    /// Accumulate phases from the shifted frequencies, inverse FFT, overlap-add.
    private func synthesize() {
        for k in 0...frameSize / 2 {
            let binOffset = synthesisFrequency[k] / binWidth - Float(k)
            let advance = Float(k) * expectedAdvance + 2 * Float.pi * binOffset / Float(oversampling)
            phaseSum[k] = wrapToPi(phaseSum[k] + advance)
            real[k] = synthesisMagnitude[k] * cos(phaseSum[k])
            imag[k] = synthesisMagnitude[k] * sin(phaseSum[k])
        }
        // Negative frequencies stay zero: only the real part is used below.
        for k in frameSize / 2 + 1..<frameSize {
            real[k] = 0
            imag[k] = 0
        }
        fft.inverse(real: &real, imag: &imag)

        var synthesisEnergy: Float = 0
        for k in 0..<frameSize {
            let windowed = real[k] * window[k]
            synthesisEnergy += windowed * windowed
        }
        // Match the analysis frame energy (capped, so a frame whose content was
        // shifted past Nyquist doesn't get its leftovers blown up), then divide
        // by the Hann² overlap sum, which is 3/8 · oversampling.
        let energyMatch = synthesisEnergy > 1e-12 ? min((frameEnergy / synthesisEnergy).squareRoot(), 4) : 0
        let gain = energyMatch / (0.375 * Float(oversampling))
        for k in 0..<frameSize {
            outputAccumulator[k] += window[k] * real[k] * gain
        }
    }

    @inline(__always)
    private func wrapToPi(_ angle: Float) -> Float {
        angle - 2 * Float.pi * (angle / (2 * Float.pi)).rounded()
    }
}
