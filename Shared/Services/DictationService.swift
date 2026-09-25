//
//  DictationService.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 14.07.26.
//
//  Live-Diktat fuer den Fokus-Modus: nimmt ueber das Mikrofon gesprochene
//  Sprache entgegen und transkribiert sie mit SFSpeechRecognizer — bevorzugt
//  On-Device. iOS + macOS (nicht Teil des Watch-Targets).
//

import Foundation
import Speech
import AVFoundation
import os
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

@Observable
@MainActor
final class DictationService {
    private static let logger = Logger(subsystem: "com.andre.claassen.KalorienKompass", category: "Dictation")

    /// Welche Berechtigung fehlt (fuer den "Systemeinstellungen oeffnen"-Knopf)
    enum PermissionKind { case microphone, speechRecognition }

    /// Laeuft gerade eine Aufnahme?
    private(set) var isRecording = false

    /// Aktueller (Teil-)Transkripttext
    private(set) var transcript = ""

    /// Fehlermeldung fuer die UI (nil = kein Fehler)
    var errorMessage: String?

    /// Gesetzt, wenn der letzte Start an einer fehlenden Berechtigung scheiterte
    private(set) var deniedPermission: PermissionKind?

    @ObservationIgnored private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "de-DE"))
    @ObservationIgnored private let audioEngine = AVAudioEngine()
    // nonisolated(unsafe): der Audio-Tap-Thread liest `request`, waehrend der
    // Main-Actor es verwaltet. Zugriff ist durch die Teardown-Reihenfolge in
    // stop() (erst Tap entfernen, dann request nil setzen) abgesichert.
    @ObservationIgnored nonisolated(unsafe) private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?

    /// Ist Spracherkennung grundsaetzlich verfuegbar?
    var isAvailable: Bool { recognizer?.isAvailable ?? false }

    /// Fuegt Erkanntes an bereits vorhandenen Text an.
    ///
    /// Ein leeres Transkript laesst das Feld unangetastet: der Erkenner meldet
    /// sich beim Abschluss noch einmal ohne Inhalt, und das darf getippten oder
    /// zuvor diktierten Text nicht loeschen (Issue #75).
    nonisolated static func merged(existing: String, transcript: String) -> String {
        let vorhanden = existing.trimmingCharacters(in: .whitespacesAndNewlines)
        let neu = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !neu.isEmpty else { return existing }
        return vorhanden.isEmpty ? neu : vorhanden + " " + neu
    }

    // MARK: - Steuerung

    /// Startet bzw. stoppt das Diktat. `onUpdate` liefert bei jedem Teilergebnis
    /// den aktuellen Transkripttext.
    func toggle(onUpdate: @escaping (String) -> Void) async {
        if isRecording {
            stop()
        } else {
            await start(onUpdate: onUpdate)
        }
    }

    func start(onUpdate: @escaping (String) -> Void) async {
        guard !isRecording else { return }
        errorMessage = nil

        guard await ensureAuthorization() else {
            errorMessage = String(localized: "dictation_permission_denied")
            return
        }
        deniedPermission = nil
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = String(localized: "dictation_unavailable")
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        do {
            try startEngine()
        } catch {
            self.request = nil
            errorMessage = error.localizedDescription
            return
        }

        transcript = ""
        isRecording = true

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                // Ein leeres Ergebnis nach dem Beenden darf das bereits Erkannte
                // nicht ueberschreiben: der Erkenner meldet sich beim Abschluss
                // noch einmal, und frueher landete dieses Leerergebnis im
                // Eingabefeld — das Diktat war damit weg (Issue #75).
                if let result {
                    let text = result.bestTranscription.formattedString
                    if !text.isEmpty {
                        self.transcript = text
                        onUpdate(text)
                    }
                }
                if error != nil || (result?.isFinal ?? false) {
                    self.stop()
                }
            }
        }
    }

    /// Beendet das Diktat. Das zuletzt Erkannte bleibt erhalten.
    func stop() {
        guard isRecording else { return }
        isRecording = false

        // Reihenfolge ist wichtig gegen Use-after-free: erst den Tap entfernen
        // (danach feuert der Audio-Thread nicht mehr), dann die Engine stoppen,
        // dann das Request abschliessen und erst zuletzt die Referenzen loesen.
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        request?.endAudio()
        request = nil
        // `finish()` statt `cancel()`: abbrechen verwirft das letzte Teilergebnis,
        // und genau das war der gesprochene Satz (Issue #75).
        task?.finish()
        task = nil

        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    // MARK: - Audio-Engine

    private func startEngine() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        #endif

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        // Tap liest `request` frisch ueber weak self und null-prueft es — nach
        // stop() ist request nil, ein verspaeteter Buffer wird ignoriert.
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }
        audioEngine.prepare()
        try audioEngine.start()
    }

    // MARK: - Berechtigungen

    private func ensureAuthorization() async -> Bool {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard speechStatus == .authorized else {
            Self.logger.error("Spracherkennung nicht autorisiert: \(speechStatus.rawValue, privacy: .public)")
            deniedPermission = .speechRecognition
            return false
        }

        #if os(iOS)
        let micGranted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
        #else
        let micGranted = await AVCaptureDevice.requestAccess(for: .audio)
        #endif
        if !micGranted {
            Self.logger.error("Mikrofon-Zugriff verweigert")
            deniedPermission = .microphone
        }
        return micGranted
    }

    /// Oeffnet die passende Stelle in den Systemeinstellungen (Datenschutz).
    func openSystemSettings() {
        #if os(macOS)
        let urlString: String
        switch deniedPermission {
        case .speechRecognition:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition"
        default:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        }
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
        #elseif os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}
