import CoreAudio
import DSP

/// Everything the real-time IO block touches, preallocated. No allocation,
/// locks or logging in `render`.
final class RenderContext: @unchecked Sendable {
    private let engine: VoiceEngine
    private let scratch: UnsafeMutableBufferPointer<Float>
    /// Aggregate output channels that belong to BlackHole. Outputs of the mic
    /// device (a USB headset, say) come first and are left silent.
    private let targetChannels: Range<Int>
    /// Replaces the mic with a sine, to check the chain without speaking.
    private var testTone: SineOscillator?

    init(engine: VoiceEngine, targetChannels: Range<Int>, testTone: SineOscillator?) {
        self.engine = engine
        self.targetChannels = targetChannels
        self.testTone = testTone
        scratch = .allocate(capacity: 16_384)
        scratch.initialize(repeating: 0)
    }

    deinit {
        scratch.deallocate()
    }

    func render(input: UnsafePointer<AudioBufferList>, output: UnsafeMutablePointer<AudioBufferList>) {
        let outputs = UnsafeMutableAudioBufferListPointer(output)
        guard let reference = outputs.first, reference.mNumberChannels > 0 else { return }
        let frames = min(Int(reference.mDataByteSize) / (Int(reference.mNumberChannels) * 4), scratch.count)
        let voice = UnsafeMutableBufferPointer(rebasing: scratch[0..<frames])

        readMicrophone(input, into: voice)
        engine.render(voice)
        write(voice, to: outputs)
    }

    /// Channel 0 of the first input stream: the mic is the aggregate's first sub-device.
    private func readMicrophone(_ input: UnsafePointer<AudioBufferList>, into voice: UnsafeMutableBufferPointer<Float>) {
        if testTone != nil {
            for i in voice.indices { voice[i] = 0.3 * testTone!.next() }
            return
        }
        let inputs = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        guard let mic = inputs.first, let data = mic.mData, mic.mNumberChannels > 0 else {
            for i in voice.indices { voice[i] = 0 }
            return
        }
        let samples = data.assumingMemoryBound(to: Float.self)
        let stride = Int(mic.mNumberChannels)
        let available = Int(mic.mDataByteSize) / (stride * 4)
        for i in voice.indices {
            voice[i] = i < available ? samples[i * stride] : 0
        }
    }

    private func write(_ voice: UnsafeMutableBufferPointer<Float>, to outputs: UnsafeMutableAudioBufferListPointer) {
        var firstChannel = 0
        for buffer in outputs {
            let channels = Int(buffer.mNumberChannels)
            defer { firstChannel += channels }
            guard let data = buffer.mData, channels > 0 else { continue }
            let samples = data.assumingMemoryBound(to: Float.self)
            let frames = Int(buffer.mDataByteSize) / (channels * 4)
            for channel in 0..<channels {
                let isTarget = targetChannels.contains(firstChannel + channel)
                for i in 0..<frames {
                    samples[i * channels + channel] = isTarget && i < voice.count ? voice[i] : 0
                }
            }
        }
    }
}
