import CoreAudio

/// Runs a RenderContext as the IOProc of a device (input and output together).
final class DuplexIO {
    private let deviceID: AudioDeviceID
    private var procID: AudioDeviceIOProcID?

    init(device: AudioDevice, bufferFrames: UInt32, context: RenderContext) throws {
        deviceID = device.id

        var frames = bufferFrames
        var address = AudioDevice.address(kAudioDevicePropertyBufferFrameSize)
        let sizeStatus = AudioObjectSetPropertyData(deviceID, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &frames)
        guard sizeStatus == noErr else { throw CoreAudioError(sizeStatus, "set BufferFrameSize") }

        // nil queue: the block runs directly on the HAL's real-time IO thread.
        let status = AudioDeviceCreateIOProcIDWithBlock(&procID, deviceID, nil) { _, input, _, output, _ in
            context.render(input: input, output: output)
        }
        guard status == noErr else { throw CoreAudioError(status, "AudioDeviceCreateIOProcIDWithBlock") }
    }

    func start() throws {
        let status = AudioDeviceStart(deviceID, procID)
        guard status == noErr else { throw CoreAudioError(status, "AudioDeviceStart") }
    }

    func stop() {
        AudioDeviceStop(deviceID, procID)
        if let procID { AudioDeviceDestroyIOProcID(deviceID, procID) }
        procID = nil
    }
}
