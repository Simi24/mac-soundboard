import Synchronization

/// Real-time voice processor: one prebuilt chain per preset, switched with a
/// short fade so changing voice never clicks.
///
/// Threading: `render` runs only on the audio thread; `select` and `preset`
/// are safe from any thread (atomic). Chains are all built up front, so the
/// audio thread never allocates.
public final class VoiceEngine: @unchecked Sendable {
    private let chains: [AudioProcessor]
    /// Runs before every preset, clean included: effects make mic hiss audible.
    private let gate: NoiseGate
    private let clipper = SoftClipper()
    private let requested = Atomic<Int>(Preset.clean.index)
    private var current = Preset.clean.index
    private var fadingIn = false

    public init(sampleRate: Double) {
        chains = Preset.allCases.map { PresetFactory.makeChain($0, sampleRate: sampleRate) }
        gate = NoiseGate(sampleRate: sampleRate)
    }

    public func select(_ preset: Preset) {
        requested.store(preset.index, ordering: .relaxed)
    }

    public var preset: Preset {
        Preset.allCases[requested.load(ordering: .relaxed)]
    }

    public func render(_ buffer: UnsafeMutableBufferPointer<Float>) {
        let target = requested.load(ordering: .relaxed)
        gate.process(buffer)
        chains[current].process(buffer)

        if target != current {
            // Fade the old voice out over this buffer, start the new one silent.
            ramp(buffer, from: 1, to: 0)
            current = target
            chains[current].reset()
            fadingIn = true
        } else if fadingIn {
            ramp(buffer, from: 0, to: 1)
            fadingIn = false
        }
        clipper.process(buffer)
    }

    private func ramp(_ buffer: UnsafeMutableBufferPointer<Float>, from start: Float, to end: Float) {
        guard buffer.count > 0 else { return }
        let step = (end - start) / Float(buffer.count)
        for i in buffer.indices {
            buffer[i] *= start + step * Float(i)
        }
    }
}
