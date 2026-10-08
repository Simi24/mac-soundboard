import Foundation

/// Minimal RIFF/WAVE codec for offline renders: reads 16/24-bit PCM or
/// 32-bit float (downmixed to mono), writes 16-bit PCM mono.
struct WavFile {
    var samples: [Float]
    var sampleRate: Double

    enum FormatError: Error, CustomStringConvertible {
        case notWave, missingChunk(String), unsupported(format: Int, bits: Int)

        var description: String {
            switch self {
            case .notWave: "not a RIFF/WAVE file"
            case .missingChunk(let id): "missing '\(id)' chunk"
            case .unsupported(let format, let bits): "unsupported encoding (format \(format), \(bits) bit)"
            }
        }
    }

    init(samples: [Float], sampleRate: Double) {
        self.samples = samples
        self.sampleRate = sampleRate
    }

    init(contentsOf url: URL) throws {
        let bytes = [UInt8](try Data(contentsOf: url))
        guard bytes.count >= 12, Self.tag(bytes, 0) == "RIFF", Self.tag(bytes, 8) == "WAVE" else { throw FormatError.notWave }

        var format: (code: Int, channels: Int, rate: Int, bits: Int)?
        var payload: ArraySlice<UInt8>?
        var offset = 12
        while offset + 8 <= bytes.count {
            let id = Self.tag(bytes, offset)
            let size = Self.integer(bytes, offset + 4, width: 4)
            let body = bytes[(offset + 8)..<min(offset + 8 + size, bytes.count)]
            if id == "fmt " {
                var code = Self.integer(bytes, offset + 8, width: 2)
                if code == 0xFFFE { code = Self.integer(bytes, offset + 32, width: 2) }  // WAVE_FORMAT_EXTENSIBLE
                format = (code, Self.integer(bytes, offset + 10, width: 2),
                          Self.integer(bytes, offset + 12, width: 4), Self.integer(bytes, offset + 22, width: 2))
            } else if id == "data" {
                payload = body
            }
            offset += 8 + size + (size & 1)
        }
        guard let format else { throw FormatError.missingChunk("fmt ") }
        guard let payload else { throw FormatError.missingChunk("data") }

        let width = format.bits / 8
        let frameWidth = width * format.channels
        let decode: (Int) -> Float
        switch (format.code, format.bits) {
        case (1, 16): decode = { Float(Int16(truncatingIfNeeded: Self.integer(bytes, $0, width: 2))) / 32_768 }
        case (1, 24): decode = { Float(Int32(truncatingIfNeeded: Self.integer(bytes, $0, width: 3) << 8) >> 8) / 8_388_608 }
        case (3, 32): decode = { Float(bitPattern: UInt32(Self.integer(bytes, $0, width: 4))) }
        default: throw FormatError.unsupported(format: format.code, bits: format.bits)
        }

        let start = payload.startIndex
        samples = (0..<payload.count / frameWidth).map { frame in
            let base = start + frame * frameWidth
            let sum = (0..<format.channels).reduce(Float(0)) { $0 + decode(base + $1 * width) }
            return sum / Float(format.channels)
        }
        sampleRate = Double(format.rate)
    }

    func write(to url: URL) throws {
        let rate = Int(sampleRate)
        var bytes = [UInt8]()
        func append(_ text: String) { bytes += Array(text.utf8) }
        func append(_ value: Int, width: Int) {
            for i in 0..<width { bytes.append(UInt8((value >> (8 * i)) & 0xFF)) }
        }
        append("RIFF"); append(36 + samples.count * 2, width: 4); append("WAVE")
        append("fmt "); append(16, width: 4); append(1, width: 2); append(1, width: 2)
        append(rate, width: 4); append(rate * 2, width: 4); append(2, width: 2); append(16, width: 2)
        append("data"); append(samples.count * 2, width: 4)
        for sample in samples {
            append(Int(Int16(max(-1, min(1, sample)) * 32_767)), width: 2)
        }
        try Data(bytes).write(to: url)
    }

    private static func tag(_ bytes: [UInt8], _ offset: Int) -> String {
        String(decoding: bytes[offset..<offset + 4], as: UTF8.self)
    }

    /// Little-endian unsigned integer.
    private static func integer(_ bytes: [UInt8], _ offset: Int, width: Int) -> Int {
        (0..<width).reduce(0) { $0 | Int(bytes[offset + $1]) << (8 * $1) }
    }
}
