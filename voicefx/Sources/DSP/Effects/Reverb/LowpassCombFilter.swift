/// Feedback comb with a one-pole lowpass in the loop: each echo loses some
/// treble, like sound bouncing off soft walls.
final class LowpassCombFilter {
    private var buffer: [Float]
    private var index = 0
    private var filterState: Float = 0
    private let feedback: Float
    private let damping: Float

    init(length: Int, feedback: Float, damping: Float) {
        buffer = [Float](repeating: 0, count: length)
        self.feedback = feedback
        self.damping = damping
    }

    @inline(__always)
    func process(_ input: Float) -> Float {
        let output = buffer[index]
        filterState = output * (1 - damping) + filterState * damping
        buffer[index] = input + filterState * feedback
        index += 1
        if index == buffer.count { index = 0 }
        return output
    }

    func reset() {
        for i in buffer.indices { buffer[i] = 0 }
        filterState = 0
        index = 0
    }
}
