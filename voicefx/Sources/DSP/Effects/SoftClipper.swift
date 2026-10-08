import Foundation

/// Output safety stage: transparent below `threshold`, then bends smoothly
/// toward ±1 so echo/reverb build-ups never hard-clip in the call.
public final class SoftClipper: AudioProcessor {
    private let threshold: Float

    public init(threshold: Float = 0.8) {
        self.threshold = threshold
    }

    public func process(_ buffer: UnsafeMutableBufferPointer<Float>) {
        let headroom = 1 - threshold
        for i in buffer.indices {
            let x = buffer[i]
            let magnitude = abs(x)
            guard magnitude > threshold else { continue }
            // Slope 1 at the threshold, asymptote at 1: no audible kink.
            let bent = threshold + headroom * tanh((magnitude - threshold) / headroom)
            buffer[i] = x < 0 ? -bent : bent
        }
    }

    public func reset() {}
}
