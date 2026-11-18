# Tram Widget

macOS desktop widget with live departures from any Prague (PID) stop: timetable time, real time and delay, plus a little tram that pulls into the stop on every refresh.

- **Data:** Golemio `GET /v2/pid/departureboards?ids=<platform>` (free API key from api.golemio.cz, stored in the app group, never in code)
- **Stops:** bundled index built from PID open data by `tools/build_stops.py` (also used by the website's stop picker)
- **Live vs. timetable:** a departure counts as live only once Golemio reports `last_stop`; before that it shows "no GPS yet"
- **Widget refresh:** requested every 5 min (macOS decides), countdown recomputed every minute, ↻ refreshes now

## Build it yourself

1. `brew install xcodegen`
2. In `project.yml` change `DEVELOPMENT_TEAM` and `BUNDLE_PREFIX` (the two ▶ lines)
3. `xcodegen generate && open TramWidget.xcodeproj`, then Run
4. In the app: pick your stop, paste your Golemio key, then add the widget (right-click desktop → Edit Widgets)

Refresh the stop index: download https://data.pid.cz/stops/json/stops.json to `tools/data-raw/` and run
`python3 tools/build_stops.py tools/data-raw/stops.json site/public/stops.json App/Resources/stops.json`.
