import Foundation

/// Decoded shape of a Statuspage `/api/v2/summary.json` response.
///
/// Only the fields status-lens consumes are modeled. Component composition and
/// enum values are treated as open sets (see `ComponentStatus` /
/// `StatusIndicator`): pages add components and Statuspage may add states
/// without notice, and decoding must never fail on them.
public struct StatuspageSummary: Codable, Equatable, Sendable {
    public let page: Page
    public let status: OverallStatus
    public let components: [Component]
    public let incidents: [Incident]
    public let scheduledMaintenances: [ScheduledMaintenance]

    enum CodingKeys: String, CodingKey {
        case page, status, components, incidents
        case scheduledMaintenances = "scheduled_maintenances"
    }

    /// Statuspage-compatible implementations (e.g. OpenAI's page, which is
    /// not Atlassian-hosted) omit top-level keys — absent arrays decode as
    /// empty instead of failing the summary.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.page = try container.decode(Page.self, forKey: .page)
        self.status = try container.decode(OverallStatus.self, forKey: .status)
        self.components = try container.decodeIfPresent([Component].self, forKey: .components) ?? []
        self.incidents = try container.decodeIfPresent([Incident].self, forKey: .incidents) ?? []
        self.scheduledMaintenances = try container.decodeIfPresent(
            [ScheduledMaintenance].self, forKey: .scheduledMaintenances
        ) ?? []
    }

    public init(
        page: Page,
        status: OverallStatus,
        components: [Component],
        incidents: [Incident],
        scheduledMaintenances: [ScheduledMaintenance]
    ) {
        self.page = page
        self.status = status
        self.components = components
        self.incidents = incidents
        self.scheduledMaintenances = scheduledMaintenances
    }

    public struct Page: Codable, Equatable, Sendable {
        public let id: String
        public let name: String
        public let url: String?
        public let updatedAt: String?

        enum CodingKeys: String, CodingKey {
            case id, name, url
            case updatedAt = "updated_at"
        }

        public init(id: String, name: String, url: String?, updatedAt: String?) {
            self.id = id
            self.name = name
            self.url = url
            self.updatedAt = updatedAt
        }
    }

    public struct OverallStatus: Codable, Equatable, Sendable {
        public let indicator: StatusIndicator
        public let description: String

        public init(indicator: StatusIndicator, description: String) {
            self.indicator = indicator
            self.description = description
        }
    }

    public struct Component: Codable, Equatable, Sendable {
        public let id: String
        public let name: String
        public let status: ComponentStatus
        public let position: Int?
        public let group: Bool?
        public let groupId: String?
        public let onlyShowIfDegraded: Bool?

        enum CodingKeys: String, CodingKey {
            case id, name, status, position, group
            case groupId = "group_id"
            case onlyShowIfDegraded = "only_show_if_degraded"
        }

        public init(
            id: String,
            name: String,
            status: ComponentStatus,
            position: Int? = nil,
            group: Bool? = nil,
            groupId: String? = nil,
            onlyShowIfDegraded: Bool? = nil
        ) {
            self.id = id
            self.name = name
            self.status = status
            self.position = position
            self.group = group
            self.groupId = groupId
            self.onlyShowIfDegraded = onlyShowIfDegraded
        }
    }

    public struct Incident: Codable, Equatable, Sendable {
        public let id: String
        public let name: String
        public let status: String
        public let impact: String?
        public let createdAt: String?
        public let updatedAt: String?
        public let shortlink: String?
        public let incidentUpdates: [Update]?

        enum CodingKeys: String, CodingKey {
            case id, name, status, impact, shortlink
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case incidentUpdates = "incident_updates"
        }

        public struct Update: Codable, Equatable, Sendable {
            public let id: String
            public let status: String?
            public let body: String?
            public let displayAt: String?

            enum CodingKeys: String, CodingKey {
                case id, status, body
                case displayAt = "display_at"
            }
        }
    }

    public struct ScheduledMaintenance: Codable, Equatable, Sendable {
        public let id: String
        public let name: String
        public let status: String
        public let scheduledFor: String?
        public let scheduledUntil: String?
        public let shortlink: String?

        enum CodingKeys: String, CodingKey {
            case id, name, status, shortlink
            case scheduledFor = "scheduled_for"
            case scheduledUntil = "scheduled_until"
        }
    }
}

/// Overall page indicator. Statuspage documents none / minor / major /
/// critical / maintenance; anything else decodes as `.unknown` so a platform
/// addition degrades gracefully instead of failing the whole summary.
public enum StatusIndicator: Equatable, Sendable {
    case none
    case minor
    case major
    case critical
    case maintenance
    case unknown(String)

    public init(rawValue: String) {
        switch rawValue {
        case "none": self = .none
        case "minor": self = .minor
        case "major": self = .major
        case "critical": self = .critical
        case "maintenance": self = .maintenance
        default: self = .unknown(rawValue)
        }
    }

    public var rawValue: String {
        switch self {
        case .none: return "none"
        case .minor: return "minor"
        case .major: return "major"
        case .critical: return "critical"
        case .maintenance: return "maintenance"
        case .unknown(let raw): return raw
        }
    }
}

extension StatusIndicator: Codable {
    public init(from decoder: Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Per-component status. Same open-set treatment as `StatusIndicator`.
public enum ComponentStatus: Equatable, Sendable {
    case operational
    case degradedPerformance
    case partialOutage
    case majorOutage
    case underMaintenance
    case unknown(String)

    public init(rawValue: String) {
        switch rawValue {
        case "operational": self = .operational
        case "degraded_performance": self = .degradedPerformance
        case "partial_outage": self = .partialOutage
        case "major_outage": self = .majorOutage
        case "under_maintenance": self = .underMaintenance
        default: self = .unknown(rawValue)
        }
    }

    public var rawValue: String {
        switch self {
        case .operational: return "operational"
        case .degradedPerformance: return "degraded_performance"
        case .partialOutage: return "partial_outage"
        case .majorOutage: return "major_outage"
        case .underMaintenance: return "under_maintenance"
        case .unknown(let raw): return raw
        }
    }
}

extension ComponentStatus: Codable {
    public init(from decoder: Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
