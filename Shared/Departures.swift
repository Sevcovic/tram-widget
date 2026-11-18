import Foundation

/// Platform U906Z3P: Zelená, trams toward the city (8 → Starý Hloubětín, 18 → Vozovna Pankrác).
enum Config {
    static let stopId = "U906Z3P"
    static let stopName = "Zelená"
    static let directionLabel = "do centra"
    static let appGroup = "M4UR3N7X2Y.zelenatram"
    static let apiKeyDefaultsKey = "golemioApiKey"
}

struct Departure: Codable, Hashable, Identifiable {
    var id: String
    var line: String
    var headsign: String
    var scheduled: Date
    var predicted: Date?
    var isCanceled: Bool

    /// Best known departure time.
    var actual: Date { predicted ?? scheduled }
    var hasLiveData: Bool { predicted != nil }
    /// Delay in whole minutes (rounded), nil without live data.
    var delayMinutes: Int? {
        guard let predicted else { return nil }
        return Int((predicted.timeIntervalSince(scheduled) / 60).rounded())
    }
}

struct Snapshot: Codable {
    var fetchedAt: Date
    var departures: [Departure]
    var error: String?
    /// Raw timestamps + delay of the first departures, for checking what Golemio actually sends.
    var debug: String?

    static let empty = Snapshot(fetchedAt: .distantPast, departures: [], error: nil)
}

// MARK: - Shared storage (app group)

enum SharedStore {
    static var defaults: UserDefaults { UserDefaults(suiteName: Config.appGroup) ?? .standard }

    static var apiKey: String? {
        get {
            let k = defaults.string(forKey: Config.apiKeyDefaultsKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (k?.isEmpty ?? true) ? nil : k
        }
        set { defaults.set(newValue, forKey: Config.apiKeyDefaultsKey) }
    }

    static func save(_ snapshot: Snapshot) {
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: "lastSnapshot")
        }
    }

    static func load() -> Snapshot? {
        guard let data = defaults.data(forKey: "lastSnapshot") else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }
}

// MARK: - Golemio API

enum GolemioError: LocalizedError {
    case noKey, http(Int), decoding(String)
    var errorDescription: String? {
        switch self {
        case .noKey: return "Chybí API klíč"
        case .http(let code): return code == 401 || code == 403 ? "Neplatný API klíč" : "Chyba serveru (\(code))"
        case .decoding(let msg): return "Nečitelná odpověď: \(msg)"
        }
    }
}

enum GolemioClient {
    // Response shape of GET /v2/pid/departureboards (only the fields we need; all optional to be tolerant).
    private struct Response: Decodable {
        struct Dep: Decodable {
            struct Times: Decodable { var scheduled: String?; var predicted: String? }
            struct Route: Decodable { var short_name: String? }
            struct Trip: Decodable { var id: String?; var headsign: String?; var is_canceled: Bool? }
            struct LastStop: Decodable { var id: String?; var name: String? }
            var departure_timestamp: Times?
            var last_stop: LastStop?
            var route: Route?
            var trip: Trip?
        }
        var departures: [Dep]?
    }

    static var lastDebug: String?

    private static func debugSummary(_ data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let deps = obj["departures"] as? [[String: Any]] else { return nil }
        return deps.prefix(4).map { d in
            let line = (d["route"] as? [String: Any])?["short_name"] ?? "?"
            let dep = d["departure_timestamp"] ?? "-"
            let delay = d["delay"] ?? "-"
            let pos = (d["last_stop"] as? [String: Any])?["name"] ?? "-"
            return "\(line): departure=\(dep) delay=\(delay) last_stop=\(pos)"
        }.joined(separator: "\n")
    }

    static func fetch(apiKey: String? = SharedStore.apiKey) async throws -> [Departure] {
        guard let apiKey else { throw GolemioError.noKey }
        var comps = URLComponents(string: "https://api.golemio.cz/v2/pid/departureboards")!
        comps.queryItems = [
            .init(name: "ids", value: Config.stopId),
            .init(name: "minutesBefore", value: "0"),
            .init(name: "minutesAfter", value: "90"),
            .init(name: "limit", value: "12"),
            .init(name: "mode", value: "departures"),
        ]
        var req = URLRequest(url: comps.url!, timeoutInterval: 15)
        req.setValue(apiKey, forHTTPHeaderField: "X-Access-Token")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode != 200 { throw GolemioError.http(http.statusCode) }

        lastDebug = debugSummary(data)
        let decoded: Response
        do { decoded = try JSONDecoder().decode(Response.self, from: data) }
        catch { throw GolemioError.decoding(error.localizedDescription) }

        return (decoded.departures ?? []).compactMap { d in
            guard let sched = d.departure_timestamp?.scheduled.flatMap(parseDate) else { return nil }
            // Golemio fills `predicted` with the timetable (and says delay.is_available = true) even for trips
            // that haven't started yet. `last_stop` is only set once the vehicle reports a position, so use that.
            let live = d.last_stop?.id != nil || d.last_stop?.name != nil
            let pred = live ? d.departure_timestamp?.predicted.flatMap(parseDate) : nil
            let line = d.route?.short_name ?? "?"
            return Departure(
                id: (d.trip?.id ?? line) + "-\(sched.timeIntervalSince1970)",
                line: line,
                headsign: d.trip?.headsign ?? "",
                scheduled: sched,
                predicted: pred,
                isCanceled: d.trip?.is_canceled ?? false
            )
        }
        .sorted { $0.actual < $1.actual }
    }

    /// Fetch and store; never throws, errors are kept in the snapshot next to the last good departures.
    @discardableResult
    static func refresh() async -> Snapshot {
        do {
            let deps = try await fetch()
            let snap = Snapshot(fetchedAt: .now, departures: deps, error: nil, debug: lastDebug)
            SharedStore.save(snap)
            return snap
        } catch {
            var snap = SharedStore.load() ?? .empty
            snap.error = error.localizedDescription
            SharedStore.save(snap)
            return snap
        }
    }

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f
    }()
    private static let isoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f
    }()
    static func parseDate(_ s: String) -> Date? { iso.date(from: s) ?? isoFrac.date(from: s) }
}

// MARK: - Formatting

enum Fmt {
    static let time: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "H:mm"; f.timeZone = TimeZone(identifier: "Europe/Prague"); return f
    }()

    /// "teď", "2 min", "14 min"
    static func countdown(to date: Date, from now: Date) -> String {
        let m = Int((date.timeIntervalSince(now) / 60).rounded(.down))
        return m <= 0 ? "teď" : "\(m) min"
    }

    static func delay(_ minutes: Int?) -> String {
        guard let minutes else { return "bez polohy" }
        if minutes == 0 { return "včas" }
        return minutes > 0 ? "+\(minutes)" : "\(minutes)"
    }

    static func age(_ fetchedAt: Date, now: Date) -> String {
        let m = Int(now.timeIntervalSince(fetchedAt) / 60)
        return m < 1 ? "právě teď" : "před \(m) min"
    }
}
