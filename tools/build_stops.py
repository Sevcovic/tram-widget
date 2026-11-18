"""Build a compact stop index from PID open data (https://data.pid.cz/stops/json/stops.json).

Output: [[name, municipality, [[gtfsId, platform, mode, [[line, direction], ...]], ...]], ...]
Modes: t tram, b bus, m metro, r train, y trolleybus, f ferry, l funicular.
Used by the website's stop picker and bundled into the app.
Run: python3 tools/build_stops.py tools/data-raw/stops.json site/public/stops.json Shared/stops.json
"""
import json, sys

MODES = {"tram": "t", "bus": "b", "metro": "m", "train": "r", "trolleybus": "y", "ferry": "f", "funicular": "l"}

def main(src, *outs):
    data = json.load(open(src, encoding="utf-8"))
    out = []
    for g in data["stopGroups"]:
        plats = []
        for s in g["stops"]:
            ids = s.get("gtfsIds") or []
            if not ids:
                continue
            lines, seen = [], set()
            for l in s.get("lines", []):
                key = (l["name"], l.get("direction", ""))
                if key in seen:
                    continue
                seen.add(key)
                lines.append([l["name"], l.get("direction", "")])
            if not lines:
                continue
            types = [l.get("type") for l in s.get("lines", []) if l.get("type")]
            main = max(set(types), key=types.count) if types else s.get("mainTrafficType")
            mode = MODES.get(main, "b")
            plats.append([ids[0], s.get("platform", ""), mode, lines])
        if plats:
            out.append([g["name"], g.get("municipality", ""), plats])
    out.sort(key=lambda x: x[0])
    blob = json.dumps({"generatedAt": data.get("generatedAt"), "stops": out}, ensure_ascii=False, separators=(",", ":"))
    for o in outs:
        open(o, "w", encoding="utf-8").write(blob)
    print(f"{len(out)} stops, {sum(len(s[2]) for s in out)} platforms, {len(blob.encode())//1024} KB")

if __name__ == "__main__":
    main(*sys.argv[1:])
