import Foundation

/// tanh waveshaper: soft clipping that adds odd harmonics (overdriven speaker).
public final class Saturator: AudioProcessor {
    private let drive: Float
    private let outputGain: Float

    public init(drive: Float, outputGain: Float) {
        self.drive = drive
        self.outputGain = outputGain
    }

    public func process(_ buffer: UnsafeMutableBufferPointer<Float>) {
        for i in buffer.indices {
            buffer[i] = tanh(buffer[i] * drive) * outputGain
        }
    }

    public func reset() {}
}
