import Darwin
import Testing
@testable import DSP

struct FFTTests {
    @Test func matchesNaiveDFT() {
        let n = 64
        let input = Signals.noise(count: n, amplitude: 1)
        var real = input
        var imag = [Float](repeating: 0, count: n)
        FFT(size: n).forward(real: &real, imag: &imag)

        for k in 0..<n {
            var expectedReal = 0.0
            var expectedImag = 0.0
            for t in 0..<n {
                let angle = -2 * Double.pi * Double(k * t) / Double(n)
                expectedReal += Double(input[t]) * cos(angle)
                expectedImag += Double(input[t]) * sin(angle)
            }
            #expect(abs(Double(real[k]) - expectedReal) < 1e-3)
            #expect(abs(Double(imag[k]) - expectedImag) < 1e-3)
        }
    }

    @Test func inverseRestoresTheSignal() {
        let n = 1024
        let input = Signals.noise(count: n, amplitude: 1)
        var real = input
        var imag = [Float](repeating: 0, count: n)
        let fft = FFT(size: n)
        fft.forward(real: &real, imag: &imag)
        fft.inverse(real: &real, imag: &imag)

        for t in 0..<n {
            #expect(abs(real[t] - input[t]) < 1e-5)
            #expect(abs(imag[t]) < 1e-5)
        }
    }

    @Test func binCenteredSineLandsInItsBin() {
        let n = 256
        var real = (0..<n).map { Float(cos(2 * Double.pi * 5 * Double($0) / Double(n))) }
        var imag = [Float](repeating: 0, count: n)
        FFT(size: n).forward(real: &real, imag: &imag)

        // A unit cosine splits into ±5, each with magnitude N/2.
        #expect(abs(real[5] - Float(n / 2)) < 1e-3)
        #expect(abs(real[n - 5] - Float(n / 2)) < 1e-3)
        let leakage = (0..<n).filter { $0 != 5 && $0 != n - 5 }.map { abs(real[$0]) + abs(imag[$0]) }.max()!
        #expect(leakage < 1e-3)
    }
}
