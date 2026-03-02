# SpeechMore

一个轻量级 macOS 菜单栏语音助手，基于 [阶跃星辰 (StepFun)](https://www.stepfun.com/) 的实时 ASR 和 LLM API 构建。

按住快捷键即可实时语音识别、AI 问答或翻译，松手即停，结果显示在屏幕底部浮层中。

## 功能

| 快捷键 | 模式 | 说明 |
|--------|------|------|
| 按住 **右 ⌥ (Option)** | 语音输入 | 实时语音转文字 (ASR 直出) |
| 按住 右⌥ → 再按 **Space** | 随便问 | 语音提问，AI 回答 (ASR + LLM) |
| 按住 右⌥ → 再按 **左 Shift** | 翻译 | 语音翻译为目标语言 (ASR + LLM) |

- 按住右 Option 立即开始录音，录音过程中可按 Space / Shift 升级模式
- 松开右 Option 结束录音
- 结果展示在屏幕底部浮层，支持手动复制

## 系统要求

- macOS 13.0 (Ventura) 或更高版本
- Swift 5.9+
- [阶跃星辰 API Key](https://platform.stepfun.com/)

## 构建 & 安装

```bash
# 克隆仓库
git clone <repo-url>
cd speechmore

# 构建并安装到 /Applications
bash build-app.sh

# 运行
open /Applications/SpeechMore.app
```

首次启动会自动弹出辅助功能权限请求，需要在 **系统设置 → 隐私与安全性 → 辅助功能** 中允许。

## 配置

点击菜单栏的 **波形图标** → **打开主页**：

1. 填入 Step API Key
2. 选择翻译目标语言（默认 English）

设置会自动保存到 UserDefaults。

## 项目结构

```
Sources/SpeechMore/
├── App/                # 应用入口、AppDelegate
├── Audio/              # 麦克风录音 (AudioRecorder)
├── Core/               # AppState、Constants、Settings、LogStore
├── Features/           # FeatureCoordinator、FeatureMode、TextInjector
├── HotKey/             # 全局快捷键监听 (HotKeyManager)
├── Network/            # ASR WebSocket 客户端、LLM HTTP 客户端
└── UI/                 # 菜单栏、主窗口、浮层 (OverlayPanel/View)
```

## 技术栈

- **语言**: Swift / SwiftUI
- **构建**: Swift Package Manager
- **ASR**: StepFun Realtime ASR (WebSocket 流式识别)
- **LLM**: StepFun Chat Completions (SSE 流式输出)
- **音频**: AVFoundation (PCM 16-bit 16kHz)

## 主页 & 日志

应用提供一个独立的主页窗口（从菜单栏弹窗中点击"打开主页"），包含：

- **主页 Tab**: API Key 设置、语言选择、快捷键说明
- **日志 Tab**: 实时运行日志，方便排查问题

## License

MIT
