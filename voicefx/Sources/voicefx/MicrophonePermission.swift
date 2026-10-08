import AVFoundation

/// Without TCC microphone permission CoreAudio does not fail: it delivers
/// digital silence. So ask explicitly and stop with a clear message instead.
enum MicrophonePermission {
    static func ensureGranted() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return
        case .notDetermined:
            let semaphore = DispatchSemaphore(value: 0)
            nonisolated(unsafe) var granted = false
            AVCaptureDevice.requestAccess(for: .audio) {
                granted = $0
                semaphore.signal()
            }
            semaphore.wait()
            if granted { return }
        default:
            break
        }
        Log.fail(
            "microphone permission denied. Allow VoiceFX in System Settings → Privacy & Security → Microphone"
                + " (or reset with: tccutil reset Microphone com.soundboard.voicefx)",
            code: 2
        )
    }
}
