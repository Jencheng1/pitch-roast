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

/// A small in-panel notification (e.g. "competitor scan is ready"). Tapping it
/// jumps to the relevant brain dump.
struct PickleToast: Equatable {
    var message: String
    var icon: String
    var dumpID: UUID?
}

/// What's open in the larger workspace window.
enum WorkspaceSelection: Hashable {
    case brain(UUID)
    case pitch(UUID)
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
    @Published var landscapeLoading = false         // true while the live competitor search runs
    @Published var toast: PickleToast?              // transient "ready" notification
    @Published var expandRecap = false              // request the results view to open its recap

    // Workspace window (the larger founder workspace)
    @Published var workspaceOpen = false
    @Published var workspaceSelection: WorkspaceSelection?
    @Published var workspaceReplying = false
    @Published var workspaceError: String?
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
        toast = nil
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

                // Show the synthesis immediately (with its knowledge-based landscape);
                // the live web-search landscape fills in afterward in the background.
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

                if let idea = synthesis.topIdea ?? synthesis.ideas.first {
                    refreshLandscape(dumpID: rec.id, idea: idea,
                                     baseCategory: synthesis.landscape?.category, openAIKey: openAIKey)
                }
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

                let reply = try await provider.reply(context: context, newThought: newThought,
                                                     images: replyImages(for: existing))
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

    /// Background live-research enrichment: fetch the competitive landscape via
    /// web search and patch it into the (already-shown) dump when it returns.
    private func refreshLandscape(dumpID: UUID, idea: BrainDumpSynthesis.Idea,
                                  baseCategory: String?, openAIKey: String?) {
        guard let researcher = makeLandscapeResearcher(openAIKey: openAIKey) else { return }
        landscapeLoading = true
        Task {
            do {
                var live = try await researcher.research(
                    ideaName: idea.name, problem: idea.problem, category: baseCategory ?? idea.name,
                    customer: idea.audience, valueProp: idea.valueProp)
                // Only accept a *useful* result — an empty search (no players /
                // no category) shouldn't overwrite the knowledge landscape or
                // raise a "ready" toast.
                guard !live.players.isEmpty,
                      !live.category.trimmingCharacters(in: .whitespaces).isEmpty
                else { throw ProviderError.noContent }

                live.live = true
                if var rec = brainStore.record(dumpID) {
                    rec.synthesis.landscape = live
                    brainStore.replace(rec)
                }
                if currentDumpID == dumpID { brainResult?.landscape = live }
                let count = live.players.count
                toast = PickleToast(
                    message: "Competitor scan's in — \(count) player\(count == 1 ? "" : "s") found. See where it sits →",
                    icon: "map.fill", dumpID: dumpID)
            } catch {
                // Search failed or came back empty — keep the knowledge-based
                // landscape that's already on screen (no toast, no LIVE badge).
            }
            landscapeLoading = false
        }
    }

    // MARK: Toast

    func tapToast() {
        let id = toast?.dumpID
        toast = nil
        guard let id, let rec = brainStore.record(id) else { return }
        showPanel()
        expandRecap = true            // open the recap so the landscape is visible
        openBrainDump(rec)
    }

    func dismissToast() { toast = nil }

    // MARK: Workspace

    func openWorkspace() {
        if workspaceSelection == nil {
            if let id = currentDumpID { workspaceSelection = .brain(id) }
            else if let d = brainStore.latest { workspaceSelection = .brain(d.id) }
            else if let p = store.latest { workspaceSelection = .pitch(p.id) }
        }
        workspaceOpen = true
    }

    func closeWorkspace() { workspaceOpen = false }

    /// Attach supporting materials to a session right away (the Materials tray /
    /// a drop onto the reading pane). Loading is best-effort per file; failures
    /// surface in `workspaceError` without dropping the ones that did read.
    func attachToSession(_ urls: [URL], dumpID: UUID) {
        guard !urls.isEmpty else { return }
        workspaceError = nil
        var loaded: [Attachment] = []
        var failure: String?
        for url in urls {
            do { loaded.append(try AttachmentLoader.load(url: url)) }
            catch { failure = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription }
        }
        if !loaded.isEmpty { brainStore.addAttachments(loaded, to: dumpID) }
        if let failure { workspaceError = failure }
    }

    func removeSessionAttachment(_ attachmentID: UUID, dumpID: UUID) {
        brainStore.removeAttachment(attachmentID, from: dumpID)
    }

    /// Continue a brain-dump conversation by typing (workspace), optionally with
    /// attachments staged in the composer. Pickle replies to the new message and
    /// can analyze the materials; the synthesis stays put. The staged files are
    /// persisted onto the session so they inform every future reply too.
    func workspaceFollowup(dumpID: UUID, text: String, attachments: [Attachment] = []) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !workspaceReplying, brainStore.record(dumpID) != nil else { return }
        guard !t.isEmpty || !attachments.isEmpty else { return }

        // Persist staged files first so context + vision see them this turn.
        if !attachments.isEmpty { brainStore.addAttachments(attachments, to: dumpID) }
        guard let rec = brainStore.record(dumpID) else { return }

        let context = replyContext(for: rec)
        let images = replyImages(for: rec)
        // What Pickle is told, and what we log in the thread (note the files).
        let message = t.isEmpty
            ? "I've shared some materials — take a look and tell me what you make of them."
            : t
        var youLog = t
        if !attachments.isEmpty {
            let names = attachments.map(\.name).joined(separator: ", ")
            youLog += (t.isEmpty ? "" : "\n") + "📎 " + names
        }

        let openAIKey = Keychain.load(.openAI)
        workspaceError = nil
        workspaceReplying = true
        Task {
            let provider = makeProvider(openAIKey: openAIKey)
            do {
                let reply = try await provider.reply(context: context, newThought: message, images: images)
                brainStore.appendTurn(BrainDumpTurn(you: youLog, pickle: reply), to: dumpID)
                if currentDumpID == dumpID { brainTurns = brainStore.record(dumpID)?.turns ?? brainTurns }
            } catch {
                workspaceError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            workspaceReplying = false
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
        // Fold in the text of any supporting materials (decks, notes, research).
        let textFiles = record.files.compactMap(\.contextBlock)
        if !textFiles.isEmpty {
            ctx += "\n\nSupporting materials the founder attached (use them for specifics):\n"
                + textFiles.joined(separator: "\n\n")
        }
        let imageNames = record.files.filter { $0.kind == .image }.map(\.name)
        if !imageNames.isEmpty {
            ctx += "\n\nThe founder also attached \(imageNames.count) image(s) you can see: "
                + imageNames.joined(separator: ", ")
        }
        return ctx
    }

    /// Image attachments on a session, as vision payloads for the reply.
    private func replyImages(for record: BrainDumpRecord) -> [ReplyImage] {
        record.files.compactMap(\.replyImage)
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
        if toast?.dumpID == record.id { toast = nil }
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
        currentDumpID = nil; continuingDumpID = nil; isAddingOn = false; toast = nil
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

    /// Live competitive research engine. Prefer Claude's web search (cleanest);
    /// otherwise OpenAI's. Nil if neither key is available → knowledge fallback.
    private func makeLandscapeResearcher(openAIKey: String?) -> LandscapeResearcher? {
        if let key = Keychain.load(.anthropic), !key.isEmpty {
            return ClaudeLandscapeResearcher(apiKey: key)
        }
        if let key = openAIKey, !key.isEmpty {
            return OpenAILandscapeResearcher(apiKey: key)
        }
        return nil
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
