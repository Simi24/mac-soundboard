/// Schroeder allpass: flat magnitude response, smears the phase so the
/// discrete comb echoes blur into a dense tail.
final class AllpassDiffuser {
    private var buffer: [Float]
    private var index = 0
    private let feedback: Float = 0.5

    init(length: Int) {
        buffer = [Float](repeating: 0, count: length)
    }

    @inline(__always)
    func process(_ input: Float) -> Float {
        let delayed = buffer[index]
        buffer[index] = input + delayed * feedback
        index += 1
        if index == buffer.count { index = 0 }
        return delayed - input
    }

    func reset() {
        for i in buffer.indices { buffer[i] = 0 }
        index = 0
    }
}
