import AVFoundation
import Foundation

final class AudioRecorder {
    var onAudioChunk: ((Data) -> Void)?

    private var audioEngine: AVAudioEngine?
    private var converter: AVAudioConverter?
    private var isRecording = false

    private let targetFormat: AVAudioFormat = {
        AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: Constants.sampleRate,
            channels: AVAudioChannelCount(Constants.channels),
            interleaved: true
        )!
    }()

    func startRecording() {
        guard !isRecording else { return }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            print("[AudioRecorder] Invalid input format: \(inputFormat)")
            return
        }

        // Create converter from input format to target 16kHz 16-bit mono
        guard let conv = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            print("[AudioRecorder] Failed to create audio converter")
            return
        }
        self.converter = conv

        // Calculate buffer size for ~100ms of audio at input sample rate
        let bufferSize = AVAudioFrameCount(inputFormat.sampleRate * Double(Constants.chunkDurationMs) / 1000.0)

        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }

        do {
            try engine.start()
            self.audioEngine = engine
            self.isRecording = true
            print("[AudioRecorder] Recording started. Input: \(inputFormat.sampleRate)Hz, \(inputFormat.channelCount)ch")
        } catch {
            print("[AudioRecorder] Failed to start engine: \(error)")
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        converter = nil
        isRecording = false
        print("[AudioRecorder] Recording stopped.")
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let converter = converter else { return }

        // Output buffer: frames for target sample rate
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let outputFrameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCount) else {
            return
        }

        var error: NSError?
        var hasData = false

        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if hasData {
                outStatus.pointee = .noDataNow
                return nil
            }
            hasData = true
            outStatus.pointee = .haveData
            return buffer
        }

        if let error = error {
            print("[AudioRecorder] Conversion error: \(error)")
            return
        }

        guard outputBuffer.frameLength > 0 else { return }

        // Extract raw PCM bytes
        let byteCount = Int(outputBuffer.frameLength) * Int(targetFormat.streamDescription.pointee.mBytesPerFrame)
        guard let channelData = outputBuffer.int16ChannelData else { return }

        let data = Data(bytes: channelData[0], count: byteCount)
        onAudioChunk?(data)
    }
}
