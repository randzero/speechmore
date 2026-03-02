import SwiftUI

struct MainView: View {
    @ObservedObject private var settings = Settings.shared
    @ObservedObject private var logStore = LogStore.shared
    @State private var showKey = false
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            homeTab
                .tabItem {
                    Image(systemName: "house")
                    Text("主页")
                }
                .tag(0)

            logTab
                .tabItem {
                    Image(systemName: "doc.text")
                    Text("日志")
                }
                .tag(1)
        }
        .frame(minWidth: 520, minHeight: 400)
    }

    // MARK: - Home Tab

    private var homeTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("SpeechMore")
                        .font(.title2.bold())
                    Text("语音助手")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Circle()
                    .fill(settings.hasAPIKey ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                Text(settings.hasAPIKey ? "已就绪" : "未配置")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // API Key section
                    settingsSection(title: "Step API Key") {
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
                    settingsSection(title: "翻译目标语言") {
                        Picker("", selection: $settings.targetLanguage) {
                            ForEach(Settings.supportedLanguages, id: \.self) { lang in
                                Text(lang).tag(lang)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 200)
                    }

                    // Shortcuts
                    settingsSection(title: "快捷键") {
                        VStack(alignment: .leading, spacing: 8) {
                            shortcutRow(keys: "按住 右⌥", desc: "语音输入（ASR 直出）")
                            shortcutRow(keys: "按住 右⌥ → 再按 Space", desc: "随便问（ASR + LLM）")
                            shortcutRow(keys: "按住 右⌥ → 再按 Shift", desc: "翻译（ASR + LLM）")
                        }
                        .font(.system(size: 13))
                    }
                }
                .padding(20)
            }

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("退出应用") {
                    NSApplication.shared.terminate(nil)
                }
                .foregroundColor(.red)
            }
            .padding(12)
        }
    }

    // MARK: - Log Tab

    private var logTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Toolbar
            HStack {
                Text("运行日志")
                    .font(.headline)
                Spacer()
                Text("\(logStore.entries.count) 条")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button("清除") {
                    logStore.clear()
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // Log entries
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(logStore.entries.enumerated()), id: \.offset) { index, entry in
                            Text(entry)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.primary.opacity(0.8))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 1)
                                .id(index)
                        }
                    }
                }
                .onChange(of: logStore.entries.count) { _ in
                    if let last = logStore.entries.indices.last {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
    }

    // MARK: - Helpers

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(.secondary)
            content()
        }
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
