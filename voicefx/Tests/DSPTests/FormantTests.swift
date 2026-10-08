import Testing
@testable import DSP

struct FormantTests {
    let sr = Signals.sampleRate

    @Test func envelopePeaksOnTheFormant() {
        let size = 1024
        let vowel = Signals.vowel(pitch: 130, formant: 1000, seconds: 0.1)
        let window = Window.hann(size)
        var real = (0..<size).map { vowel[$0] * window[$0] }
        var imag = [Float](repeating: 0, count: size)
        FFT(size: size).forward(real: &real, imag: &imag)
        let magnitude = (0...size / 2).map { (real[$0] * real[$0] + imag[$0] * imag[$0]).squareRoot() }

        var envelope = [Float](repeating: 0, count: size / 2 + 1)
        SpectralEnvelope(frameSize: size, lifter: 96).estimate(magnitude, into: &envelope)
        let peak = Double(envelope.indices.max { envelope[$0] < envelope[$1] }!) * sr / Double(size)
        #expect(abs(peak - 1000) < 150)
    }

    /// Octave up on a vowel with a 1 kHz formant. Without formant handling the
    /// loudest harmonic moves to ~2 kHz; with formantRatio 1 it stays near
    /// 1 kHz; with 1.5 it lands near 1.5 kHz.
    @Test(arguments: [(nil, 1700.0...2400.0), (1.0, 700.0...1300.0), (1.5, 1200.0...1800.0)] as [(Double?, ClosedRange<Double>)])
    func formantsMoveIndependently(formantRatio: Double?, expected: ClosedRange<Double>) {
        let vowel = Signals.vowel(pitch: 150, formant: 1000, seconds: 1)
        let shifter = PhaseVocoderPitchShifter(semitones: 12, formantRatio: formantRatio, sampleRate: sr)
        let output = Signals.run(shifter, vowel)
        #expect(expected.contains(Signals.dominantFrequency(output)))
    }
}
