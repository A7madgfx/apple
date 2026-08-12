import Foundation
import AVFoundation

enum AudioError: LocalizedError {
    case fileMissing
    case unsupportedFormat
    case playbackFailed

    var errorDescription: String? {
        switch self {
        case .fileMissing: return "تعذر العثور على الملف الصوتي المحدد."
        case .unsupportedFormat: return "صيغة الملف الصوتي غير مدعومة."
        case .playbackFailed: return "تعذر تشغيل الملف الصوتي."
        }
    }
}

/// Owns AVAudioSession configuration and playback of the Adhan/custom prayer sound.
///
/// iOS limitation (documented, not worked around): a fully-terminated app cannot be woken
/// by iOS to start arbitrary long-form audio playback from scratch. This manager plays audio
/// when the app is foregrounded, backgrounded-but-alive (via the `audio` Background Mode,
/// which is an Apple-supported mechanism for continuing playback that was already active),
/// or woken by a scheduled local notification's action. It does not claim to guarantee
/// playback starting from a cold/terminated state — see README "iOS Limitations".
final class PrayerAudioManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var currentAlarm: ActivePrayerAlarm?

    private var player: AVAudioPlayer?
    private var securityScopedURL: URL?
    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
        super.init()
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // .playback category + mixing off allows continued playback with screen locked,
            // subject to the app having the "Audio, AirPlay, and Picture in Picture"
            // Background Mode capability enabled (see Info.plist / project capabilities).
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true, options: [])
        } catch {
            // Non-fatal: playback will simply be attempted with the session's current state.
        }
    }

    /// Starts the configured Adhan/custom sound for the given alarm. Loops indefinitely
    /// until `stop()` is called by a successful prayer-mat verification — by design there
    /// is no user-facing "stop" affordance elsewhere in the UI.
    func start(for alarm: ActivePrayerAlarm) throws {
        configureAudioSession()
        let url = try resolveAudioURL()
        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.delegate = self
            newPlayer.numberOfLoops = -1
            newPlayer.volume = settings.volume
            newPlayer.prepareToPlay()
            guard newPlayer.play() else { throw AudioError.playbackFailed }
            player = newPlayer
            isPlaying = true
            currentAlarm = alarm
        } catch let audioError as AudioError {
            throw audioError
        } catch {
            throw AudioError.playbackFailed
        }
    }

    /// The only way the alarm audio stops: called after successful on-device
    /// prayer-mat verification. There is intentionally no other public "stop" entry point.
    func stopAfterVerification() {
        player?.stop()
        player = nil
        isPlaying = false
        currentAlarm?.status = .completed
        currentAlarm = nil
        securityScopedURL?.stopAccessingSecurityScopedResource()
        securityScopedURL = nil
    }

    /// Plays a short (non-looping) preview from Settings so the user can audition a sound.
    func preview(url: URL) throws {
        configureAudioSession()
        let newPlayer = try AVAudioPlayer(contentsOf: url)
        newPlayer.numberOfLoops = 0
        newPlayer.volume = settings.volume
        newPlayer.play()
        player = newPlayer
    }

    func stopPreview() {
        player?.stop()
        player = nil
    }

    private func resolveAudioURL() throws -> URL {
        switch settings.audioSourceKind {
        case .defaultAdhan:
            guard let url = Bundle.main.url(forResource: "default_adhan", withExtension: "mp3") else {
                throw AudioError.fileMissing
            }
            return url
        case .custom:
            guard let bookmark = settings.customAudioBookmark else { throw AudioError.fileMissing }
            var isStale = false
            guard let url = try? URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale) else {
                throw AudioError.fileMissing
            }
            guard url.startAccessingSecurityScopedResource() else { throw AudioError.fileMissing }
            securityScopedURL = url
            let supported: Set<String> = ["mp3", "m4a", "wav", "aac"]
            guard supported.contains(url.pathExtension.lowercased()) else {
                url.stopAccessingSecurityScopedResource()
                securityScopedURL = nil
                throw AudioError.unsupportedFormat
            }
            return url
        }
    }

    /// Persists a security-scoped bookmark for a file picked from the Files app, so access
    /// survives app relaunches without re-prompting the picker.
    func storeCustomAudio(pickedURL: URL, displayName: String) throws {
        guard pickedURL.startAccessingSecurityScopedResource() else { throw AudioError.fileMissing }
        defer { pickedURL.stopAccessingSecurityScopedResource() }
        let bookmark = try pickedURL.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        settings.customAudioBookmark = bookmark
        settings.customAudioDisplayName = displayName
        settings.audioSourceKind = .custom
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        isPlaying = false
    }
}
