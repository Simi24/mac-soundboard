/// Runs stages in series. An empty chain is a clean passthrough.
public final class EffectChain: AudioProcessor {
    private let stages: [AudioProcessor]

    public init(_ stages: [AudioProcessor]) {
        self.stages = stages
    }

    public func process(_ buffer: UnsafeMutableBufferPointer<Float>) {
        for stage in stages { stage.process(buffer) }
    }

    public func reset() {
        for stage in stages { stage.reset() }
    }
}
