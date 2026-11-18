import SwiftUI
import WidgetKit

@main
struct TramWidgetApp: App {
    var body: some Scene {
        WindowGroup("Tram Widget") {
            SettingsView()
                .frame(width: 460)
                .fixedSize()
        }
        .windowResizability(.contentSize)
    }
}

// MARK: - Bundled stop index (built by tools/build_stops.py from PID open data)

struct StopIndex {
    struct Platform: Identifiable, Hashable {
        let id: String, platform: String, mode: String
        let lines: [(line: String, direction: String)]
        static func == (a: Platform, b: Platform) -> Bool { a.id == b.id }
        func hash(into h: inout Hasher) { h.combine(id) }
    }
    struct Stop: Identifiable {
        let name: String, municipality: String, platforms: [Platform]
        let key: String   // folded name for search
        var id: String { name + "|" + municipality }
    }

    let stops: [Stop]

    static let shared = StopIndex()

    init() {
        guard let url = Bundle.main.url(forResource: "stops", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = obj["stops"] as? [[Any]] else { stops = []; return }
        stops = raw.compactMap { s in
            guard s.count == 3, let name = s[0] as? String, let muni = s[1] as? String, let ps = s[2] as? [[Any]] else { return nil }
            let plats: [Platform] = ps.compactMap { p in
                guard p.count == 4, let id = p[0] as? String, let pl = p[1] as? String, let mode = p[2] as? String,
                      let ls = p[3] as? [[String]] else { return nil }
                return Platform(id: id, platform: pl, mode: mode, lines: ls.compactMap { $0.count == 2 ? ($0[0], $0[1]) : nil })
            }
            return Stop(name: name, municipality: muni, platforms: plats, key: StopIndex.fold(name))
        }
    }

    static func fold(_ s: String) -> String { s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil) }

    func search(_ query: String, limit: Int = 8) -> [Stop] {
        let q = Self.fold(query.trimmingCharacters(in: .whitespaces))
        guard q.count >= 2 else { return [] }
        let prefix = stops.filter { $0.key.hasPrefix(q) }
        let contains = stops.filter { !$0.key.hasPrefix(q) && $0.key.contains(q) }
        return Array((prefix + contains).prefix(limit))
    }
}

extension StopChoice {
    init(stop: StopIndex.Stop, platform p: StopIndex.Platform) {
        var lines: [String] = [], dirs: [String] = []
        for (l, d) in p.lines {
            if !lines.contains(l) { lines.append(l) }
            if !d.isEmpty && !dirs.contains(d) { dirs.append(d) }
        }
        self.init(id: p.id, name: stop.name, platform: p.platform, mode: p.mode, lines: lines, directions: dirs)
    }
}

// MARK: - Settings window

