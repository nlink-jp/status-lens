import StatusLensCore
import SwiftUI

/// Settings window content. Changes apply immediately, the Mac way:
/// toggles/pickers write through on change; text fields commit on Enter or
/// focus loss. The URL field validates at commit — an invalid address is
/// flagged inline and the previous valid URL stays in effect, so half-typed
/// URLs never reach the polling loop. Launch-at-login talks to SMAppService
/// directly — system state, not part of our persisted settings.
struct SettingsView: View {
    @ObservedObject var model: AppModel
    let apply: (Settings) -> Void

    @State private var launchAtLogin = false
    @State private var loginError: String?
    @State private var loaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Profiles")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(model.settings.profiles) { profile in
                    ProfileRow(
                        profile: profile,
                        update: { updateProfile($0) },
                        remove: { removeProfile(profile.id) }
                    )
                }
            }

            Menu {
                ForEach(ServiceCatalog.entries) { entry in
                    Button(entry.name) { addCatalogProfile(entry) }
                        .disabled(existingURLs.contains(entry.baseURL))
                }
                Divider()
                Button("Custom…") { addCustomProfile() }
            } label: {
                Label("Add profile", systemImage: "plus")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Divider()

            IntervalField(seconds: model.settings.pollingIntervalSeconds) { commitInterval($0) }

            Picker("Menu bar", selection: displayModeBinding) {
                Text("Every profile").tag(DisplayMode.parallel)
                Text("Worst status only").tag(DisplayMode.worst)
            }
            .pickerStyle(.radioGroup)

            Toggle("Launch at login", isOn: $launchAtLogin)
                .disabled(!LoginItem.isAvailable)
                .onChange(of: launchAtLogin) { newValue in
                    guard LoginItem.isAvailable, newValue != LoginItem.isEnabled else { return }
                    do {
                        try LoginItem.setEnabled(newValue)
                        loginError = nil
                    } catch {
                        loginError = "Launch at login failed: \(error.localizedDescription)"
                        launchAtLogin = LoginItem.isEnabled
                    }
                }
            if !LoginItem.isAvailable {
                Text("Available only when running from the app bundle.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let loginError {
                Text(loginError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .frame(width: 540)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            launchAtLogin = LoginItem.isEnabled
        }
    }

    // MARK: Immediate-apply mutations

    private var displayModeBinding: Binding<DisplayMode> {
        Binding(
            get: { model.settings.displayMode },
            set: { mode in
                var settings = model.settings
                settings.displayMode = mode
                apply(settings)
            }
        )
    }

    private func updateProfile(_ profile: Profile) {
        var settings = model.settings
        guard let index = settings.profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        settings.profiles[index] = profile
        apply(settings)
    }

    private func removeProfile(_ id: UUID) {
        var settings = model.settings
        settings.profiles.removeAll { $0.id == id }
        apply(settings)
    }

    private var existingURLs: Set<URL> {
        Set(model.settings.profiles.map(\.baseURL))
    }

    /// Catalog entries are verified Statuspage pages, so they start watched.
    private func addCatalogProfile(_ entry: CatalogEntry) {
        guard !existingURLs.contains(entry.baseURL) else { return }
        var settings = model.settings
        settings.profiles.append(entry.makeProfile())
        apply(settings)
    }

    /// Custom rows start disabled so the placeholder URL is never polled;
    /// the user fills in the address, then flips the watch toggle on.
    private func addCustomProfile() {
        var settings = model.settings
        settings.profiles.append(Profile(
            name: "New service",
            baseURL: URL(string: "https://status.example.com")!,
            label: "",
            enabled: false,
            notify: true
        ))
        apply(settings)
    }

    private func commitInterval(_ seconds: Int) {
        var settings = model.settings
        settings.pollingIntervalSeconds = Settings.clampInterval(seconds)
        apply(settings)
    }
}

/// One profile line. Toggles write through immediately; name writes through
/// per keystroke; URL and label commit on Enter / focus loss.
private struct ProfileRow: View {
    let profile: Profile
    let update: (Profile) -> Void
    let remove: () -> Void

    @State private var urlText: String
    @State private var labelText: String
    @State private var urlInvalid = false
    @FocusState private var urlFocused: Bool
    @FocusState private var labelFocused: Bool

    init(profile: Profile, update: @escaping (Profile) -> Void, remove: @escaping () -> Void) {
        self.profile = profile
        self.update = update
        self.remove = remove
        _urlText = State(initialValue: profile.baseURL.absoluteString)
        _labelText = State(initialValue: profile.label)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Toggle("", isOn: enabledBinding)
                    .labelsHidden()
                    .help("Watch this profile")
                TextField("Name", text: nameBinding)
                    .frame(width: 110)
                TextField("https://status.example.com", text: $urlText)
                    .focused($urlFocused)
                    .onSubmit(commitURL)
                TextField("CL", text: $labelText)
                    .frame(width: 44)
                    .focused($labelFocused)
                    .onSubmit(commitLabel)
                    .help("Menu bar label (1–3 characters)")
                Toggle(isOn: notifyBinding) {
                    Image(systemName: "bell")
                }
                .help("Notify on degradation and recovery")
                Button(action: remove) {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
                .help("Remove this profile")
            }
            if urlInvalid {
                Text("Not a valid http(s) URL — the previous address stays in effect")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.leading, 28)
            }
        }
        .onChange(of: urlFocused) { focused in
            if !focused { commitURL() }
        }
        .onChange(of: labelFocused) { focused in
            if !focused { commitLabel() }
        }
        .onChange(of: profile.baseURL) { url in
            if !urlFocused {
                urlText = url.absoluteString
                urlInvalid = false
            }
        }
        .onChange(of: profile.label) { label in
            if !labelFocused { labelText = label }
        }
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { profile.enabled },
            set: { var updated = profile; updated.enabled = $0; update(updated) }
        )
    }

    private var notifyBinding: Binding<Bool> {
        Binding(
            get: { profile.notify },
            set: { var updated = profile; updated.notify = $0; update(updated) }
        )
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { profile.name },
            set: { var updated = profile; updated.name = $0; update(updated) }
        )
    }

    private func commitURL() {
        guard urlText != profile.baseURL.absoluteString else {
            urlInvalid = false
            return
        }
        guard let url = Profile.parseBaseURL(urlText) else {
            urlInvalid = true
            return
        }
        urlInvalid = false
        urlText = url.absoluteString
        var updated = profile
        updated.baseURL = url
        update(updated)
    }

    private func commitLabel() {
        let normalized = Profile.normalizeLabel(labelText, fallbackName: profile.name)
        labelText = normalized
        guard normalized != profile.label else { return }
        var updated = profile
        updated.label = normalized
        update(updated)
    }
}

/// Polling interval field: commits on Enter / focus loss, clamped to the
/// valid range; non-numeric input snaps back to the current value.
private struct IntervalField: View {
    let seconds: Int
    let commit: (Int) -> Void

    @State private var text: String
    @FocusState private var focused: Bool

    init(seconds: Int, commit: @escaping (Int) -> Void) {
        self.seconds = seconds
        self.commit = commit
        _text = State(initialValue: String(seconds))
    }

    var body: some View {
        HStack(spacing: 8) {
            Text("Polling interval")
            TextField("60", text: $text)
                .frame(width: 60)
                .multilineTextAlignment(.trailing)
                .focused($focused)
                .onSubmit(commitNow)
            Text("seconds (30–3600)")
                .foregroundStyle(.secondary)
        }
        .onChange(of: focused) { isFocused in
            if !isFocused { commitNow() }
        }
        .onChange(of: seconds) { value in
            if !focused { text = String(value) }
        }
    }

    private func commitNow() {
        guard let value = Int(text.trimmingCharacters(in: .whitespaces)) else {
            text = String(seconds)
            return
        }
        let clamped = Settings.clampInterval(value)
        text = String(clamped)
        if clamped != seconds { commit(clamped) }
    }
}
