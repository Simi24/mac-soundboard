import Darwin
import Testing
@testable import DSP

struct PitchShifterTests {
    let sr = Signals.sampleRate
    /// One bin of the 8192-point analysis FFT at 48 kHz.
    let tolerance = 12.0

    @Test(arguments: [12.0, 7.0, -7.0, -12.0])
    func phaseVocoderShiftsPitch(semitones: Double) {
        let shifter = PhaseVocoderPitchShifter(semitones: semitones, sampleRate: sr)
        let output = Signals.run(shifter, Signals.sine(440, seconds: 1))
        let expected = 440 * pow(2, semitones / 12)
        #expect(abs(Signals.dominantFrequency(output) - expected) < tolerance)
    }

    /// Level within ±3.5 dB and a steady envelope (no "phasiness" wobble),
    /// for any shift and for tones on and off bin centers.
    @Test(arguments: [0.0, 7.0, -7.0, 12.0], [210.0, 440.0, 1234.5])
    func phaseVocoderKeepsLevelSteady(semitones: Double, frequency: Double) {
        let input = Signals.sine(frequency, seconds: 1)
        let output = Signals.run(PhaseVocoderPitchShifter(semitones: semitones, sampleRate: sr), input)
        let gainDB = 20 * log10(Signals.rms(output[24000...]) / Signals.rms(input[24000...]))
        #expect(abs(gainDB) < 3.5)

        let envelope = stride(from: 24000, to: 47520, by: 480).map { Signals.rms(output[$0..<$0 + 480]) }
        #expect(envelope.max()! / envelope.min()! < 1.15)
    }

    @Test(arguments: [12.0, 5.0, -7.0])
    func granularShiftsPitch(semitones: Double) {
        let shifter = GranularPitchShifter(semitones: semitones, sampleRate: sr)
        let output = Signals.run(shifter, Signals.sine(440, seconds: 1))
        let expected = 440 * pow(2, semitones / 12)
        #expect(abs(Signals.dominantFrequency(output) - expected) < tolerance)
    }
}
