import Foundation

/// stderr logging. When launched as an app bundle, start.sh redirects it to a file.
enum Log {
    static func info(_ message: String) {
        FileHandle.standardError.write(Data("[voicefx] \(message)\n".utf8))
    }

    static func fail(_ message: String, code: Int32 = 1) -> Never {
        info("ERROR: \(message)")
        exit(code)
    }
}
