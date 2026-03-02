import Foundation

// MARK: - Client → Server Messages

/// session.update - 配置音频格式和转录参数
struct ASRSessionUpdate: Encodable {
    let event_id: String
    let type = "session.update"
    let session: Session

    struct Session: Encodable {
        let audio: Audio
    }

    struct Audio: Encodable {
        let input: Input
    }

    struct Input: Encodable {
        let format: Format
        let transcription: Transcription
    }

    struct Format: Encodable {
        let type: String
        let codec: String
        let rate: Int
        let bits: Int
        let channel: Int
    }

    struct Transcription: Encodable {
        let model: String
        let language: String
        let full_rerun_on_commit: Bool
        let enable_itn: Bool
    }

    static func defaultUpdate() -> ASRSessionUpdate {
        ASRSessionUpdate(
            event_id: "evt_\(UUID().uuidString.prefix(8))",
            session: Session(
                audio: Audio(
                    input: Input(
                        format: Format(
                            type: "pcm",
                            codec: "pcm_s16le",
                            rate: Int(Constants.sampleRate),
                            bits: Int(Constants.bitsPerSample),
                            channel: Int(Constants.channels)
                        ), 
                        transcription: Transcription(
                            model: "step-asr",
                            language: "zh",
                            full_rerun_on_commit: true,
                            enable_itn: true
                        )
                    )
                )
            )
        )
    }
}

/// input_audio_buffer.append - 发送音频数据
struct ASRAudioAppend: Encodable {
    let event_id: String
    let type = "input_audio_buffer.append"
    let audio: String  // base64 encoded PCM
}

/// input_audio_buffer.commit - 提交音频缓冲区
struct ASRBufferCommit: Encodable {
    let event_id: String
    let type = "input_audio_buffer.commit"

    static func create() -> ASRBufferCommit {
        ASRBufferCommit(event_id: "evt_\(UUID().uuidString.prefix(8))")
    }
}

// MARK: - Server → Client Messages (parsed generically)

/// Generic server message envelope for type routing
struct ASRServerEnvelope: Decodable {
    let event_id: String?
    let type: String
}

/// conversation.item.input_audio_transcription.delta
struct ASRTranscriptionDelta: Decodable {
    let item_id: String?
    let text: String?
}

/// conversation.item.input_audio_transcription.completed
struct ASRTranscriptionCompleted: Decodable {
    let item_id: String?
    let transcript: String?
}

/// error
struct ASRError: Decodable {
    let error: ErrorDetail?

    struct ErrorDetail: Decodable {
        let type: String?
        let code: String?
        let message: String?
    }
}
