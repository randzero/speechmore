import SwiftUI

struct MenuBarView: View {
    @ObservedObject private var settings = Settings.shared
    @State private var showKey = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("SpeechMore")
                    .font(.headline)
            }

            Divider()

            // API Key
            VStack(alignment: .leading, spacing: 4) {
                Text("Step API Key")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                HStack {
                    if showKey {
                        TextField("sk-...", text: $settings.apiKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    } else {
                        SecureField("sk-...", text: $settings.apiKey)
                            .textFieldStyle(.roundedBorder)
                    }
                    Button(action: { showKey.toggle() }) {
                        Image(systemName: showKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                }
            }

            // Target Language
            VStack(alignment: .leading, spacing: 4) {
                Text("翻译目标语言")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Picker("", selection: $settings.targetLanguage) {
                    ForEach(Settings.supportedLanguages, id: \.self) { lang in
                        Text(lang).tag(lang)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            Divider()

            // Shortcuts help
            VStack(alignment: .leading, spacing: 4) {
                Text("快捷键")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                shortcutRow(keys: "按住 \(settings.triggerKey.shortLabel)", desc: "语音输入")
                shortcutRow(keys: "按住 \(settings.triggerKey.shortLabel)+Space", desc: "随便问")
                shortcutRow(keys: "按住 \(settings.triggerKey.shortLabel)+Shift", desc: "翻译")
            }
            .font(.system(size: 12))

            Divider()

            // Open main window
            Button(action: {
                NotificationCenter.default.post(name: .openMainWindow, object: nil)
            }) {
                HStack {
                    Image(systemName: "macwindow")
                    Text("打开主页")
                    Spacer()
                }
            }
            .buttonStyle(.borderless)

            Divider()

            // Status
            HStack {
                Circle()
                    .fill(settings.hasAPIKey ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(settings.hasAPIKey ? "已就绪" : "请设置 API Key")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("退出") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
                .foregroundColor(.red)
            }
        }
        .padding(16)
        .frame(width: 300)
    }

    private func shortcutRow(keys: String, desc: String) -> some View {
        HStack {
            Text(keys)
                .foregroundColor(.primary)
                .fontWeight(.medium)
            Spacer()
            Text(desc)
                .foregroundColor(.secondary)
        }
    }
}
