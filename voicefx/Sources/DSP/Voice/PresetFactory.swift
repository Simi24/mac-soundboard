/// Builds the effect chain behind each preset. All tuning lives here.
public enum PresetFactory {
    public static func makeChain(_ preset: Preset, sampleRate sr: Double) -> AudioProcessor {
        switch preset {
        case .clean:
            return EffectChain([])

        case .robot:
            // Ring mod kills the pitch; an 8 ms comb adds a metallic 125 Hz buzz.
            return EffectChain([
                RingModulator(frequency: 50, mix: 1, sampleRate: sr),
                Echo(delaySeconds: 0.008, feedback: 0.55, mix: 0.5, sampleRate: sr),
            ])

        case .radio:
            // Narrow 400–3000 Hz band (two cascaded biquads per side for 24 dB/oct),
            // a honky mid bump and an overdriven small speaker.
            return EffectChain([
                Biquad(.highPass, frequency: 400, sampleRate: sr),
                Biquad(.highPass, frequency: 400, sampleRate: sr),
                Biquad(.lowPass, frequency: 3000, sampleRate: sr),
                Biquad(.lowPass, frequency: 3000, sampleRate: sr),
                Biquad(.peaking(gainDB: 6), frequency: 1500, q: 1, sampleRate: sr),
                Saturator(drive: 4, outputGain: 0.5),
            ])

        case .echo:
            return EffectChain([
                Echo(delaySeconds: 0.32, feedback: 0.35, mix: 0.5, sampleRate: sr),
            ])

        case .cathedral:
            return EffectChain([
                Freeverb(roomSize: 0.92, damping: 0.3, wet: 0.35, dry: 0.8, sampleRate: sr),
            ])

        case .chipmunk:
            return EffectChain([
                PhaseVocoderPitchShifter(semitones: 8, sampleRate: sr),
            ])

        case .female:
            // Pitch up a fourth, formants up only ~17% (a shorter vocal tract):
            // moving formants with the pitch would give a chipmunk instead.
            // Less chest, a bit more presence.
            return EffectChain([
                PhaseVocoderPitchShifter(semitones: 5, formantRatio: 1.17, sampleRate: sr),
                Biquad(.highPass, frequency: 140, sampleRate: sr),
                Biquad(.peaking(gainDB: 3), frequency: 3500, q: 0.8, sampleRate: sr),
            ])

        case .demon:
            return EffectChain([
                PhaseVocoderPitchShifter(semitones: -7, sampleRate: sr),
                Biquad(.lowPass, frequency: 2500, sampleRate: sr),
                Saturator(drive: 1.5, outputGain: 0.9),
                Freeverb(roomSize: 0.5, damping: 0.5, wet: 0.15, dry: 0.9, sampleRate: sr),
            ])

        case .alien:
            return EffectChain([
                GranularPitchShifter(semitones: 5, sampleRate: sr),
                RingModulator(frequency: 600, mix: 0.3, sampleRate: sr),
                Echo(delaySeconds: 0.12, feedback: 0.3, mix: 0.3, sampleRate: sr),
            ])
        }
    }
}
