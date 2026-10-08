import Testing
@testable import DSP

struct DelayLineTests {
    @Test func integerDelayReturnsPastSamples() {
        let line = DelayLine(maxDelay: 10)
        for value in 1...20 { line.write(Float(value)) }
        #expect(line.read(delay: 0) == 20)
        #expect(line.read(delay: 3) == 17)
        #expect(line.read(delay: 10) == 10)
    }

    @Test func fractionalDelayInterpolatesLinearly() {
        let line = DelayLine(maxDelay: 4)
        line.write(0)
        line.write(10)
        #expect(line.read(delay: 0.5) == 5)
        #expect(line.read(delay: 0.25) == 7.5)
    }
}
