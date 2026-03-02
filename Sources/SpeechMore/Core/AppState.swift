import Foundation
import Combine

enum OverlayStyle {
    case hidden
    case compact    // Recording: small pill
    case expanded   // Result: large panel
}

enum SessionPhase {
    case idle
    case recording
    case transcribing
    case processing
    case done
    case error(String)
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var phase: SessionPhase = .idle
    @Published var currentMode: FeatureMode?
    @Published var partialTranscript: String = ""
    @Published var finalTranscript: String = ""
    @Published var llmResult: String = ""
    @Published var overlayStyle: OverlayStyle = .hidden

    var displayText: String {
        switch phase {
        case .recording:
            return partialTranscript.isEmpty ? "正在听..." : partialTranscript
        case .transcribing:
            return partialTranscript.isEmpty ? "处理中..." : partialTranscript
        case .processing:
            return llmResult.isEmpty ? "思考中..." : llmResult
        case .done:
            return llmResult.isEmpty ? finalTranscript : llmResult
        case .error(let msg):
            return "错误: \(msg)"
        case .idle:
            return ""
        }
    }

    func reset() {
        phase = .idle
        currentMode = nil
        partialTranscript = ""
        finalTranscript = ""
        llmResult = ""
        overlayStyle = .hidden
    }
}
