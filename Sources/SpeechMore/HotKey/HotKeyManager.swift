import Foundation
import AppKit

final class HotKeyManager {
    var onModeStart: ((FeatureMode) -> Void)?
    var onModeEnd: (() -> Void)?
    /// Called when mode upgrades mid-session (e.g. voiceInput → askAnything)
    var onModeChange: ((FeatureMode) -> Void)?

    private var flagsMonitor: Any?
    private var localFlagsMonitor: Any?
    private var keyDownMonitor: Any?
    private var keyUpMonitor: Any?
    private var localKeyDownMonitor: Any?
    private var localKeyUpMonitor: Any?
    private var retryTimer: Timer?

    private var optionDown = false
    private var spaceDown = false
    private var shiftDown = false
    private var activeMode: FeatureMode?

    init() {
        trySetupMonitors()
    }

    deinit {
        retryTimer?.invalidate()
        removeMonitors()
    }

    private func trySetupMonitors() {
        if AXIsProcessTrusted() {
            setupMonitors()
            retryTimer?.invalidate()
            retryTimer = nil
        } else {
            appLog("[HotKey] Accessibility not granted, retrying every 2s...")
            retryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                if AXIsProcessTrusted() {
                    self?.setupMonitors()
                    self?.retryTimer?.invalidate()
                    self?.retryTimer = nil
                    appLog("[HotKey] Permission granted, monitors installed.")
                }
            }
        }
    }

    private func setupMonitors() {
        guard flagsMonitor == nil else { return }

        // Global monitors for events in other apps
        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlags(event)
        }
        keyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event)
        }
        keyUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyUp) { [weak self] event in
            self?.handleKeyUp(event)
        }

        // Local monitors for events when our app is focused
        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlags(event)
            return event
        }
        localKeyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event)
            return event
        }
        localKeyUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] event in
            self?.handleKeyUp(event)
            return event
        }

        appLog("[HotKey] All monitors installed. Trigger: hold Right Option (⌥)")
    }

    private func removeMonitors() {
        if let m = flagsMonitor { NSEvent.removeMonitor(m) }
        if let m = localFlagsMonitor { NSEvent.removeMonitor(m) }
        if let m = keyDownMonitor { NSEvent.removeMonitor(m) }
        if let m = keyUpMonitor { NSEvent.removeMonitor(m) }
        if let m = localKeyDownMonitor { NSEvent.removeMonitor(m) }
        if let m = localKeyUpMonitor { NSEvent.removeMonitor(m) }
        flagsMonitor = nil
        localFlagsMonitor = nil
        keyDownMonitor = nil
        keyUpMonitor = nil
        localKeyDownMonitor = nil
        localKeyUpMonitor = nil
    }

    // MARK: - Event Handling

    private func handleFlags(_ event: NSEvent) {
        let keyCode = event.keyCode
        let flags = event.modifierFlags

        // Right Option key (keyCode 61)
        if keyCode == Constants.rightOptionKeyCode {
            let isOption = flags.contains(.option)
            if isOption && !optionDown {
                optionDown = true
                appLog("[HotKey] Right Option DOWN")
                startMode()
            } else if !isOption && optionDown {
                optionDown = false
                appLog("[HotKey] Right Option UP")
                endModeIfActive()
            }
        }

        // Left Shift (keyCode 56)
        if keyCode == Constants.leftShiftKeyCode {
            let isShift = flags.contains(.shift)
            if isShift && !shiftDown {
                shiftDown = true
                if optionDown { tryUpgradeMode() }
            } else if !isShift && shiftDown {
                shiftDown = false
            }
        }
    }

    private func handleKeyDown(_ event: NSEvent) {
        if event.keyCode == Constants.spaceKeyCode && optionDown && !spaceDown {
            spaceDown = true
            tryUpgradeMode()
        }
    }

    private func handleKeyUp(_ event: NSEvent) {
        if event.keyCode == Constants.spaceKeyCode && spaceDown {
            spaceDown = false
        }
    }

    // MARK: - Mode Logic

    /// Start a new session: always begins as voiceInput
    private func startMode() {
        guard activeMode == nil else { return }
        guard optionDown else { return }
        guard Settings.shared.hasAPIKey else {
            appLog("[HotKey] No API key configured.")
            return
        }

        activeMode = .voiceInput
        appLog("[HotKey] >>> Mode started: \(FeatureMode.voiceInput.displayName)")
        DispatchQueue.main.async { [weak self] in
            self?.onModeStart?(.voiceInput)
        }
    }

    /// Upgrade mode mid-session when Space or Shift is pressed
    private func tryUpgradeMode() {
        guard let current = activeMode else { return }

        let newMode: FeatureMode
        if spaceDown {
            newMode = .askAnything
        } else if shiftDown {
            newMode = .translate
        } else {
            return
        }

        guard newMode != current else { return }
        activeMode = newMode
        appLog("[HotKey] ↑ Mode upgraded: \(current.displayName) → \(newMode.displayName)")
        DispatchQueue.main.async { [weak self] in
            self?.onModeChange?(newMode)
        }
    }

    private func endModeIfActive() {
        guard let mode = activeMode else { return }
        activeMode = nil
        spaceDown = false
        shiftDown = false
        appLog("[HotKey] <<< Mode ended: \(mode.displayName)")
        DispatchQueue.main.async { [weak self] in
            self?.onModeEnd?()
        }
    }
}
