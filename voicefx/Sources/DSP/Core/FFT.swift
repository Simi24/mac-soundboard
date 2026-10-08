import Foundation

/// Iterative radix-2 Cooley–Tukey FFT, in place on split complex arrays.
///
/// Twiddle factors and the bit-reversal permutation are precomputed in `init`,
/// so `forward` and `inverse` never allocate.
public final class FFT {
    public let size: Int
    private let cosTable: [Float]  // cos(2πk/N), k < N/2
    private let sinTable: [Float]  // sin(2πk/N), k < N/2
    private let bitReversed: [Int]

    public init(size: Int) {
        precondition(size >= 2 && size & (size - 1) == 0, "FFT size must be a power of two")
        self.size = size
        let bits = size.trailingZeroBitCount
        cosTable = (0..<size / 2).map { Float(cos(2 * Double.pi * Double($0) / Double(size))) }
        sinTable = (0..<size / 2).map { Float(sin(2 * Double.pi * Double($0) / Double(size))) }
        bitReversed = (0..<size).map { index in
            var reversed = 0
            for bit in 0..<bits where index & (1 << bit) != 0 {
                reversed |= 1 << (bits - 1 - bit)
            }
            return reversed
        }
    }

    /// X[k] = Σ x[n]·e^(−2πikn/N), unnormalized.
    public func forward(real: inout [Float], imag: inout [Float]) {
        transform(&real, &imag, direction: -1)
    }

    /// x[n] = (1/N)·Σ X[k]·e^(+2πikn/N), so `inverse(forward(x)) == x`.
    public func inverse(real: inout [Float], imag: inout [Float]) {
        transform(&real, &imag, direction: 1)
        let scale = 1 / Float(size)
        for i in 0..<size {
            real[i] *= scale
            imag[i] *= scale
        }
    }

    private func transform(_ real: inout [Float], _ imag: inout [Float], direction: Float) {
        precondition(real.count == size && imag.count == size, "buffer size must match FFT size")

        for i in 0..<size {
            let j = bitReversed[i]
            if j > i {
                real.swapAt(i, j)
                imag.swapAt(i, j)
            }
        }

        // Butterflies: merge pairs of half-size DFTs, doubling the span each pass.
        var half = 1
        while half < size {
            let twiddleStride = size / (half * 2)
            var start = 0
            while start < size {
                for k in 0..<half {
                    let wReal = cosTable[k * twiddleStride]
                    let wImag = direction * sinTable[k * twiddleStride]
                    let a = start + k
                    let b = a + half
                    let tReal = real[b] * wReal - imag[b] * wImag
                    let tImag = real[b] * wImag + imag[b] * wReal
                    real[b] = real[a] - tReal
                    imag[b] = imag[a] - tImag
                    real[a] += tReal
                    imag[a] += tImag
                }
                start += half * 2
            }
            half *= 2
        }
    }
}
