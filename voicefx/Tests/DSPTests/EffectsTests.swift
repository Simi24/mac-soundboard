import Testing
@testable import DSP

struct EffectsTests {
    let sr = Signals.sampleRate

    @Test func emptyChainIsPassthrough() {
        let input = Signals.noise(count: 1000, amplitude: 1)
        #expect(Signals.run(EffectChain([]), input) == input)
    }

    @Test func echoRepeatsWithFeedback() {
        let echo = Echo(delaySeconds: 0.01, feedback: 0.5, mix: 0.8, sampleRate: sr)
        let delay = 480
        let output = Signals.run(echo, Signals.impulse(count: 2000))
        #expect(output[0] == 1)
        #expect(abs(output[delay] - 0.8) < 1e-6)
        #expect(abs(output[2 * delay] - 0.4) < 1e-6)
        #expect(output[delay - 1] == 0 && output[delay + 1] == 0)
    }

    @Test func ringModulatorMovesEnergyToSidebands() {
        let ring = RingModulator(frequency: 50, mix: 1, sampleRate: sr)
        let output = Signals.run(ring, Signals.sine(1000, seconds: 1))
        let sideband = Signals.level(output, at: 1050)
        #expect(Signals.level(output, at: 950) > sideband * 0.9)
        #expect(Signals.level(output, at: 1000) < sideband * 0.05)
    }

    @Test func softClipperIsTransparentBelowThresholdAndBounded() {
        let quiet: [Float] = [0, 0.3, -0.5, 0.79]
        #expect(Signals.run(SoftClipper(), quiet) == quiet)

        let loud: [Float] = stride(from: -10, through: 10, by: 0.01).map { Float($0) }
        let clipped = Signals.run(SoftClipper(), loud)
        #expect(clipped.allSatisfy { abs($0) <= 1 })
        #expect(zip(clipped, clipped.dropFirst()).allSatisfy { $0 <= $1 })  // monotonic
    }

    @Test func freeverbTailDecays() {
        let reverb = Freeverb(roomSize: 0.92, damping: 0.3, wet: 1, dry: 0, sampleRate: sr)
        let output = Signals.run(reverb, Signals.impulse(count: Int(sr) * 3))
        let second = Int(sr)
        let early = Signals.rms(output[0..<second])
        let late = Signals.rms(output[2 * second..<3 * second])
        #expect(output.allSatisfy { $0.isFinite })
        #expect(early > 0)
        #expect(late > 0 && late < early * 0.5)
    }
}
