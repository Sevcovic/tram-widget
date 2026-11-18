# Zelená Tram

macOS widget: next trams 8 and 18 from Zelená, platform U906Z3P (toward the city), scheduled vs. actual departure.

- Data: Golemio `GET /v2/pid/departureboards?ids=U906Z3P` (free API key, stored in the app group defaults, never in code)
- Widget refreshes when macOS allows (requested every 5 min); countdown is recomputed every minute from cached data; tap ↻ in the widget to refresh now.

Build: `xcodegen generate && xcodebuild -scheme ZelenaTram -configuration Release -derivedDataPath build -allowProvisioningUpdates build`, then copy `build/Build/Products/Release/ZelenaTram.app` to /Applications.
