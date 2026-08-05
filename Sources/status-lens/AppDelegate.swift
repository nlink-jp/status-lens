import AppKit
import StatusLensCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let store = SettingsStore()
    private let fetcher = StatuspageClient()
    private var settings: Settings = .default
    private var states: [ProfileState] = []
    private var pollTimer: Timer?
    private var pollTask: Task<Void, Never>?
    private var activity: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        settings = store.load()

        // An LSUIElement app with no visible window gets App-Napped and its
        // timers freeze; hold an activity for the app's lifetime.
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep],
            reason: "status-lens periodic status polling"
        )

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        render()
        rebuildMenu()
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
            self.states = states
            self.render()
            self.rebuildMenu()
            self.pollTask = nil
        }
    }

    private func render() {
        statusItem.button?.attributedTitle = StatusBarRenderer.attributedTitle(
            states: states,
            mode: settings.displayMode
        )
    }

    // MARK: Menu

    private func rebuildMenu() {
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

        let quit = NSMenuItem(
            title: "Quit status-lens",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quit)

        statusItem.menu = menu
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
        setDisplayMode(.parallel)
    }

    @objc private func useWorstMode() {
        setDisplayMode(.worst)
    }

    private func setDisplayMode(_ mode: DisplayMode) {
        settings.displayMode = mode
        store.save(settings)
        render()
        rebuildMenu()
    }
}
