import Testing
@testable import DSP

struct VoiceEngineTests {
    let sr = Signals.sampleRate

    private func render(_ engine: VoiceEngine, _ signal: [Float]) -> [Float] {
        var buffer = signal
        buffer.withUnsafeMutableBufferPointer { engine.render($0) }
        return buffer
    }

    /// Clean = only the noise gate, which leaves speech-level signals alone.
    @Test func startsClean() {
        let engine = VoiceEngine(sampleRate: sr)
        let input = Signals.sine(300, seconds: 0.1)
        let output = render(engine, input)
        #expect(engine.preset == .clean)
        #expect(zip(output[480...], input[480...]).allSatisfy { abs($0 - $1) < 1e-3 })
    }

    @Test func switchingFadesOutThenIn() {
        let engine = VoiceEngine(sampleRate: sr)
        let ones = [Float](repeating: 0.5, count: 256)
        engine.select(.radio)
        let fadeOut = render(engine, ones)
        let fadeIn = render(engine, ones)
        #expect(engine.preset == .radio)
        #expect(abs(fadeOut.first! - 0.5) < 1e-6)
        #expect(abs(fadeOut.last!) < 0.01)
        #expect(abs(fadeIn.first!) < 0.01)
    }

    /// Every preset must stay finite and within ±1 on a loud, long input:
    /// catches unstable feedback loops and gain build-ups.
    @Test(arguments: Preset.allCases)
    func presetIsStableOnLoudNoise(preset: Preset) {
        let engine = VoiceEngine(sampleRate: sr)
        engine.select(preset)
        let output = Signals.noise(count: Int(sr) * 5, amplitude: 0.9).chunks(of: 256).flatMap { render(engine, $0) }
        #expect(output.allSatisfy { $0.isFinite && abs($0) <= 1 })
        #expect(Signals.rms(output[Int(sr)...]) > 0.01)
    }
}

private extension Array {
    func chunks(of size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}
