import Foundation
import AVFoundation
import Combine
import SwiftUI   // withAnimation

/// Records the pitch to a temp `.m4a`, publishing a normalized live level (for
/// the mascot's reactive mouth + waveform) and elapsed time. Auto-stops at the
/// format's max duration.
@MainActor
final class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var level: CGFloat = 0          // 0…1 smoothed
    @Published var elapsed: TimeInterval = 0
    @Published var permissionDenied = false

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var startedAt: Date?
    private(set) var fileURL: URL?
    private var maxSeconds: Int = 120

    /// Request mic access and begin recording. Returns false if denied.
    @discardableResult
    func start(maxSeconds: Int) async -> Bool {
        self.maxSeconds = maxSeconds
        let granted = await Self.requestMic()
        guard granted else { permissionDenied = true; return false }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pickle-\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let rec = try AVAudioRecorder(url: url, settings: settings)
            rec.isMeteringEnabled = true
            rec.delegate = self
            guard rec.prepareToRecord(), rec.record() else { return false }
            recorder = rec
            fileURL = url
            startedAt = Date()
            elapsed = 0
            isRecording = true
            startMetering()
            return true
        } catch {
            return false
        }
    }

    /// Stop and return the recorded file URL.
    @discardableResult
    func stop() -> URL? {
        guard isRecording else { return fileURL }
        recorder?.stop()
        timer?.invalidate(); timer = nil
        isRecording = false
        withAnimation { level = 0 }
        return fileURL
    }

    func discard() {
        _ = stop()
        if let url = fileURL { try? FileManager.default.removeItem(at: url) }
        fileURL = nil
    }

    var remaining: Int { max(0, maxSeconds - Int(elapsed)) }

    // MARK: Metering

    private func startMetering() {
        let t = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        guard let recorder, isRecording else { return }
        recorder.updateMeters()
        // dBFS (-160…0) → 0…1, perceptual.
        let db = recorder.averagePower(forChannel: 0)
        let norm = max(0, (db + 55) / 55)
        let shaped = CGFloat(pow(Double(norm), 1.6))
        level += (shaped - level) * 0.3   // smoothing
        elapsed = startedAt.map { Date().timeIntervalSince($0) } ?? 0
        if Int(elapsed) >= maxSeconds { _ = stop() }
    }

    // MARK: Mic permission

    static func requestMic() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return true
        case .notDetermined:
            return await withCheckedContinuation { cont in
                AVCaptureDevice.requestAccess(for: .audio) { cont.resume(returning: $0) }
            }
        default: return false
        }
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in self.isRecording = false }
    }
}
