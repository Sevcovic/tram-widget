import SwiftUI
import WidgetKit

@main
struct ZelenaTramApp: App {
    var body: some Scene {
        WindowGroup("Zelená Tram") {
            SettingsView()
                .frame(width: 440)
                .fixedSize()
        }
        .windowResizability(.contentSize)
    }
}

struct SettingsView: View {
    @State private var key = SharedStore.apiKey ?? ""
    @State private var snapshot = SharedStore.load()
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "tram.fill").font(.title2).foregroundStyle(.red)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Zelená → centrum").font(.title3.weight(.semibold))
                    Text("Nástupiště \(Config.stopId) · tramvaje 8 a 18").font(.caption).foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Golemio API klíč").font(.subheadline.weight(.medium))
                SecureField("Vlož klíč z api.golemio.cz", text: $key)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button(busy ? "Načítám…" : "Uložit a otestovat") { Task { await saveAndTest() } }
                        .keyboardShortcut(.defaultAction)
                        .disabled(busy || key.trimmingCharacters(in: .whitespaces).isEmpty)
                    Spacer()
                    Link("Získat klíč", destination: URL(string: "https://api.golemio.cz/api-keys")!)
                        .font(.caption)
                }
            }

            Divider()

            if let snapshot {
                departures(snapshot)
                    .padding(EdgeInsets(top: 24, leading: 24, bottom: 22, trailing: 24))
                    .background(LapTrack(trigger: snapshot.fetchedAt))
                    .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.quaternary.opacity(0.5)))
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                if let debug = snapshot.debug {
                    DisclosureGroup("Data z API (debug)") {
                        Text(debug).font(.system(size: 10, design: .monospaced)).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.caption)
                }
            } else {
                Text("Po uložení klíče se tu ukážou odjezdy.").font(.callout).foregroundStyle(.secondary)
            }

            Text("Widget přidáš: pravý klik na plochu → Upravit widgety → hledej „Zelená“.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(20)
    }

    @ViewBuilder private func departures(_ snapshot: Snapshot) -> some View {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Nejbližší odjezdy").font(.subheadline.weight(.medium))
                        Spacer()
                        Text("Aktualizováno \(Fmt.age(snapshot.fetchedAt, now: .now))").font(.caption).foregroundStyle(.secondary)
                    }
                    if let err = snapshot.error {
                        Label(err, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange).font(.caption)
                    }
                    ForEach(snapshot.departures.prefix(6)) { d in
                        HStack {
                            Text(d.line).font(.body.weight(.bold).monospacedDigit()).frame(width: 28, alignment: .leading)
                            Text(d.headsign).lineLimit(1)
                            Spacer()
                            Text(Fmt.time.string(from: d.scheduled)).foregroundStyle(.secondary).monospacedDigit()
                            Text(d.hasLiveData ? Fmt.time.string(from: d.actual) : "–").fontWeight(.semibold).monospacedDigit()
                            Text(Fmt.delay(d.delayMinutes)).font(.caption).foregroundStyle(.secondary).frame(width: 64, alignment: .trailing)
                        }
                        .font(.callout)
                    }
                }
    }

    private func saveAndTest() async {
        busy = true
        SharedStore.apiKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        snapshot = await GolemioClient.refresh()
        WidgetCenter.shared.reloadAllTimelines()
        busy = false
    }
}
