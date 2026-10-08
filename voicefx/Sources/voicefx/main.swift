import DSP

let usage = """
    voicefx — real-time voice effects for calls (mic → effects → BlackHole)

      voicefx run [--mic NAME] [--port 8766] [--preset NAME] [--test-tone]
      voicefx render <preset> in.wav out.wav
      voicefx devices
      voicefx presets
    """

let arguments = Array(CommandLine.arguments.dropFirst())

do {
    switch arguments.first {
    case "run":
        try RunCommand.run(Array(arguments.dropFirst()))
    case "render":
        try RenderCommand.run(Array(arguments.dropFirst()))
    case "devices":
        for device in AudioDevice.all() {
            print("\(device.name)  in:\(device.inputChannels) out:\(device.outputChannels)\(device.isPhysical ? "" : "  (virtual/aggregate)")")
        }
    case "presets":
        print(Preset.allCases.map(\.rawValue).joined(separator: "\n"))
    default:
        print(usage)
    }
} catch {
    Log.fail("\(error)")
}