struct SettingsView: View {
    @State private var key = SharedStore.apiKey ?? ""
    @State private var snapshot = SharedStore.load()
    @State private var stop = SharedStore.stop
    @State private var query = ""
    @State private var busy = false
    @State private var colorTick = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: TramArt.modeSymbol(stop.mode)).font(.title2).foregroundStyle(TramArt.red)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tram Widget").font(.title3.weight(.semibold))
                    Text(L("Živé odjezdy PID na ploše Macu", "Live PID departures on your Mac desktop"))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            stopSection
            keySection

            if let snapshot {
                departures(snapshot)
                    .padding(EdgeInsets(top: 24, leading: 24, bottom: 22, trailing: 24))
                    .background(LapTrack(trigger: snapshot.fetchedAt))
                    .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.quaternary.opacity(0.5)))
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                if let debug = snapshot.debug {
                    DisclosureGroup(L("Data z API (debug)", "Raw API data (debug)")) {
                        Text(debug).font(.system(size: 10, design: .monospaced)).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.caption)
                }
            }

            Text(L("Widget přidáš: pravý klik na plochu → Upravit widgety → hledej „Tram Widget“.",
                   "Add the widget: right-click the desktop → Edit Widgets → search for “Tram Widget”."))
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(20)
    }

    // MARK: Stop

    private var stopSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("1 · Zastávka", "1 · Stop")).font(.subheadline.weight(.medium))

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: TramArt.modeSymbol(stop.mode)).foregroundStyle(.secondary).frame(width: 18)
                VStack(alignment: .leading, spacing: 4) {
                    Text(stop.title).font(.body.weight(.semibold))
                    if !stop.directions.isEmpty {
                        Text(L("směr ", "towards ") + stop.directions.prefix(3).joined(separator: " · "))
                            .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                    HStack(spacing: 5) {
                        ForEach(stop.lines, id: \.self) { line in
                            Button { cycleColor(line) } label: { Badge(line: line, tick: colorTick) }
                                .buttonStyle(.plain)
                                .help(L("Klikni pro jinou barvu", "Click to change colour"))
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.quaternary.opacity(0.4)))

            TextField(L("Hledat jinou zastávku…", "Search another stop…"), text: $query)
                .textFieldStyle(.roundedBorder)

            let results = StopIndex.shared.search(query)
            if !results.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(results) { s in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Text(s.name).font(.callout.weight(.semibold))
                                if s.municipality != "Praha" && !s.municipality.isEmpty {
                                    Text(s.municipality).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            ForEach(s.platforms) { p in
                                Button { choose(s, p) } label: { PlatformRow(p: p) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.quaternary))
            } else if query.count >= 2 {
                Text(L("Nic nenalezeno", "Nothing found")).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Key

    private var keySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L("2 · Golemio API klíč", "2 · Golemio API key")).font(.subheadline.weight(.medium))
            SecureField(L("Vlož klíč z api.golemio.cz", "Paste your key from api.golemio.cz"), text: $key)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button(busy ? L("Načítám…", "Loading…") : L("Uložit a načíst", "Save & load")) { Task { await saveAndLoad() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(busy || key.trimmingCharacters(in: .whitespaces).isEmpty)
                Spacer()
                Link(L("Získat klíč zdarma", "Get a free key"), destination: URL(string: "https://api.golemio.cz/api-keys")!)
                    .font(.caption)
            }
        }
    }

    // MARK: Departures

    @ViewBuilder private func departures(_ snapshot: Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L("Nejbližší odjezdy", "Next departures")).font(.subheadline.weight(.medium))
                Spacer()
                Text(Fmt.age(snapshot.fetchedAt, now: .now)).font(.caption).foregroundStyle(.secondary)
            }
            if let err = snapshot.error {
                Label(err, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange).font(.caption)
            }
            if snapshot.departures.isEmpty && snapshot.error == nil {
                Text(L("Žádné odjezdy v příštích 90 min", "No departures in the next 90 min"))
                    .font(.callout).foregroundStyle(.secondary)
            }
            ForEach(snapshot.departures.prefix(6)) { d in
                HStack {
                    Badge(line: d.line, tick: colorTick).padding(.trailing, 4)
                    Text(d.headsign).lineLimit(1)
                    Spacer()
                    Text(Fmt.time.string(from: d.scheduled)).foregroundStyle(.secondary).monospacedDigit()
                    Text(d.hasLiveData ? Fmt.time.string(from: d.actual) : "–").fontWeight(.semibold).monospacedDigit()
                    Text(Fmt.delay(d.delayMinutes)).font(.caption).foregroundStyle(.secondary).frame(width: 70, alignment: .trailing)
                }
                .font(.callout)
            }
        }
    }

    // MARK: Actions

    private func choose(_ s: StopIndex.Stop, _ p: StopIndex.Platform) {
        stop = StopChoice(stop: s, platform: p)
        SharedStore.stop = stop
        SharedStore.lineColors = [:]
        query = ""
        snapshot = nil
        WidgetCenter.shared.reloadAllTimelines()
        if SharedStore.apiKey != nil { Task { await load() } }
    }

    private func cycleColor(_ line: String) {
        var colors = SharedStore.lineColors
        colors[line] = (TramArt.colorIndex(line, stop: stop) + 1) % TramArt.palette.count
        SharedStore.lineColors = colors
        colorTick += 1
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func saveAndLoad() async {
        SharedStore.apiKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        await load()
    }

    private func load() async {
        busy = true
        snapshot = await GolemioClient.refresh()
        WidgetCenter.shared.reloadAllTimelines()
        busy = false
    }
}

struct Badge: View {
    let line: String
    var tick = 0   // forces redraw after a colour change
    var body: some View {
        Text(line)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 4)
            .frame(minWidth: 22, minHeight: 17)
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(TramArt.lineColor(line)))
            .id(tick)
    }
}

struct PlatformRow: View {
    let p: StopIndex.Platform
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: TramArt.modeSymbol(p.mode)).foregroundStyle(.secondary).frame(width: 16)
            Text(p.platform.isEmpty ? "–" : p.platform).font(.caption.weight(.bold)).frame(width: 18, alignment: .leading)
            Text(p.lines.prefix(5).map { "\($0.line) → \($0.direction)" }.joined(separator: " · ")
                 + (p.lines.count > 5 ? " …" : ""))
                .font(.caption).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 3).padding(.horizontal, 6)
        .contentShape(Rectangle())
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.04)))
    }
}
