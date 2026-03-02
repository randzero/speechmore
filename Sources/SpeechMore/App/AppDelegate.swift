import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var hotKeyManager: HotKeyManager!
    private var overlayPanel: OverlayPanel!
    private var coordinator: FeatureCoordinator!
    private var mainWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request accessibility permission
        requestAccessibilityPermission()

        // Setup menu bar
        setupStatusItem()

        // Setup overlay
        overlayPanel = OverlayPanel()

        // Setup coordinator
        coordinator = FeatureCoordinator()

        // Setup hot key manager
        hotKeyManager = HotKeyManager()
        hotKeyManager.onModeStart = { [weak self] mode in
            self?.coordinator.start(mode: mode)
        }
        hotKeyManager.onModeChange = { [weak self] mode in
            self?.coordinator.updateMode(mode)
        }
        hotKeyManager.onModeEnd = { [weak self] in
            self?.coordinator.stop()
        }

        // Observe overlay style
        AppState.shared.$overlayStyle
            .receive(on: RunLoop.main)
            .sink { [weak self] style in
                guard let self = self else { return }
                switch style {
                case .compact:
                    self.overlayPanel.showCompact()
                case .expanded:
                    self.overlayPanel.showExpanded()
                case .hidden:
                    self.overlayPanel.hide()
                }
            }
            .store(in: &cancellables)

        // Listen for "open main window" notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showMainWindow),
            name: .openMainWindow,
            object: nil
        )

        appLog("[App] SpeechMore launched")
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform.circle", accessibilityDescription: "SpeechMore")
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 300)
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: MenuBarView())
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc func showMainWindow() {
        popover?.performClose(nil)

        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let mainView = MainView()
        let hostingController = NSHostingController(rootView: mainView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "SpeechMore"
        window.contentViewController = hostingController
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.mainWindow = window
    }

    private func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            appLog("[App] Accessibility not yet granted, system prompt shown.")
        }
    }
}

extension Notification.Name {
    static let openMainWindow = Notification.Name("openMainWindow")
}
