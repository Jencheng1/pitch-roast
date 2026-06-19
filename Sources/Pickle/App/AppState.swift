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
    @Published private(set) var navStack: [PitchStage] = []   // back history
    @Published var panelVisible = false
    @Published var expanded = false                 // taller workspace mode
    @Published var selectedLength: PitchLength = .demoDay

    // Live + result
    @Published var transcriptPreview: String = ""
    @Published var result: SessionRecord?
    @Published var errorMessage: String?
    @Published var isNewBest = false

    // Config — provider + keys
    @Published var provider: AnalysisProviderKind
    @Published var openAIKeyPresent: Bool
    @Published var claudeKeyPresent: Bool
    @Published var speakFeedback: Bool

    /// Analysis is gated on the selected provider's key. Transcription + voice
    /// always have an on-device fallback, so they never block on their own.
    var canAnalyze: Bool {
        switch provider {
        case .openai: return openAIKeyPresent
        case .claude: return claudeKeyPresent
        }
    }

    // Companion jelly wobble (-1…1), set during a drag; the mascot leans + stretches.
    @Published var jelly: CGFloat = 0

    // Idle-wander hop transforms (driven by AppDelegate's wander timer).
    @Published var hopLift: CGFloat = 0      // vertical offset, negative = airborne
    @Published var hopStretch: CGFloat = 0   // + stretch tall (takeoff) / − squash flat (landing)
    @Published var hopLean: CGFloat = 0      // −1…1 lean + rotation toward travel

    // Drag wiring — set by AppDelegate, which owns the companion window.
    var onCompanionDragBegan: (() -> Void)?
    var onCompanionDrag: ((_ globalMouseX: CGFloat, _ velocityX: CGFloat) -> Void)?
    var onCompanionDragEnded: (() -> Void)?

    let recorder = AudioRecorder()
    let store = SessionStore()
    let voice = VoiceCoach()

    private var analyzeTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init() {
        // OpenAI is the default analysis provider for new users.
        provider = UserDefaults.standard.string(forKey: "analysisProvider")
            .flatMap(AnalysisProviderKind.init(rawValue:)) ?? .openai
        openAIKeyPresent = Keychain.load(.openAI) != nil
        claudeKeyPresent = Keychain.load(.anthropic) != nil
        speakFeedback = UserDefaults.standard.object(forKey: "speakFeedback") as? Bool ?? true

        // Re-publish nested ObservableObject changes (live mic level, session
        // list, speaking state) so views observing AppState refresh — SwiftUI
        // doesn't bridge nested ObservableObjects automatically.
        for child in [recorder.objectWillChange.eraseToAnyPublisher(),
                      store.objectWillChange.eraseToAnyPublisher(),
                      voice.objectWillChange.eraseToAnyPublisher()] {
            child.sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &cancellables)
        }
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
    func toggleExpand() { expanded.toggle() }

    // MARK: Idle wandering — the hop choreography

    /// A single hop, driven by spring physics in four beats: anticipation
    /// (lean + stretch up), airborne (rise in an arc with subtle rotation),
    /// landing (drop + squash), and settle (spring back home with a wobble).
    /// `direction` is −1 (left) or +1 (right). The window's horizontal travel is
    /// timed by `AppDelegate` to land within the airborne beat.
    func playHop(direction: CGFloat) {
        // 1 · Takeoff — coil toward the direction and stretch upward.
        withAnimation(.spring(response: 0.16, dampingFraction: 0.55)) {
            hopLean = direction
            hopStretch = 0.55
        }
        // 2 · Airborne — rise in a bounce arc, easing the stretch, slight rotation.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self else { return }
            withAnimation(.spring(response: 0.30, dampingFraction: 0.60)) {
                self.hopLift = -28
                self.hopStretch = 0.20
                self.hopLean = direction * 0.7
            }
        }
        // 3 · Landing — come down and squash on impact.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) { [weak self] in
            guard let self else { return }
            withAnimation(.spring(response: 0.20, dampingFraction: 0.50)) {
                self.hopLift = 0
                self.hopStretch = -0.50
                self.hopLean = direction * 0.2
            }
        }
        // 4 · Settle — spring back to his normal shape with a playful wobble.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.60) { [weak self] in
            guard let self else { return }
            withAnimation(.spring(response: 0.50, dampingFraction: 0.42)) {
                self.hopStretch = 0
                self.hopLean = 0
            }
        }
    }

    // MARK: Recording flow

    func startRecording() {
        guard canAnalyze else { navigate(to: .settings); showPanel(); return }
        voice.stop()
        errorMessage = nil
        transcriptPreview = ""
        navStack = []                 // a new pitch starts a fresh flow
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

        let openAIKey = Keychain.load(.openAI)
        analyzeTask?.cancel()
        analyzeTask = Task {
            let analyzer = PitchAnalyzer(
                transcriber: makeTranscriber(openAIKey: openAIKey),
                provider: makeProvider(openAIKey: openAIKey)
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
                navStack = []           // a freshly analyzed verdict has no "back"
                stage = .results
                if speakFeedback { voice.speak(record.analysis.roast, openAIKey: openAIKey) }
                try? FileManager.default.removeItem(at: url)
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                stage = .welcome
            }
        }
    }

    // MARK: Navigation

    /// Navigate, remembering where we came from so the back arrow can return.
    func navigate(to s: PitchStage) {
        guard s != stage else { return }
        navStack.append(stage)
        stage = s
    }

    var canGoBack: Bool { !navStack.isEmpty }

    func goBack() {
        guard let previous = navStack.popLast() else { return }
        stage = previous
    }

    func goWelcome() { navigate(to: .welcome) }
    func goHistory() { navigate(to: .history) }
    func goSettings() { navigate(to: .settings) }

    /// Open a saved run's verdict (from the welcome strip or history list).
    func openRecord(_ record: SessionRecord) {
        result = record
        isNewBest = false
        navigate(to: .results)
    }

    func practiceAgain() {
        voice.stop(); result = nil; isNewBest = false
        navStack = []; stage = .welcome          // start a fresh flow
    }

    /// Re-speak the current roast (the speaker button on the results screen).
    func replayVoice() {
        guard let roast = result?.analysis.roast else { return }
        if voice.isSpeaking { voice.stop() }
        else { voice.speak(roast, openAIKey: Keychain.load(.openAI)) }
    }

    // MARK: Engine selection

    private func makeTranscriber(openAIKey: String?) -> Transcriber {
        if let key = openAIKey, !key.isEmpty { return OpenAITranscriber(apiKey: key) }
        return SpeechTranscriber()                       // on-device fallback
    }

    private func makeProvider(openAIKey: String?) -> AnalysisProvider {
        switch provider {
        case .openai: return OpenAIClient(apiKey: openAIKey)
        case .claude: return ClaudeClient(apiKey: Keychain.load(.anthropic))
        }
    }

    // MARK: Settings

    func setProvider(_ p: AnalysisProviderKind) {
        provider = p
        UserDefaults.standard.set(p.rawValue, forKey: "analysisProvider")
        errorMessage = nil
    }

    func setSpeakFeedback(_ on: Bool) {
        speakFeedback = on
        UserDefaults.standard.set(on, forKey: "speakFeedback")
        if !on { voice.stop() }
    }

    func saveOpenAIKey(_ key: String) {
        let t = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        Keychain.save(t, for: .openAI); openAIKeyPresent = true; errorMessage = nil
    }
    func clearOpenAIKey() { Keychain.clear(.openAI); openAIKeyPresent = false }

    func saveClaudeKey(_ key: String) {
        let t = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        Keychain.save(t, for: .anthropic); claudeKeyPresent = true; errorMessage = nil
    }
    func clearClaudeKey() { Keychain.clear(.anthropic); claudeKeyPresent = false }
}
