import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Refresh button intent

struct RefreshIntent: AppIntent {
    static var title: LocalizedStringResource = "Obnovit odjezdy"
    func perform() async throws -> some IntentResult {
        await GolemioClient.refresh()
        return .result()   // WidgetKit reloads the timeline after an interactive intent
    }
}

// MARK: - Timeline

struct TramEntry: TimelineEntry {
    let date: Date
    let snapshot: Snapshot
    let hasKey: Bool

    /// Departures still ahead at this entry's time (drop a tram ~30 s after it should have left).
    var upcoming: [Departure] {
        snapshot.departures.filter { !$0.isCanceled && $0.actual > date.addingTimeInterval(-30) }
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> TramEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (TramEntry) -> Void) {
        if context.isPreview { completion(.sample); return }
        completion(TramEntry(date: .now, snapshot: SharedStore.load() ?? .empty, hasKey: SharedStore.apiKey != nil))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TramEntry>) -> Void) {
        Task {
            let hasKey = SharedStore.apiKey != nil
            let snap = hasKey ? await GolemioClient.refresh() : (SharedStore.load() ?? .empty)
            let now = Date.now
            // One entry per minute so countdowns stay correct between network refreshes.
            let start = Calendar.current.dateInterval(of: .minute, for: now)?.start ?? now
            var entries = [TramEntry(date: now, snapshot: snap, hasKey: hasKey)]
            for i in 1...45 {
                entries.append(TramEntry(date: start.addingTimeInterval(Double(i) * 60), snapshot: snap, hasKey: hasKey))
            }
            // Ask for fresh data soon; macOS decides when it actually happens.
            completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(5 * 60))))
        }
    }
}

// MARK: - Views

struct LineBadge: View {
    let line: String
    var body: some View {
        Text(line)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 26, height: 22)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color(red: 0.85, green: 0.12, blue: 0.16)))
    }
}

func delayColor(_ d: Departure) -> Color {
    guard let m = d.delayMinutes else { return .secondary }
    switch m {
    case ...1: return .green
    case 2...4: return .orange
    default: return .red
    }
}

struct Header: View {
    let entry: TramEntry
    var compact = false
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "tram.fill").foregroundStyle(.red).font(.caption)
            Text(Config.stopName).font(.system(size: 13, weight: .semibold))
            if !compact { Text(Config.directionLabel).font(.caption).foregroundStyle(.secondary) }
            Spacer(minLength: 4)
            Button(intent: RefreshIntent()) {
                HStack(spacing: 3) {
                    if entry.snapshot.error != nil {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                    if !compact || entry.snapshot.error == nil {
                        Text(Fmt.age(entry.snapshot.fetchedAt, now: entry.date))
                    }
                    Image(systemName: "arrow.clockwise")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

/// Medium: line · destination · scheduled · actual · delay · countdown
struct DepartureRow: View {
    let d: Departure
    let now: Date
    var body: some View {
        HStack(spacing: 8) {
            LineBadge(line: d.line)
            Text(d.headsign).font(.system(size: 12)).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            Text(Fmt.time.string(from: d.scheduled))
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(.secondary)
                .strikethrough(d.delayMinutes.map { $0 != 0 } ?? false, color: .secondary)
                .frame(width: 36, alignment: .trailing)
            Text(d.hasLiveData ? Fmt.time.string(from: d.actual) : "–")
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(delayColor(d))
                .frame(width: 36, alignment: .trailing)
            Text(Fmt.countdown(to: d.actual, from: now))
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .frame(width: 44, alignment: .trailing)
        }
    }
}

/// Small: line · countdown, scheduled → actual underneath
struct CompactRow: View {
    let d: Departure
    let now: Date
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            LineBadge(line: d.line)
            VStack(alignment: .leading, spacing: 1) {
                Text(Fmt.countdown(to: d.actual, from: now))
                    .font(.system(size: 17, weight: .semibold, design: .rounded).monospacedDigit())
                HStack(spacing: 3) {
                    Text(Fmt.time.string(from: d.scheduled)).foregroundStyle(.secondary)
                    if d.hasLiveData {
                        Text(Fmt.delay(d.delayMinutes)).foregroundStyle(delayColor(d)).fontWeight(.semibold)
                    }
                }
                .font(.system(size: 11).monospacedDigit())
            }
            Spacer(minLength: 0)
        }
    }
}

struct Message: View {
    let text: String
    var body: some View {
        Text(text).font(.caption).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .multilineTextAlignment(.center)
    }
}

struct ZelenaWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: TramEntry

    var body: some View {
        let compact = family == .systemSmall
        let deps = Array(entry.upcoming.prefix(compact ? 2 : 4))
        VStack(alignment: .leading, spacing: compact ? 8 : 6) {
            Header(entry: entry, compact: compact)
            if !entry.hasKey {
                Message(text: "Otevři aplikaci Zelená Tram a vlož API klíč.")
            } else if deps.isEmpty {
                Message(text: entry.snapshot.error ?? "Žádné odjezdy v příštích 90 min")
            } else {
                ForEach(deps) { d in
                    if compact { CompactRow(d: d, now: entry.date) } else { DepartureRow(d: d, now: entry.date) }
                }
                Spacer(minLength: 0)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

@main
struct ZelenaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ZelenaTram", provider: Provider()) { entry in
            ZelenaWidgetView(entry: entry)
        }
        .configurationDisplayName("Zelená → centrum")
        .description("Tramvaje 8 a 18 ze Zelené: jízdní řád a skutečný odjezd.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview data

extension TramEntry {
    static var sample: TramEntry {
        let now = Date.now
        func dep(_ line: String, _ head: String, _ inMin: Double, _ delay: Double?) -> Departure {
            let s = now.addingTimeInterval(inMin * 60)
            return Departure(id: "\(line)\(inMin)", line: line, headsign: head, scheduled: s,
                             predicted: delay.map { s.addingTimeInterval($0 * 60) }, isCanceled: false)
        }
        let snap = Snapshot(fetchedAt: now, departures: [
            dep("8", "Starý Hloubětín", 2, 1), dep("18", "Vozovna Pankrác", 5, 3),
            dep("8", "Starý Hloubětín", 10, 0), dep("18", "Vozovna Pankrác", 14, nil),
        ], error: nil)
        return TramEntry(date: now, snapshot: snap, hasKey: true)
    }
}
