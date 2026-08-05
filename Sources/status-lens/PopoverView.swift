import AppKit
import StatusLensCore
import SwiftUI

extension ServiceStatus {
    var uiColor: Color {
        Color(nsColor: StatusBarRenderer.color(for: self))
    }
}

/// Left-click popover: per-profile detail (components → incidents →
/// scheduled maintenance) plus a small action footer.
struct PopoverView: View {
    @ObservedObject var model: AppModel
    let actions: AppActions

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.states.isEmpty {
                Text("No status fetched yet")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ForEach(Array(model.states.enumerated()), id: \.element.profile.id) { index, state in
                    if index > 0 { Divider() }
                    ProfileSection(state: state)
                }
            }
            Divider()
            footer
        }
        .padding(12)
        .frame(width: 360)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button(action: actions.refresh) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .focusable(false)
            .help("Refresh now")
            Button(action: actions.openSettings) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .focusable(false)
            .help("Settings")
            if let updated = model.lastUpdated {
                Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("status-lens \(appVersion)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Button(action: actions.quit) {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .focusable(false)
            .help("Quit status-lens")
        }
    }
}

private struct ProfileSection: View {
    let state: ProfileState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: state.status.symbolName)
                    .fontWeight(.bold)
                    .foregroundStyle(state.status.uiColor)
                Text(state.profile.name)
                    .font(.headline)
                Text(state.status.displayText)
                    .font(.caption)
                    .foregroundStyle(state.status.uiColor)
                Spacer()
                Button {
                    NSWorkspace.shared.open(state.profile.baseURL)
                } label: {
                    Image(systemName: "arrow.up.right.square")
                }
                .buttonStyle(.borderless)
                .focusable(false)
                .help("Open status page")
            }

            if let summary = state.summary {
                componentGrid(summary)
                ForEach(Array(summary.incidents.prefix(3)), id: \.id) { incident in
                    IncidentRow(incident: incident)
                }
                ForEach(Array(summary.scheduledMaintenances.prefix(2)), id: \.id) { maintenance in
                    MaintenanceRow(maintenance: maintenance)
                }
            } else if let error = state.errorDescription {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    @ViewBuilder
    private func componentGrid(_ summary: StatuspageSummary) -> some View {
        // Large pages (Cloudflare lists every PoP) collapse to noteworthy
        // components + counts so the popover height stays bounded.
        let digest = componentDigest(summary.components)
        if !digest.shown.isEmpty {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), alignment: .leading),
                    GridItem(.flexible(), alignment: .leading),
                ],
                alignment: .leading,
                spacing: 3
            ) {
                ForEach(digest.shown, id: \.id) { component in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(component.status.severity.uiColor)
                            .frame(width: 6, height: 6)
                        Text(component.name)
                            .font(.caption)
                            .lineLimit(1)
                            .help(component.name)
                    }
                }
            }
        }
        if digest.hiddenNoteworthyCount > 0 || digest.hiddenOperationalCount > 0 {
            componentSummaryLine(digest)
        }
    }

    @ViewBuilder
    private func componentSummaryLine(_ digest: ComponentDigest) -> some View {
        let allHealthy = digest.shown.isEmpty && digest.hiddenNoteworthyCount == 0
        let text: String = {
            if allHealthy {
                return "All \(digest.totalCount) components operational"
            }
            var parts: [String] = []
            if digest.hiddenNoteworthyCount > 0 {
                parts.append("+\(digest.hiddenNoteworthyCount) more degraded")
            }
            if digest.hiddenOperationalCount > 0 {
                parts.append("\(digest.hiddenOperationalCount) operational")
            }
            return parts.joined(separator: " · ")
        }()
        HStack(spacing: 4) {
            if allHealthy {
                Circle()
                    .fill(ServiceStatus.operational.uiColor)
                    .frame(width: 6, height: 6)
            }
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct IncidentRow: View {
    let incident: StatuspageSummary.Incident

    private var impactColor: Color {
        ServiceStatus(indicator: StatusIndicator(rawValue: incident.impact ?? "none")).uiColor
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(impactColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(incident.name)
                    .font(.caption)
                    .fontWeight(.medium)
                if let body = incident.incidentUpdates?.first?.body, !body.isEmpty {
                    Text(body)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if let date = parseStatuspageDate(incident.updatedAt) {
                    Text(relativeText(from: date))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

private struct MaintenanceRow: View {
    let maintenance: StatuspageSummary.ScheduledMaintenance

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.caption)
                .foregroundStyle(ServiceStatus.maintenance.uiColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(maintenance.name)
                    .font(.caption)
                    .fontWeight(.medium)
                if let date = parseStatuspageDate(maintenance.scheduledFor) {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private func relativeText(from date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: Date())
}
