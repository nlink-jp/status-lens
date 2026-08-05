import StatusLensCore
import SwiftUI

/// Settings window content. Edits happen on a local draft and land in one
/// Apply step (validated as a whole), so half-typed URLs never reach the
/// polling loop. Launch-at-login talks to SMAppService directly — system
/// state, not part of our persisted settings.
struct SettingsView: View {
    @ObservedObject var model: AppModel
    let apply: (Settings) -> Void

    @State private var drafts: [ProfileDraft] = []
    @State private var intervalText = ""
    @State private var displayMode: DisplayMode = .parallel
    @State private var launchAtLogin = false
    @State private var loginError: String?
    @State private var validationErrors: [String] = []
    @State private var loaded = false

    struct ProfileDraft: Identifiable {
        let id: UUID
        var name: String
        var urlText: String
        var label: String
        var enabled: Bool
        var notify: Bool
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Profiles")
                .font(.headline)

            profileRows

            Button {
                drafts.append(ProfileDraft(
                    id: UUID(),
                    name: "",
                    urlText: "",
                    label: "",
                    enabled: true,
                    notify: true
                ))
            } label: {
                Label("Add profile", systemImage: "plus")
            }
            .buttonStyle(.borderless)

            Divider()

            HStack(spacing: 8) {
                Text("Polling interval")
                TextField("60", text: $intervalText)
                    .frame(width: 60)
                    .multilineTextAlignment(.trailing)
                Text("seconds (30–3600)")
                    .foregroundStyle(.secondary)
            }

            Picker("Menu bar", selection: $displayMode) {
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

            if !validationErrors.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(validationErrors, id: \.self) { message in
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Revert") { loadFromSettings() }
                Button("Apply") { applyDraft() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 540)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            loadFromSettings()
        }
    }

    private var profileRows: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach($drafts) { $draft in
                HStack(spacing: 8) {
                    Toggle("", isOn: $draft.enabled)
                        .labelsHidden()
                        .help("Watch this profile")
                    TextField("Name", text: $draft.name)
                        .frame(width: 110)
                    TextField("https://status.example.com", text: $draft.urlText)
                    TextField("CL", text: $draft.label)
                        .frame(width: 44)
                        .help("Menu bar label (1–3 characters)")
                    Toggle(isOn: $draft.notify) {
                        Image(systemName: "bell")
                    }
                    .help("Notify on degradation and recovery")
                    Button {
                        drafts.removeAll { $0.id == draft.id }
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Remove this profile")
                }
            }
        }
    }

    private func loadFromSettings() {
        let settings = model.settings
        drafts = settings.profiles.map { profile in
            ProfileDraft(
                id: profile.id,
                name: profile.name,
                urlText: profile.baseURL.absoluteString,
                label: profile.label,
                enabled: profile.enabled,
                notify: profile.notify
            )
        }
        intervalText = String(settings.pollingIntervalSeconds)
        displayMode = settings.displayMode
        launchAtLogin = LoginItem.isEnabled
        validationErrors = []
    }

    private func applyDraft() {
        var errors: [String] = []
        var profiles: [Profile] = []

        for (index, draft) in drafts.enumerated() {
            let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if name.isEmpty {
                errors.append("Profile \(index + 1): name is empty.")
                continue
            }
            guard let url = Profile.parseBaseURL(draft.urlText) else {
                errors.append("\(name): \"\(draft.urlText)\" is not a valid http(s) URL.")
                continue
            }
            profiles.append(Profile(
                id: draft.id,
                name: name,
                baseURL: url,
                label: draft.label,
                enabled: draft.enabled,
                notify: draft.notify
            ))
        }

        guard let interval = Int(intervalText.trimmingCharacters(in: .whitespaces)) else {
            errors.append("Polling interval must be a number of seconds.")
            validationErrors = errors
            return
        }

        validationErrors = errors
        guard errors.isEmpty else { return }

        let newSettings = Settings(
            displayMode: displayMode,
            pollingIntervalSeconds: interval,
            profiles: profiles
        )
        apply(newSettings)
        loadFromSettings()
    }
}
