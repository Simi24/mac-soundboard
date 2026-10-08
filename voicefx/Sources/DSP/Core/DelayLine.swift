/// Circular buffer with fractional (linearly interpolated) reads.
///
/// After `write(x)`, `read(delay: 0)` returns `x`; `read(delay: d)` returns the
/// sample written `d` writes ago.
public final class DelayLine {
    private var buffer: [Float]
    private var writeIndex = 0

    public init(maxDelay: Int) {
        buffer = [Float](repeating: 0, count: maxDelay + 2)
    }

    @inline(__always)
    public func write(_ x: Float) {
        buffer[writeIndex] = x
        writeIndex += 1
        if writeIndex == buffer.count { writeIndex = 0 }
    }

    @inline(__always)
    public func read(delay: Float) -> Float {
        let position = Float(writeIndex - 1) - delay
        let older = Int(position.rounded(.down))
        let fraction = position - Float(older)
        let a = buffer[wrap(older)]
        let b = buffer[wrap(older + 1)]
        return a + (b - a) * fraction
    }

    public func reset() {
        for i in buffer.indices { buffer[i] = 0 }
        writeIndex = 0
    }

    @inline(__always)
    private func wrap(_ index: Int) -> Int {
        let n = buffer.count
        let r = index % n
        return r < 0 ? r + n : r
    }
}
