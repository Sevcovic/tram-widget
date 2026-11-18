import Foundation

// MARK: - Language (Czech if the Mac prefers Czech, English otherwise)

let isCzech = Locale.preferredLanguages.first?.hasPrefix("cs") ?? false
func L(_ cs: String, _ en: String) -> String { isCzech ? cs : en }

// MARK: - Config

enum Config {
    /// App group shared by the app and the widget; set per team in project.yml (APP_GROUP_ID).
    static let appGroup = Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String ?? "tramwidget"
}

/// The platform the user picked (one side of a stop, e.g. Zelená C toward the city).
struct StopChoice: Codable, Hashable {
    var id: String            // GTFS id used by Golemio, e.g. U906Z3P
    var name: String          // Zelená
    var platform: String      // C
    var mode: String          // t tram, b bus, m metro, r train, y trolleybus, f ferry, l funicular
    var lines: [String]       // ["8", "18"]
    var directions: [String]  // ["Starý Hloubětín", "Vozovna Pankrác"]

    static let zelena = StopChoice(id: "U906Z3P", name: "Zelená", platform: "C", mode: "t",
                                   lines: ["8", "18"], directions: ["Starý Hloubětín", "Vozovna Pankrác"])

    var title: String { platform.isEmpty ? name : "\(name) · \(platform)" }
}

struct Departure: Codable, Hashable, Identifiable {
    var id: String
    var line: String
    var headsign: String
    var scheduled: Date
    var predicted: Date?
    var isCanceled: Bool

    var actual: Date { predicted ?? scheduled }
    var hasLiveData: Bool { predicted != nil }
    var delayMinutes: Int? {
        guard let predicted else { return nil }
        return Int((predicted.timeIntervalSince(scheduled) / 60).rounded())
    }
}

struct Snapshot: Codable {
    var fetchedAt: Date
    var departures: [Departure]
    var error: String?
    var debug: String?

    static let empty = Snapshot(fetchedAt: .distantPast, departures: [], error: nil)
}

// MARK: - Shared storage (app group)

enum SharedStore {
    static var defaults: UserDefaults { UserDefaults(suiteName: Config.appGroup) ?? .standard }

    static var apiKey: String? {
        get {
            let k = defaults.string(forKey: "golemioApiKey")?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (k?.isEmpty ?? true) ? nil : k
        }
        set { defaults.set(newValue, forKey: "golemioApiKey") }
    }

    static var stop: StopChoice {
        get {
            guard let data = defaults.data(forKey: "stop"),
                  let s = try? JSONDecoder().decode(StopChoice.self, from: data) else { return .zelena }
            return s
        }
        set {
            defaults.set(try? JSONEncoder().encode(newValue), forKey: "stop")
            defaults.removeObject(forKey: "lastSnapshot")   // old departures belong to the old stop
        }
    }

    /// Palette index per line; lines without a choice get one by their order at the stop.
    static var lineColors: [String: Int] {
        get { (defaults.dictionary(forKey: "lineColors") as? [String: Int]) ?? [:] }
        set { defaults.set(newValue, forKey: "lineColors") }
    }

    static func save(_ snapshot: Snapshot) {
        if let data = try? JSONEncoder().encode(snapshot) { defaults.set(data, forKey: "lastSnapshot") }
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
        case .noKey: return L("Chybí API klíč", "API key missing")
        case .http(let code):
            return code == 401 || code == 403 ? L("Neplatný API klíč", "Invalid API key")
                                              : L("Chyba serveru (\(code))", "Server error (\(code))")
        case .decoding(let msg): return L("Nečitelná odpověď: ", "Unreadable response: ") + msg
        }
    }
}

enum GolemioClient {
    private struct Response: Decodable {
        struct Dep: Decodable {
            struct Times: Decodable { var scheduled: String?; var predicted: String? }
            struct Route: Decodable { var short_name: String? }
            struct Trip: Decodable { var id: String?; var headsign: String?; var is_canceled: Bool? }
            struct LastStop: Decodable { var id: String?; var name: String? }
            var departure_timestamp: Times?
            var route: Route?
            var trip: Trip?
            var last_stop: LastStop?
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

    static func fetch(stopId: String = SharedStore.stop.id, apiKey: String? = SharedStore.apiKey) async throws -> [Departure] {
        guard let apiKey else { throw GolemioError.noKey }
        var comps = URLComponents(string: "https://api.golemio.cz/v2/pid/departureboards")!
        comps.queryItems = [
            .init(name: "ids", value: stopId),
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
            // that haven't started yet. `last_stop` is only set once the vehicle reports a position.
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

    static func countdown(to date: Date, from now: Date) -> String {
        let m = Int((date.timeIntervalSince(now) / 60).rounded(.down))
        return m <= 0 ? L("teď", "now") : "\(m) min"
    }

    static func delay(_ minutes: Int?) -> String {
        guard let minutes else { return L("bez polohy", "no GPS yet") }
        if minutes == 0 { return L("včas", "on time") }
        return minutes > 0 ? "+\(minutes)" : "\(minutes)"
    }

    static func age(_ fetchedAt: Date, now: Date) -> String {
        let m = Int(now.timeIntervalSince(fetchedAt) / 60)
        return m < 1 ? L("právě teď", "just now") : L("před \(m) min", "\(m) min ago")
    }
}
