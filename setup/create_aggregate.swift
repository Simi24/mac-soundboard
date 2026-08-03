import CoreAudio
import Foundation

func allDevices() -> [AudioDeviceID] {
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else { return [] }
    var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
    guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids) == noErr else { return [] }
    return ids
}

func stringProp(_ id: AudioDeviceID, _ selector: AudioObjectPropertySelector) -> String? {
    var address = AudioObjectPropertyAddress(
        mSelector: selector,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)
    var size = UInt32(MemoryLayout<CFString?>.size)
    var value: Unmanaged<CFString>? = nil
    let err = withUnsafeMutablePointer(to: &value) { ptr in
        AudioObjectGetPropertyData(id, &address, 0, nil, &size, ptr)
    }
    guard err == noErr, let v = value else { return nil }
    return v.takeRetainedValue() as String
}

func hasInputChannels(_ id: AudioDeviceID) -> Bool {
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyStreamConfiguration,
        mScope: kAudioDevicePropertyScopeInput,
        mElement: kAudioObjectPropertyElementMain)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr, size > 0 else { return false }
    let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(size))
    defer { bufferList.deallocate() }
    guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, bufferList) == noErr else { return false }
    return UnsafeMutableAudioBufferListPointer(bufferList).reduce(0) { $0 + Int($1.mNumberChannels) } > 0
}

let aggregateName = "Mic + Soundboard"
let aggregateUID = "com.soundboard.mic-aggregate"

var micUID: String?
var blackholeUID: String?

for id in allDevices() {
    guard let name = stringProp(id, kAudioObjectPropertyName),
          let uid = stringProp(id, kAudioDevicePropertyDeviceUID) else { continue }
    if name == aggregateName || uid == aggregateUID {
        print("EXISTS: il dispositivo aggregato esiste già (id \(id))")
        exit(0)
    }
    if name.contains("BlackHole") {
        blackholeUID = uid
    } else if hasInputChannels(id), micUID == nil, !name.contains("Aggregate") {
        micUID = uid
        print("Microfono trovato: \(name) [\(uid)]")
    }
}

guard let mic = micUID else { print("ERROR: nessun microfono trovato"); exit(1) }
guard let bh = blackholeUID else { print("ERROR: BlackHole non trovato (driver non caricato?)"); exit(1) }
print("BlackHole trovato: [\(bh)]")

let description: [String: Any] = [
    kAudioAggregateDeviceNameKey as String: aggregateName,
    kAudioAggregateDeviceUIDKey as String: aggregateUID,
    kAudioAggregateDeviceSubDeviceListKey as String: [
        [kAudioSubDeviceUIDKey as String: mic],
        [kAudioSubDeviceUIDKey as String: bh,
         kAudioSubDeviceDriftCompensationKey as String: 1],
    ],
    kAudioAggregateDeviceMasterSubDeviceKey as String: mic,
]

var aggregateID: AudioDeviceID = 0
let status = AudioHardwareCreateAggregateDevice(description as CFDictionary, &aggregateID)
if status == noErr {
    print("OK: creato '\(aggregateName)' (id \(aggregateID))")
} else {
    print("ERROR: AudioHardwareCreateAggregateDevice fallita con status \(status)")
    exit(1)
}
