import AppKit

@MainActor
class GifRecorder {
    static let shared = GifRecorder()

    func startRecording(rect: CGRect, settings: AppSettings) {
        print("[GIF] GIF recording not yet implemented")
    }

    func stopRecording() async -> URL? {
        return nil
    }
}
