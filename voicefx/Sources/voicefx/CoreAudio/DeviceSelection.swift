/// Picks the devices voicefx bridges: a real microphone in, BlackHole out.
enum DeviceSelection {
    /// `--mic` substring if given, else the system default input if it is a
    /// real mic, else the first real mic found.
    static func microphone(matching name: String?) -> AudioDevice? {
        let mics = AudioDevice.all().filter { $0.inputChannels > 0 && $0.isPhysical }
        if let name {
            return mics.first { $0.name.localizedCaseInsensitiveContains(name) }
        }
        if let preferred = AudioDevice.defaultInput(), mics.contains(preferred) {
            return preferred
        }
        return mics.first
    }

    static func blackHole() -> AudioDevice? {
        AudioDevice.all().first { $0.name.contains("BlackHole") && $0.outputChannels >= 2 }
    }
}
