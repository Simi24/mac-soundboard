import Foundation

public enum FilterKind: Sendable {
    case lowPass
    case highPass
    /// Constant 0 dB peak gain at the center frequency.
    case bandPass
    case peaking(gainDB: Double)
}

/// Second-order IIR filter, coefficients from Robert Bristow-Johnson's
/// "Audio EQ Cookbook", run as Transposed Direct Form II.
public final class Biquad: AudioProcessor {
    private let b0: Float, b1: Float, b2: Float, a1: Float, a2: Float
    private var z1: Float = 0
    private var z2: Float = 0

    public init(_ kind: FilterKind, frequency: Double, q: Double = 0.7071, sampleRate: Double) {
        let w0 = 2 * Double.pi * frequency / sampleRate
        let cosW = cos(w0)
        let alpha = sin(w0) / (2 * q)

        let (b, a): ((Double, Double, Double), (Double, Double, Double))
        switch kind {
        case .lowPass:
            b = ((1 - cosW) / 2, 1 - cosW, (1 - cosW) / 2)
            a = (1 + alpha, -2 * cosW, 1 - alpha)
        case .highPass:
            b = ((1 + cosW) / 2, -(1 + cosW), (1 + cosW) / 2)
            a = (1 + alpha, -2 * cosW, 1 - alpha)
        case .bandPass:
            b = (alpha, 0, -alpha)
            a = (1 + alpha, -2 * cosW, 1 - alpha)
        case .peaking(let gainDB):
            let amplitude = pow(10, gainDB / 40)
            b = (1 + alpha * amplitude, -2 * cosW, 1 - alpha * amplitude)
            a = (1 + alpha / amplitude, -2 * cosW, 1 - alpha / amplitude)
        }

        // Normalize so a0 == 1.
        b0 = Float(b.0 / a.0)
        b1 = Float(b.1 / a.0)
        b2 = Float(b.2 / a.0)
        a1 = Float(a.1 / a.0)
        a2 = Float(a.2 / a.0)
    }

    @inline(__always)
    public func processSample(_ x: Float) -> Float {
        let y = b0 * x + z1
        z1 = b1 * x - a1 * y + z2
        z2 = b2 * x - a2 * y
        return y
    }

    public func process(_ buffer: UnsafeMutableBufferPointer<Float>) {
        for i in buffer.indices {
            buffer[i] = processSample(buffer[i])
        }
    }

    public func reset() {
        z1 = 0
        z2 = 0
    }

    /// |H(e^jω)| at `frequency`: the analytic response, used to verify the design.
    public func magnitude(atFrequency frequency: Double, sampleRate: Double) -> Double {
        let w = 2 * Double.pi * frequency / sampleRate
        func evaluate(_ c0: Float, _ c1: Float, _ c2: Float) -> Double {
            // c0 + c1·e^(−jω) + c2·e^(−2jω)
            let re = Double(c0) + Double(c1) * cos(w) + Double(c2) * cos(2 * w)
            let im = -Double(c1) * sin(w) - Double(c2) * sin(2 * w)
            return (re * re + im * im).squareRoot()
        }
        return evaluate(b0, b1, b2) / evaluate(1, a1, a2)
    }
}
