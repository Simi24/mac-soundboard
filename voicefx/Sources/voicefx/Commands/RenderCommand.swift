import DSP
import Foundation

/// `voicefx render <preset> in.wav out.wav`: apply a preset offline, to tune
/// effects by ear without being in a call.
enum RenderCommand {
    static func run(_ arguments: [String]) throws {
        guard arguments.count == 3, let preset = Preset(rawValue: arguments[0]) else {
            Log.fail("usage: voicefx render <\(Preset.allCases.map(\.rawValue).joined(separator: "|"))> in.wav out.wav")
        }
        var wav = try WavFile(contentsOf: URL(fileURLWithPath: arguments[1]))
        let chain = EffectChain([
            NoiseGate(sampleRate: wav.sampleRate),
            PresetFactory.makeChain(preset, sampleRate: wav.sampleRate),
            SoftClipper(),
        ])

        let block = 256
        wav.samples.withUnsafeMutableBufferPointer { all in
            for start in stride(from: 0, to: all.count, by: block) {
                chain.process(UnsafeMutableBufferPointer(rebasing: all[start..<min(start + block, all.count)]))
            }
        }
        try wav.write(to: URL(fileURLWithPath: arguments[2]))
        Log.info("rendered \(preset.rawValue): \(wav.samples.count) samples @ \(Int(wav.sampleRate)) Hz → \(arguments[2])")
    }
}
