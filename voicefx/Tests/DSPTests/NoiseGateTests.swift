import Darwin
import Testing
@testable import DSP

struct NoiseGateTests {
    let sr = Signals.sampleRate

    private func db(_ ratio: Float) -> Float { 20 * log10(ratio) }

    @Test func pullsSteadyHissDown() {
        let hiss = Signals.noise(count: Int(sr) * 3, amplitude: 0.003)  // ≈ −55 dBFS RMS
        let output = Signals.run(NoiseGate(sampleRate: sr), hiss)
        let reduction = db(Signals.rms(output[Int(sr)...]) / Signals.rms(hiss[Int(sr)...]))
        #expect(reduction < -15)
    }

    @Test func leavesQuietSpeechLevelUntouched() {
        let gate = NoiseGate(sampleRate: sr)
        _ = Signals.run(gate, Signals.noise(count: Int(sr) * 2, amplitude: 0.003))  // learn the floor
        let speech = Signals.sine(220, seconds: 1, amplitude: 0.05)                  // ≈ −29 dBFS RMS
        let output = Signals.run(gate, speech)
        let change = db(Signals.rms(output[4800...]) / Signals.rms(speech[4800...]))
        #expect(abs(change) < 0.5)
    }

    @Test func opensWithinAFewMilliseconds() {
        let gate = NoiseGate(sampleRate: sr)
        _ = Signals.run(gate, Signals.noise(count: Int(sr) * 2, amplitude: 0.003))
        let burst = Signals.sine(1000, seconds: 0.05, amplitude: 0.3)
        let output = Signals.run(gate, burst)
        // From 5 ms on the burst must be at least 90% of its level.
        #expect(Signals.rms(output[240..<960]) > 0.9 * Signals.rms(burst[240..<960]))
    }
}
