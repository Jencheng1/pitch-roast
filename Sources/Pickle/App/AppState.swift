import Foundation
import SwiftUI
import Combine

/// The flow Pickle moves through. The panel renders one stage at a time.
enum PitchStage: Equatable {
    case welcome       // pick a length / see Pickle
    case recording
    case analyzing
    case results
    case brainDumpResults
    case history
    case settings
}

/// Pitch practice vs. freeform brain dump — chosen on the welcome screen.
enum AppMode: Equatable {
    case pitch
    case brainDump
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
    @Published var mode: AppMode = .pitch           // pitch practice vs. brain dump

    // Live + result
    @Published var transcriptPreview: String = ""
    @Published var result: SessionRecord?
    @Published var brainResult: BrainDumpSynthesis? // latest brain-dump synthesis
    @Published var brainTranscript: String = ""
    @Published var brainTurns: [BrainDumpTurn] = []  // follow-up replies on the current dump
    @Published var currentDumpID: UUID?             // the brain dump being viewed
    @Published var isAddingOn = false               // true while replying to an add-on
    private var continuingDumpID: UUID?             // set while adding on to a dump
    @Published var errorMessage: String?
    @Published var isNewBest = false

    /// Max recording length for a brain dump — long and unhurried.
    private let brainDumpMaxSeconds = 600

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
    let brainStore = BrainDumpStore()
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
                      brainStore.objectWillChange.eraseToAnyPublisher(),
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
        case .brainDumpResults:
            return (brainResult?.topIdea?.conviction ?? 0) >= 70 ? .impressed : .curious
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
        mode = .pitch
        beginCapture(maxSeconds: selectedLength.maxSeconds)
    }

    /// Begin a fresh, standalone brain dump.
    func startBrainDump() {
        mode = .brainDump
        currentDumpID = nil
        continuingDumpID = nil
        isAddingOn = false
        brainTurns = []
        beginCapture(maxSeconds: brainDumpMaxSeconds)
    }

    /// Add more thinking onto an existing brain dump — records again, then
    /// Pickle *replies* to the new thought (the synthesis stays as-is).
    func continueBrainDump(_ record: BrainDumpRecord) {
        mode = .brainDump
        currentDumpID = record.id
        continuingDumpID = record.id
        isAddingOn = true
        brainResult = record.synthesis
        brainTranscript = record.transcript
        brainTurns = record.turns
        beginCapture(maxSeconds: brainDumpMaxSeconds)
    }

    /// Add more to the brain dump currently on screen (results action bar).
    func addMoreToCurrent() {
        if let id = currentDumpID, let rec = brainStore.record(id) {
            continueBrainDump(rec)
        } else {
            startBrainDump()
        }
    }

    private func beginCapture(maxSeconds: Int) {
        guard canAnalyze else { navigate(to: .settings); showPanel(); return }
        voice.stop()
        errorMessage = nil
        transcriptPreview = ""
        navStack = []                 // a new run starts a fresh flow
        Task {
            let ok = await recorder.start(maxSeconds: maxSeconds)
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

    /// Stop recording and kick off the right pipeline for the current mode.
    func finishRecording() {
        guard let url = recorder.stop() else { stage = .welcome; return }
        let seconds = recorder.elapsed
        stage = .analyzing
        let openAIKey = Keychain.load(.openAI)

        if mode == .brainDump {
            if continuingDumpID != nil {
                runBrainReply(url: url, seconds: seconds, openAIKey: openAIKey)
            } else {
                runBrainSynthesis(url: url, seconds: seconds, openAIKey: openAIKey)
            }
        } else {
            runPitchAnalysis(url: url, seconds: seconds, openAIKey: openAIKey)
        }
    }

    private func runPitchAnalysis(url: URL, seconds: Double, openAIKey: String?) {
        let length = selectedLength
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

    /// Fresh brain dump → full structured synthesis (saved as a new record).
    private func runBrainSynthesis(url: URL, seconds: Double, openAIKey: String?) {
        analyzeTask?.cancel()
        analyzeTask = Task {
            let analyzer = PitchAnalyzer(
                transcriber: makeTranscriber(openAIKey: openAIKey),
                provider: makeProvider(openAIKey: openAIKey)
            )
            do {
                let (transcript, synthesis) = try await analyzer.brainDump(
                    audioURL: url, spokenSeconds: seconds,
                    onTranscript: { [weak self] text in
                        Task { @MainActor in self?.transcriptPreview = text }
                    })
                guard !Task.isCancelled else { return }
                let rec = BrainDumpRecord(
                    durationSeconds: seconds, transcript: transcript, synthesis: synthesis)
                brainStore.add(rec)
                currentDumpID = rec.id
                isAddingOn = false
                brainTranscript = transcript
                brainTurns = []
                brainResult = synthesis
                navStack = []
                stage = .brainDumpResults
                if speakFeedback { voice.speak(synthesis.headline, openAIKey: openAIKey) }
                try? FileManager.default.removeItem(at: url)
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                stage = .welcome
            }
        }
    }

    /// Adding on → Pickle replies to the new thought only; the synthesis is left
    /// alone, the reply is appended to the dump's thread.
    private func runBrainReply(url: URL, seconds: Double, openAIKey: String?) {
        guard let id = continuingDumpID, let existing = brainStore.record(id) else {
            runBrainSynthesis(url: url, seconds: seconds, openAIKey: openAIKey); return
        }
        let context = replyContext(for: existing)
        analyzeTask?.cancel()
        analyzeTask = Task {
            let transcriber = makeTranscriber(openAIKey: openAIKey)
            let provider = makeProvider(openAIKey: openAIKey)
            do {
                let raw = try await transcriber.transcribe(url: url)
                let newThought = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard newThought.count >= 4 else { throw PitchAnalyzer.AnalyzerError.emptyTranscript }
                guard !Task.isCancelled else { return }
                transcriptPreview = newThought

                let reply = try await provider.reply(context: context, newThought: newThought)
                guard !Task.isCancelled else { return }

                var updated = existing
                updated.transcript += "\n\n" + newThought
                updated.durationSeconds += seconds
                var turns = updated.turns
                turns.append(BrainDumpTurn(you: newThought, pickle: reply))
                updated.thread = turns
                brainStore.update(updated)

                currentDumpID = id
                continuingDumpID = nil
                isAddingOn = false
                brainResult = updated.synthesis        // unchanged
                brainTranscript = updated.transcript
                brainTurns = turns
                navStack = []
                stage = .brainDumpResults
                if speakFeedback { voice.speak(reply, openAIKey: openAIKey) }
                try? FileManager.default.removeItem(at: url)
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                stage = .welcome
            }
        }
    }

    /// A compact context string for the reply: where their thinking stands plus
    /// the last couple of exchanges.
    private func replyContext(for record: BrainDumpRecord) -> String {
        let s = record.synthesis
        var ctx = "What they're circling: \(s.headline)\nSummary: \(s.summary)\nYour current best bet: \(s.bestBet)"
        let recent = record.turns.suffix(3)
        if !recent.isEmpty {
            ctx += "\n\nRecent back-and-forth:\n"
                + recent.map { "Founder: \($0.you)\nYou (Pickle): \($0.pickle)" }.joined(separator: "\n")
        }
        return ctx
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

    /// Reopen a saved brain dump from history.
    func openBrainDump(_ record: BrainDumpRecord) {
        brainResult = record.synthesis
        brainTranscript = record.transcript
        brainTurns = record.turns
        currentDumpID = record.id
        isAddingOn = false
        mode = .brainDump
        navigate(to: .brainDumpResults)
    }

    func practiceAgain() {
        voice.stop(); result = nil; isNewBest = false
        mode = .pitch
        navStack = []; stage = .welcome          // start a fresh flow
    }

    /// Start another brain dump from scratch.
    func newBrainDump() {
        voice.stop(); brainResult = nil; brainTranscript = ""; brainTurns = []
        currentDumpID = nil; continuingDumpID = nil; isAddingOn = false
        mode = .brainDump
        navStack = []; stage = .welcome
    }

    /// Bridge from a brain dump into pitch practice (e.g. on the best idea).
    func practiceAPitch() {
        voice.stop()
        mode = .pitch
        navStack = []; stage = .welcome
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
