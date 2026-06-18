import Foundation
import SwiftUI
import Combine

/// The flow Pickle moves through. The panel renders one stage at a time.
enum PitchStage: Equatable {
    case welcome       // pick a length / see Pickle
    case recording
    case analyzing
    case results
    case history
    case settings
}

/// Central app state + coordinator. Owns the recorder, the store, the analysis
/// pipeline, and the current flow. Both the companion and the panel observe it.
@MainActor
final class AppState: ObservableObject {

    // Flow
    @Published var stage: PitchStage = .welcome
    @Published var panelVisible = false
    @Published var selectedLength: PitchLength = .demoDay

    // Live + result
    @Published var transcriptPreview: String = ""
    @Published var result: SessionRecord?
    @Published var errorMessage: String?
    @Published var isNewBest = false

    // Config
    @Published var hasAPIKey: Bool

    // Companion jelly wobble (-1…1), set during a drag; the mascot leans + stretches.
    @Published var jelly: CGFloat = 0

    // Drag wiring — set by AppDelegate, which owns the companion window.
    var onCompanionDragBegan: (() -> Void)?
    var onCompanionDrag: ((_ globalMouseX: CGFloat, _ velocityX: CGFloat) -> Void)?
    var onCompanionDragEnded: (() -> Void)?

    let recorder = AudioRecorder()
    let store = SessionStore()

    private var analyzeTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init() {
        hasAPIKey = Keychain.load() != nil
        // Re-publish nested ObservableObject changes (live mic level, session
        // list) so views observing AppState refresh — SwiftUI doesn't bridge
        // nested ObservableObjects automatically.
        recorder.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        store.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: Mood (drives the mascot everywhere)

    var mood: MascotMood {
        switch stage {
        case .welcome:   return result == nil ? .idle : .curious
        case .recording: return .listening
        case .analyzing: return .thinking
        case .results:
            guard let s = result?.analysis.overallScore else { return .curious }
            if isNewBest { return .celebrating }
            switch s {
            case 75...:  return .impressed
            case 50..<75: return .skeptical
            default:     return .roasting
            }
        case .history:   return .curious
        case .settings:  return .idle
        }
    }

    // MARK: Panel control

    func togglePanel() {
        panelVisible.toggle()
        if panelVisible && stage == .results { /* keep showing last result */ }
    }

    func showPanel() { panelVisible = true }
    func hidePanel() { panelVisible = false }

    // MARK: Recording flow

    func startRecording() {
        guard hasAPIKey else { stage = .settings; showPanel(); return }
        errorMessage = nil
        transcriptPreview = ""
        Task {
            let ok = await recorder.start(maxSeconds: selectedLength.maxSeconds)
            if ok {
                stage = .recording
            } else {
                errorMessage = "Pickle can't hear you — grant microphone access in System Settings → Privacy → Microphone."
            }
        }
    }

    func cancelRecording() {
        recorder.discard()
        stage = .welcome
    }

    /// Stop recording and kick off transcription + analysis.
    func finishRecording() {
        guard let url = recorder.stop() else { stage = .welcome; return }
        let seconds = recorder.elapsed
        let length = selectedLength
        stage = .analyzing

        analyzeTask?.cancel()
        analyzeTask = Task {
            let analyzer = PitchAnalyzer(
                transcriber: SpeechTranscriber(),
                client: ClaudeClient(apiKey: Keychain.load())
            )
            do {
                let record = try await analyzer.run(
                    audioURL: url, length: length, spokenSeconds: seconds,
                    onTranscript: { [weak self] text in
                        Task { @MainActor in self?.transcriptPreview = text }
                    })
                guard !Task.isCancelled else { return }
                let prevBest = store.bestOverall
                store.add(record)
                isNewBest = record.analysis.overallScore > prevBest && store.sessions.count > 1
                result = record
                stage = .results
                try? FileManager.default.removeItem(at: url)
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                stage = .welcome
            }
        }
    }

    // MARK: Navigation

    func goWelcome() { stage = .welcome }
    func goHistory() { stage = .history }
    func goSettings() { stage = .settings }
    func practiceAgain() { result = nil; isNewBest = false; stage = .welcome }

    // MARK: Settings

    func saveAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Keychain.save(trimmed)
        hasAPIKey = true
        errorMessage = nil
    }

    func clearAPIKey() {
        Keychain.clear()
        hasAPIKey = false
    }
}
