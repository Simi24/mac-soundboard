import Darwin
import Testing
@testable import DSP

struct BiquadTests {
    let sr = Signals.sampleRate

    @Test func lowPassResponse() {
        let filter = Biquad(.lowPass, frequency: 1000, sampleRate: sr)
        #expect(abs(filter.magnitude(atFrequency: 50, sampleRate: sr) - 1) < 0.01)
        #expect(abs(filter.magnitude(atFrequency: 1000, sampleRate: sr) - 0.7071) < 0.01)  // −3 dB at cutoff
        #expect(filter.magnitude(atFrequency: 10000, sampleRate: sr) < 0.015)  // −40 dB/decade
    }

    @Test func highPassResponse() {
        let filter = Biquad(.highPass, frequency: 1000, sampleRate: sr)
        #expect(filter.magnitude(atFrequency: 100, sampleRate: sr) < 0.015)
        #expect(abs(filter.magnitude(atFrequency: 1000, sampleRate: sr) - 0.7071) < 0.01)
        #expect(abs(filter.magnitude(atFrequency: 15000, sampleRate: sr) - 1) < 0.02)
    }

    @Test func bandPassPeaksAtUnityOnCenter() {
        let filter = Biquad(.bandPass, frequency: 1500, q: 2, sampleRate: sr)
        #expect(abs(filter.magnitude(atFrequency: 1500, sampleRate: sr) - 1) < 0.01)
        #expect(filter.magnitude(atFrequency: 150, sampleRate: sr) < 0.1)
    }

    @Test func peakingBoostsCenterBySetGain() {
        let filter = Biquad(.peaking(gainDB: 6), frequency: 1500, q: 1, sampleRate: sr)
        let gainDB = 20 * log10(filter.magnitude(atFrequency: 1500, sampleRate: sr))
        #expect(abs(gainDB - 6) < 0.05)
        #expect(abs(filter.magnitude(atFrequency: 20, sampleRate: sr) - 1) < 0.01)
    }

    /// The time-domain recursion must agree with the analytic response.
    @Test func filteringMatchesAnalyticMagnitude() {
        let filter = Biquad(.lowPass, frequency: 1000, sampleRate: sr)
        let expected = Float(filter.magnitude(atFrequency: 3000, sampleRate: sr))
        let input = Signals.sine(3000, seconds: 0.5)
        let output = Signals.run(filter, input)
        let measured = Signals.rms(output[12000...]) / Signals.rms(input[12000...])
        #expect(abs(measured - expected) < 0.005)
    }
}
