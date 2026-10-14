// Talking and listening, on the iPhone: dictation uses Apple's on-device
// speech recognition only (if this iPhone can't recognise speech on-device,
// it says so rather than sending audio anywhere), and answers are read aloud
// with the iPhone's own voices.

import Foundation
import AVFoundation
import Speech
import NaturalLanguage
import Observation

@MainActor @Observable
final class Dictation {
    enum Problem: LocalizedError {
        case denied, notOnDevice, unavailable
        var errorDescription: String? {
            switch self {
            case .denied: "Lockedmind needs the microphone and speech recognition to take dictation. You can allow both in Settings › Lockedmind."
            case .notOnDevice: "This iPhone can't recognise speech in your language on-device, and Lockedmind never sends your voice anywhere. You can still use the keyboard's dictation."
            case .unavailable: "Dictation isn't available right now. Try again in a moment."
            }
        }
    }

    private(set) var isListening = false
    /// 0 … 1, how loud the voice is right now, for the little meter.
    private(set) var level: Double = 0

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored private var stopper: Task<Void, Never>?

    /// Starts listening; `onText` gets everything heard so far, after `prefix`.
    func start(prefix: String, onText: @escaping (String) -> Void) async throws {
        guard !isListening else { return }
        guard await Self.allowed() else { throw Problem.denied }
        guard let recognizer = SFSpeechRecognizer(locale: .current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              recognizer.isAvailable else { throw Problem.unavailable }
        guard recognizer.supportsOnDeviceRecognition else { throw Problem.notOnDevice }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true      // never leaves the iPhone
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        self.request = request

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            request.append(buffer)
            let loudness = Self.loudness(buffer)
            Task { @MainActor in self?.level = loudness }
        }
        engine.prepare()
        try engine.start()
        isListening = true

        let lead = prefix.isEmpty || prefix.hasSuffix(" ") ? prefix : prefix + " "
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let finished = (result?.isFinal ?? false) || error != nil
            Task { @MainActor in
                if let text { onText(lead + text) }
                if finished { self?.stop() }
            }
        }
        // A minute at most, so a forgotten microphone doesn't stay open.
        stopper = Task { [weak self] in
            try? await Task.sleep(for: .seconds(60))
            self?.stop()
        }
    }

    func stop() {
        guard isListening else { return }
        stopper?.cancel()
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.finish()
        request = nil
        task = nil
        isListening = false
        level = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private static func allowed() async -> Bool {
        let speech = await withCheckedContinuation { done in
            SFSpeechRecognizer.requestAuthorization { done.resume(returning: $0 == .authorized) }
        }
        guard speech else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    nonisolated private static func loudness(_ buffer: AVAudioPCMBuffer) -> Double {
        guard let data = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<Int(buffer.frameLength) { sum += data[i] * data[i] }
        let rms = sqrt(sum / Float(buffer.frameLength))
        return Double(min(1, max(0, (20 * log10(max(rms, 0.000_01)) + 50) / 40)))
    }
}

@MainActor @Observable
final class Speaker: NSObject, AVSpeechSynthesizerDelegate {
    /// The message being read aloud, if any.
    private(set) var speaking: UUID?

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func toggle(_ message: Message) {
        if speaking == message.id { stop(); return }
        stop()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
        let utterance = AVSpeechUtterance(string: Self.plain(message.text))
        utterance.voice = AVSpeechSynthesisVoice(language: Self.language(of: message.text))
        utterance.prefersAssistiveTechnologySettings = true
        speaking = message.id
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        speaking = nil
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.speaking = nil }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.speaking = nil }
    }

    /// Markdown marks would be read out loud; take them out.
    static func plain(_ text: String) -> String {
        text.replacingOccurrences(of: #"```[\s\S]*?```"#, with: " (code) ", options: .regularExpression)
            .replacingOccurrences(of: #"(?m)^\s*(#{1,6}|[-*•+]|\d{1,3}[.)])\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "`", with: "")
    }

    private static func language(of text: String) -> String {
        let recognizer = NLLanguageGuess.guess(text)
        return recognizer ?? AVSpeechSynthesisVoice.currentLanguageCode()
    }
}

private enum NLLanguageGuess {
    static func guess(_ text: String) -> String? {
        let r = NLLanguageRecognizer()
        r.processString(String(text.prefix(400)))
        return r.dominantLanguage?.rawValue
    }
}
