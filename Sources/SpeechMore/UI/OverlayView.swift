import SwiftUI
import AppKit

struct OverlayView: View {
    @ObservedObject private var state = AppState.shared
    @State private var copied = false

    var body: some View {
        switch state.overlayStyle {
        case .compact:
            compactBody
        case .expanded:
            expandedBody
        case .hidden:
            EmptyView()
        }
    }

    // MARK: - Compact Pill

    private var compactBody: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)

            Text(state.displayText)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 12)
        .frame(width: Constants.compactWidth, height: Constants.compactHeight)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.55))
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Expanded Panel

    private var expandedBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                modeIcon
                Text(state.currentMode?.displayName ?? "SpeechMore")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                phaseIndicator

                Button(action: { state.overlayStyle = .hidden }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(Color.white.opacity(0.15)))
                }
                .buttonStyle(.plain)
            }

            Divider()
                .background(Color.white.opacity(0.2))

            // Content
            ScrollView {
                Text(state.displayText)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: .infinity)

            // Copy button (visible when done)
            if case .done = state.phase {
                HStack {
                    Spacer()
                    Button(action: copyResult) {
                        HStack(spacing: 4) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 11))
                            Text(copied ? "已复制" : "复制")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.15))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .frame(width: Constants.overlayWidth, height: Constants.overlayHeight)
        .background(
            RoundedRectangle(cornerRadius: Constants.overlayCornerRadius)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Constants.overlayCornerRadius)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Actions

    private func copyResult() {
        let text = state.displayText
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copied = false
        }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var modeIcon: some View {
        switch state.currentMode {
        case .voiceInput:
            Image(systemName: "keyboard")
                .foregroundColor(.blue)
        case .askAnything:
            Image(systemName: "questionmark.bubble")
                .foregroundColor(.green)
        case .translate:
            Image(systemName: "globe")
                .foregroundColor(.orange)
        case nil:
            Image(systemName: "waveform")
                .foregroundColor(.gray)
        }
    }

    @ViewBuilder
    private var phaseIndicator: some View {
        switch state.phase {
        case .recording:
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                Text("录音中")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }
        case .transcribing:
            Text("转写中...")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.6))
        case .processing:
            Text("处理中...")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.6))
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 12))
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.system(size: 12))
        case .idle:
            EmptyView()
        }
    }
}
