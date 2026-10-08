import DSP
import Foundation

/// `voicefx run [--mic NAME] [--port N] [--preset NAME] [--test-tone]`:
/// live mic → effects → BlackHole until SIGINT/SIGTERM.
enum RunCommand {
    static let bufferFrames: UInt32 = 256

    struct Options {
        var micName: String?
        var port: UInt16 = 8766
        var preset: Preset = .clean
        var testTone = false
    }

    static func run(_ arguments: [String]) throws {
        let options = parse(arguments)

        guard let mic = DeviceSelection.microphone(matching: options.micName) else {
            Log.fail("no physical microphone found" + (options.micName.map { " matching '\($0)'" } ?? ""))
        }
        guard let blackHole = DeviceSelection.blackHole() else {
            Log.fail("BlackHole not found: run setup/setup.sh (driver not loaded?)")
        }
        MicrophonePermission.ensureGranted()

        let aggregate = try PrivateAggregate(microphone: mic, output: blackHole)
        let sampleRate = aggregate.device.nominalSampleRate
        let engine = VoiceEngine(sampleRate: sampleRate)
        engine.select(options.preset)

        let control: ControlServer
        do {
            control = try ControlServer(port: options.port, engine: engine)
        } catch {
            aggregate.destroy()
            Log.fail("cannot bind UDP 127.0.0.1:\(options.port) — is voicefx already running?")
        }

        let firstTarget = mic.outputChannels
        let context = RenderContext(
            engine: engine,
            targetChannels: firstTarget..<firstTarget + 2,
            testTone: options.testTone ? SineOscillator(frequency: 440, sampleRate: sampleRate) : nil
        )
        let io = try DuplexIO(device: aggregate.device, bufferFrames: bufferFrames, context: context)
        try io.start()
        control.start()

        let bufferMs = Double(bufferFrames) / sampleRate * 1000
        Log.info("running: '\(mic.name)' → '\(blackHole.name)' @ \(Int(sampleRate)) Hz, buffer \(bufferFrames) (\(String(format: "%.1f", bufferMs)) ms)")
        Log.info("control on udp://127.0.0.1:\(options.port), voice: \(engine.preset.rawValue)" + (options.testTone ? ", TEST TONE instead of mic" : ""))

        stopOnSignals {
            io.stop()
            aggregate.destroy()
            Log.info("stopped")
        }
        dispatchMain()
    }

    private static func parse(_ arguments: [String]) -> Options {
        var options = Options()
        var iterator = arguments.makeIterator()
        while let flag = iterator.next() {
            switch flag {
            case "--mic": options.micName = iterator.next()
            case "--port": options.port = iterator.next().flatMap(UInt16.init) ?? options.port
            case "--preset":
                guard let name = iterator.next(), let preset = Preset(rawValue: name) else { Log.fail("unknown --preset") }
                options.preset = preset
            case "--test-tone": options.testTone = true
            default: Log.fail("unknown option \(flag)")
            }
        }
        return options
    }

    private static func stopOnSignals(_ cleanup: @escaping () -> Void) {
        for sig in [SIGINT, SIGTERM] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler {
                cleanup()
                exit(0)
            }
            source.resume()
            retainedSources.append(source)
        }
    }

    nonisolated(unsafe) private static var retainedSources: [DispatchSourceSignal] = []
}
