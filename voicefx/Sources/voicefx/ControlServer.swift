import DSP
import Foundation

/// One-line UDP protocol on 127.0.0.1, used by server.py:
///   "status"      → "ok <current> <preset,preset,...>"
///   "<preset>"    → switches voice, same reply
///   anything else → "error unknown command: <text>"
final class ControlServer: @unchecked Sendable {
    private let engine: VoiceEngine
    private let socketFD: Int32

    /// Fails if the port is taken, which also means another voicefx is running.
    init(port: UInt16, engine: VoiceEngine) throws {
        self.engine = engine
        socketFD = socket(AF_INET, SOCK_DGRAM, 0)
        guard socketFD >= 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }

        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(socketFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0 else {
            close(socketFD)
            throw POSIXError(.init(rawValue: errno) ?? .EADDRINUSE)
        }
    }

    func start() {
        Thread { [self] in serve() }.start()
    }

    func handle(_ command: String) -> String {
        if command != "status" {
            guard let preset = Preset(rawValue: command) else { return "error unknown command: \(command)" }
            engine.select(preset)
            Log.info("voice → \(preset.rawValue)")
        }
        let all = Preset.allCases.map(\.rawValue).joined(separator: ",")
        return "ok \(engine.preset.rawValue) \(all)"
    }

    private func serve() {
        var message = [UInt8](repeating: 0, count: 256)
        while true {
            var sender = sockaddr_storage()
            var senderLength = socklen_t(MemoryLayout<sockaddr_storage>.size)
            let received = withUnsafeMutablePointer(to: &sender) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    recvfrom(socketFD, &message, message.count, 0, $0, &senderLength)
                }
            }
            guard received > 0 else { continue }

            let command = String(decoding: message[0..<received], as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let reply = Array(handle(command).utf8)
            _ = withUnsafePointer(to: &sender) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    sendto(socketFD, reply, reply.count, 0, $0, senderLength)
                }
            }
        }
    }
}
