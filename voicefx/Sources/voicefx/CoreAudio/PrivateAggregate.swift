import CoreAudio
import Foundation

/// A process-private aggregate of mic + BlackHole: invisible to other apps,
/// gone when voicefx exits. One device means one IOProc sees input and output
/// in the same callback on a single clock (mic is the clock, BlackHole is
/// drift-compensated), so there is no inter-device buffering or drift.
final class PrivateAggregate {
    let id: AudioDeviceID

    init(microphone: AudioDevice, output: AudioDevice) throws {
        let description: [String: Any] = [
            kAudioAggregateDeviceNameKey: "VoiceFX",
            kAudioAggregateDeviceUIDKey: "com.soundboard.voicefx.\(getpid())",
            kAudioAggregateDeviceIsPrivateKey: 1,
            kAudioAggregateDeviceSubDeviceListKey: [
                [kAudioSubDeviceUIDKey: microphone.uid],
                [kAudioSubDeviceUIDKey: output.uid, kAudioSubDeviceDriftCompensationKey: 1],
            ],
            kAudioAggregateDeviceMainSubDeviceKey: microphone.uid,
        ]
        var id: AudioDeviceID = 0
        let status = AudioHardwareCreateAggregateDevice(description as CFDictionary, &id)
        guard status == noErr else { throw CoreAudioError(status, "AudioHardwareCreateAggregateDevice") }
        self.id = id
    }

    var device: AudioDevice { AudioDevice(id: id) }

    func destroy() {
        AudioHardwareDestroyAggregateDevice(id)
    }
}

struct CoreAudioError: Error, CustomStringConvertible {
    let status: OSStatus
    let call: String

    init(_ status: OSStatus, _ call: String) {
        self.status = status
        self.call = call
    }

    var description: String { "\(call) failed with OSStatus \(status)" }
}
