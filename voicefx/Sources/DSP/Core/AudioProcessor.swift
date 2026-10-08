/// A mono audio stage that transforms a buffer in place.
///
/// `process` runs on the real-time CoreAudio thread: implementations must not
/// allocate, lock, or log there. Everything is preallocated in `init`.
public protocol AudioProcessor: AnyObject {
    func process(_ buffer: UnsafeMutableBufferPointer<Float>)
    /// Clears internal state (delay lines, filter memory) without allocating.
    func reset()
}
