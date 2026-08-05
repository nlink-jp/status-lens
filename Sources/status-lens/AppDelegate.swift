import AppKit
import StatusLensCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let store = SettingsStore()
    private let fetcher = StatuspageClient()
    private let notifier = Notifier()
    private var model: AppModel!
    private var settings: Settings = .default
    private var states: [ProfileState] = []
    /// Last observed status per profile — the notification baseline.
    private var previousStatuses: [UUID: ServiceStatus] = [:]
    private var pollTimer: Timer?
    private var pollTask: Task<Void, Never>?
    private var activity: NSObjectProtocol?
    private var settingsWindow: NSWindow?

    private var actions: AppActions {
        AppActions(
            refresh: { [weak self] in self?.poll() },
            openSettings: { [weak self] in self?.openSettings() },
            quit: { NSApp.terminate(nil) }
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        settings = store.load()
        model = AppModel(settings: settings)
        notifier.requestAuthorizationIfAvailable()
        NSApp.mainMenu = makeMainMenu()

        // An LSUIElement app with no visible window gets App-Napped and its
        // timers freeze; hold an activity for the app's lifetime.
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep],
            reason: "status-lens periodic status polling"
        )

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover = NSPopover()
        popover.behavior = .transient
        popover.delegate = self

        render()
        schedulePollTimer()
        poll()
    }

    // MARK: Polling

    private func schedulePollTimer() {
        pollTimer?.invalidate()
        let timer = Timer(
            timeInterval: TimeInterval(settings.pollingIntervalSeconds),
            target: self,
            selector: #selector(pollTimerFired),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    @objc private func pollTimerFired() {
        poll()
    }

    private func poll() {
        guard pollTask == nil else { return }
        let profiles = settings.profiles
        let fetcher = self.fetcher
        pollTask = Task { @MainActor [weak self] in
            let states = await loadStates(profiles: profiles, fetcher: fetcher)
            guard let self else { return }
            self.applyPollResult(states)
            self.pollTask = nil
        }
    }

    private func applyPollResult(_ states: [ProfileState]) {
        for state in states {
            notifyIfCrossed(state)
        }
        previousStatuses = Dictionary(
            uniqueKeysWithValues: states.map { ($0.profile.id, $0.status) }
        )
        self.states = states
        model.update(states: states)
        render()
    }

    private func notifyIfCrossed(_ state: ProfileState) {
        guard state.profile.notify else { return }
        let detail = state.summary?.status.description ?? state.errorDescription ?? ""
        switch statusTransition(from: previousStatuses[state.profile.id], to: state.status) {
        case .degraded(_, let to):
            notifier.notify(title: "\(state.profile.name): \(to.displayText)", body: detail)
        case .recovered(_, let to):
            notifier.notify(title: "\(state.profile.name) recovered: \(to.displayText)", body: detail)
        case .none:
            break
        }
    }

    private func render() {
        statusItem.button?.attributedTitle = StatusBarRenderer.attributedTitle(
            states: states,
            mode: settings.displayMode
        )
    }

    // MARK: Status item click

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showQuickMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        guard let button = statusItem.button else { return }
        // Popover content is built on open and released on close so the
        // SwiftUI tree does not live (and lay out) while hidden.
        let hosting = NSHostingController(rootView: PopoverView(model: model, actions: actions))
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    // MARK: Settings window

    private func openSettings() {
        popover.performClose(nil)
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = SettingsView(model: model) { [weak self] newSettings in
            self?.apply(settings: newSettings)
        }
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "status-lens settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: Quick menu (right click)

    private func showQuickMenu() {
        statusItem.menu = buildQuickMenu()
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func buildQuickMenu() -> NSMenu {
        let menu = NSMenu()

        if states.isEmpty {
            menu.addItem(disabledItem(title: "No status fetched yet"))
        }
        for state in states {
            let item = NSMenuItem(
                title: "\(state.profile.name): \(state.status.displayText)",
                action: #selector(openProfilePage(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = state.profile.baseURL
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let refresh = NSMenuItem(title: "Refresh now", action: #selector(refreshNow), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)

        let parallel = NSMenuItem(title: "Show every profile", action: #selector(useParallelMode), keyEquivalent: "")
        parallel.target = self
        parallel.state = settings.displayMode == .parallel ? .on : .off
        menu.addItem(parallel)

        let worst = NSMenuItem(title: "Show worst status only", action: #selector(useWorstMode), keyEquivalent: "")
        worst.target = self
        worst.state = settings.displayMode == .worst ? .on : .off
        menu.addItem(worst)

        menu.addItem(.separator())
        menu.addItem(disabledItem(title: "status-lens \(appVersion)"))

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettingsFromMenu), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let quit = NSMenuItem(
            title: "Quit status-lens",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quit)

        return menu
    }

    @objc private func openSettingsFromMenu() {
        openSettings()
    }

    private func disabledItem(title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    // MARK: Actions

    @objc private func openProfilePage(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func refreshNow() {
        poll()
    }

    @objc private func useParallelMode() {
        var updated = settings
        updated.displayMode = .parallel
        apply(settings: updated)
    }

    @objc private func useWorstMode() {
        var updated = settings
        updated.displayMode = .worst
        apply(settings: updated)
    }

    /// Single entry point for settings changes (menu, settings UI).
    func apply(settings newSettings: Settings) {
        let intervalChanged = newSettings.pollingIntervalSeconds != settings.pollingIntervalSeconds
        let profilesChanged = newSettings.profiles != settings.profiles
        settings = newSettings
        store.save(newSettings)
        model.update(settings: newSettings)
        if intervalChanged {
            schedulePollTimer()
        }
        if profilesChanged {
            let known = Set(newSettings.profiles.map(\.id))
            previousStatuses = previousStatuses.filter { known.contains($0.key) }
            poll()
        }
        render()
    }
}

extension AppDelegate: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        popover.contentViewController = nil
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === settingsWindow {
            settingsWindow = nil
        }
    }
}
