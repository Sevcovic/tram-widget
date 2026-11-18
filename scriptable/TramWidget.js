// Tram Widget for Scriptable: live PID (Prague) departures on your iPhone home screen.
// https://tram-widget.petrbuild.app · © 2026 Petr Ševcovic
//
// First run: tap ▶ in Scriptable, add your free Golemio API key and pick your stop.
// Optional widget parameter: a platform ID such as U906Z3P (overrides the saved stop).

const THEME = "auto";            // "auto", "light" or "dark"
const STOPS_URL = "https://tram-widget.petrbuild.app/stops.json";
const DEFAULT_STOP = { id: "U906Z3P", name: "Zelená", platform: "C", lines: ["8", "18"] };
const KEY_KC = "tramwidget.golemio";
const STOP_KC = "tramwidget.stop";

const CZ = Device.language().startsWith("cs");
const tr = (cs, en) => (CZ ? cs : en);

// ───────────────────────── Data ─────────────────────────

function savedStop() {
  const param = (args.widgetParameter || "").trim();
  if (/^U\d+Z\w+$/i.test(param)) return { id: param.toUpperCase(), name: null, platform: null, lines: null };
  if (Keychain.contains(STOP_KC)) {
    try { return JSON.parse(Keychain.get(STOP_KC)); } catch (e) {}
  }
  return DEFAULT_STOP;
}

function apiKey() {
  return Keychain.contains(KEY_KC) ? Keychain.get(KEY_KC) : null;
}

function cachePath(name) {
  const fm = FileManager.local();
  return fm.joinPath(fm.cacheDirectory(), name);
}

async function loadDepartures(stop) {
  const key = apiKey();
  if (!key) return { error: tr("Spusť skript v Scriptable a vlož API klíč.", "Run the script in Scriptable and add your API key."), deps: [] };
  const url = "https://api.golemio.cz/v2/pid/departureboards?ids=" + encodeURIComponent(stop.id) +
    "&minutesBefore=0&minutesAfter=90&limit=12&mode=departures";
  const fm = FileManager.local();
  const cache = cachePath("tramwidget-" + stop.id + ".json");
  try {
    const req = new Request(url);
    req.headers = { "X-Access-Token": key, Accept: "application/json" };
    req.timeoutInterval = 15;
    const json = await req.loadJSON();
    const code = req.response && req.response.statusCode;
    if (code && code !== 200) {
      throw new Error(code === 401 || code === 403 ? tr("Neplatný API klíč", "Invalid API key") : tr("Chyba serveru ", "Server error ") + code);
    }
    const data = parse(json, stop);
    data.fetchedAt = Date.now();
    fm.writeString(cache, JSON.stringify(data));
    return data;
  } catch (e) {
    // Keep showing the last good departures, with a warning.
    if (fm.fileExists(cache)) {
      const old = JSON.parse(fm.readString(cache));
      old.error = e.message || String(e);
      return old;
    }
    return { error: e.message || String(e), deps: [] };
  }
}

function parse(json, stop) {
  const info = (json.stops && json.stops[0]) || {};
  const deps = (json.departures || []).map((d) => {
    const ts = d.departure_timestamp || {};
    // Golemio fills `predicted` with the timetable even before a vehicle starts;
    // it is only real once the vehicle has reported a stop (last_stop).
    const live = !!(d.last_stop && (d.last_stop.id || d.last_stop.name));
    return {
      line: (d.route && d.route.short_name) || "?",
      headsign: (d.trip && d.trip.headsign) || "",
      scheduled: Date.parse(ts.scheduled),
      predicted: live && ts.predicted ? Date.parse(ts.predicted) : null,
      canceled: !!(d.trip && d.trip.is_canceled),
    };
  }).filter((d) => !isNaN(d.scheduled) && !d.canceled);
  deps.sort((a, b) => (a.predicted || a.scheduled) - (b.predicted || b.scheduled));
  return {
    name: stop.name || info.stop_name || stop.id,
    platform: stop.platform != null ? stop.platform : (info.platform_code || ""),
    lines: stop.lines,
    deps,
  };
}

// ───────────────────────── Drawing ─────────────────────────

const PALETTE = ["#296BDB", "#D9262E", "#1F9E5C", "#E8850D", "#8C52D1", "#0D99A8", "#5C6169"];

function lineColor(line, data) {
  let order = data.lines;
  if (!order || !order.length) {
    order = [...new Set(data.deps.map((d) => d.line))].sort((a, b) => (parseInt(a) || 9999) - (parseInt(b) || 9999) || a.localeCompare(b));
  }
  const i = order.indexOf(line);
  return PALETTE[i >= 0 ? i % PALETTE.length : PALETTE.length - 1];
}

// Widget sizes in points by screen height (Apple's published widget sizes).
function widgetSize(family) {
  const h = Math.max(Device.screenSize().height, Device.screenSize().width);
  const table = {
    956: [170, 364, 382], 932: [170, 364, 382], 926: [170, 364, 382], 874: [162, 344, 370],
    896: [169, 360, 379], 852: [158, 338, 354], 844: [158, 338, 354], 812: [155, 329, 345],
    780: [155, 329, 345], 736: [157, 348, 357], 667: [148, 321, 324], 568: [141, 292, 311],
  };
  const s = table[h] || [158, 338, 354];
  if (family === "small") return { w: s[0], h: s[0] };
  if (family === "large") return { w: s[1], h: s[2] };
  return { w: s[1], h: s[0] };
}

function theme() {
  const dark = THEME === "dark" || (THEME === "auto" && Device.isUsingDarkAppearance());
  return dark
    ? { dark, bg: "#1C1C1E", ink: "#F5F5F7", muted: "#98989D", rail: new Color("#EBEBF5", 0.2),
        body: "#E6E7EA", roof: "#8E9299", post: "#E6E7EA", glass: new Color("#96BED2", 0.22), glassEdge: new Color("#C8D7E1", 0.4),
        green: "#30D158", orange: "#FF9F0A", red: "#FF453A" }
    : { dark, bg: "#FFFFFF", ink: "#1D1D1F", muted: "#6E6E73", rail: new Color("#3C3C43", 0.22),
        body: "#F2F3F5", roof: "#3A3D42", post: "#C9CCD1", glass: new Color("#96B4C3", 0.28), glassEdge: new Color("#3C4650", 0.35),
        green: "#1F9D55", orange: "#E5850B", red: "#D70015" };
}

function painter(w, h) {
  const S = Device.screenScale(); // draw at native pixel scale so it stays crisp
  const dc = new DrawContext();
  dc.opaque = false;
  dc.respectScreenScale = false;
  dc.size = new Size(Math.round(w * S), Math.round(h * S));
  const col = (c) => (c instanceof Color ? c : new Color(c));
  const p = (x, y) => new Point(x * S, y * S);
  const r = (x, y, ww, hh) => new Rect(x * S, y * S, ww * S, hh * S);
  const api = {
    dc, S,
    rect(x, y, ww, hh, c) { dc.setFillColor(col(c)); dc.fillRect(r(x, y, ww, hh)); },
    round(x, y, ww, hh, rad, c) {
      const path = new Path(); path.addRoundedRect(r(x, y, ww, hh), rad * S, rad * S);
      dc.addPath(path); dc.setFillColor(col(c)); dc.fillPath();
    },
    ellipse(x, y, ww, hh, c) { dc.setFillColor(col(c)); dc.fillEllipse(r(x, y, ww, hh)); },
    line(x1, y1, x2, y2, c, lw) {
      const path = new Path(); path.move(p(x1, y1)); path.addLine(p(x2, y2));
      dc.addPath(path); dc.setStrokeColor(col(c)); dc.setLineWidth(lw * S); dc.strokePath();
    },
    shape(points, c, stroke) { // points: [[x,y], ...] or {q:[cx,cy,x,y]} for quad curves
      const path = new Path();
      points.forEach((pt, i) => {
        if (pt.q) path.addQuadCurve(p(pt.q[2], pt.q[3]), p(pt.q[0], pt.q[1]));
        else if (i === 0) path.move(p(pt[0], pt[1]));
        else path.addLine(p(pt[0], pt[1]));
      });
      path.closeSubpath();
      dc.addPath(path);
      if (stroke) { dc.setStrokeColor(col(c)); dc.setLineWidth(stroke * S); dc.strokePath(); }
      else { dc.setFillColor(col(c)); dc.fillPath(); }
    },
    railRect(inset, rad, c) {
      const path = new Path(); path.addRoundedRect(r(inset, inset, w - 2 * inset, h - 2 * inset), rad * S, rad * S);
      dc.addPath(path); dc.setStrokeColor(col(c)); dc.setLineWidth(1 * S); dc.strokePath();
    },
    text(str, x, y, ww, size, weight, c, align) {
      const f = {
        bold: Font.boldSystemFont, semibold: Font.semiboldSystemFont, medium: Font.mediumSystemFont,
        regular: Font.regularSystemFont, rounded: Font.boldRoundedSystemFont, big: Font.semiboldRoundedSystemFont,
      }[weight || "regular"];
      dc.setFont(f(size * S));
      dc.setTextColor(col(c));
      if (align === "right") dc.setTextAlignedRight(); else if (align === "center") dc.setTextAlignedCenter(); else dc.setTextAlignedLeft();
      dc.drawTextInRect(String(str), r(x, y, ww, size * 1.45));
    },
  };
  return api;
}

// Tram: 4 articulated sections in PID colours, drawn straight with its front at x, wheels on rail y.
const SEG = 15, GAP = 1.2, TRAM_LEN = 4 * SEG + 3 * GAP;
function drawTram(g, x, y, th) {
  for (let k = 0; k < 4; k++) {
    const L = SEG, x0 = x - k * (SEG + GAP) - L, top = y - 11, front = k === 0, rear = k === 3, redTop = k % 2 === 1;
    const body = front
      ? [[x0, top], [x0 + L - 4, top], { q: [x0 + L, top, x0 + L, top + 5] }, [x0 + L, y - 1], [x0, y - 1]]
      : rear
      ? [[x0 + 4, top], [x0 + L, top], [x0 + L, y - 1], [x0, y - 1], [x0, top + 5], { q: [x0, top, x0 + 4, top] }]
      : [[x0, top], [x0 + L, top], [x0 + L, y - 1], [x0, y - 1]];
    if (k === 1) { // pantograph
      g.line(x0 + 4, top, x0 + 6, top - 2.4, "#8E9299", 0.55);
      g.line(x0 + 4.6, top - 2.4, x0 + 9, top - 2.4, "#8E9299", 0.55);
    }
    g.shape(body, th.body);
    const bx = rear ? x0 + 4 : x0, bw = L - (front ? 5 : 0) - (rear ? 4 : 0);
    if (redTop) g.rect(bx, top, bw, 2.2, "#D9262E");
    g.rect(bx, top + 3, bw, 3.6, "#3B3E44");
    if (!redTop) g.rect(x0, y - 3.6, L, 2.6, "#D9262E");
    if (front) {
      g.shape([[x0 + L - 5, top], [x0 + L - 4, top], { q: [x0 + L, top, x0 + L, top + 5] }, [x0 + L, top + 8], [x0 + L - 5, top + 8]], "#2A2C30");
      g.ellipse(x0 + L - 2.1, y - 5.1, 1.4, 1.4, "#FFF7D6");
    }
    if (rear) g.shape([[x0 + 4, top], [x0 + 4, top + 7], [x0, top + 7], [x0, top + 5], { q: [x0, top, x0 + 4, top] }], "#2A2C30");
    g.rect(x0 + L / 2 - 1.6, top + 3.2, 3.2, 7.4, new Color("#000000", 0.25));
    g.shape(body, new Color("#000000", 0.18), 0.35);
    g.round(x0 + 1, y - 1, L - 2, 0.9, 0.45, new Color("#000000", 0.35));
  }
}

// Shelter like the real one at Zelená: slatted canopy, white posts, glass panel, bench, info screen.
function drawShelter(g, cx, y, th) {
  const roofY = y - 13.2;
  g.rect(cx - 0.5, y - 10.6, 11.5, 10, th.glass);
  g.shape([[cx - 0.5, y - 10.6], [cx + 11, y - 10.6], [cx + 11, y - 0.6], [cx - 0.5, y - 0.6]], th.glassEdge, 0.3);
  g.line(cx + 2, y - 10.6, cx + 2, y - 0.6, th.glassEdge, 0.25);
  g.round(cx - 3.6, y - 7.4, 2.6, 1.8, 0.3, "#2B3440");
  g.rect(cx - 3.3, y - 7.1, 2, 1.2, "#7FB4D9");
  g.round(cx - 10, y - 3.1, 10, 0.8, 0.3, th.roof);
  g.line(cx - 9, y - 2.3, cx - 9, y - 0.4, th.roof, 0.5);
  g.line(cx - 1, y - 2.3, cx - 1, y - 0.4, th.roof, 0.5);
  g.line(cx - 13, roofY + 1, cx - 13, y - 0.3, th.post, 0.9);
  g.line(cx + 12.5, roofY + 1, cx + 12.5, y - 0.3, th.post, 0.9);
  g.round(cx - 18, roofY, 36, 1.5, 0.4, th.roof);
  for (let k = 0; k < 9; k++) g.line(cx - 17 + k * 4.2, roofY + 1.5, cx - 15.4 + k * 4.2, roofY + 2.6, th.roof, 0.45);
}

const df = new DateFormatter();
df.dateFormat = "H:mm";
const hm = (ms) => df.string(new Date(ms));
const actualOf = (d) => d.predicted || d.scheduled;
const delayMin = (d) => (d.predicted == null ? null : Math.round((d.predicted - d.scheduled) / 60000));
const delayColor = (d, th) => { const m = delayMin(d); return m == null ? th.muted : m <= 1 ? th.green : m <= 4 ? th.orange : th.red; };
const delayText = (d) => { const m = delayMin(d); return m == null ? tr("bez polohy", "no GPS yet") : m === 0 ? tr("včas", "on time") : (m > 0 ? "+" : "") + m; };
// The widget is a static image that iOS redraws only now and then, so nothing on it may depend on
// "now" at viewing time: show the fetch time instead of "just now", and delays instead of countdowns.
const fetchedText = (ts) => (ts ? tr("načteno ", "updated ") + hm(ts) : "");
const badgeWidth = (line) => Math.max(22, line.length * 7 + 8);

function drawBadge(g, line, x, y, data) {
  const w = badgeWidth(line);
  g.round(x, y, w, 17, 5, lineColor(line, data));
  g.text(line, x, y + 1.6, w, 11, "rounded", "#FFFFFF", "center");
  return w;
}

function render(family, data, now) {
  const th = theme();
  const { w, h } = widgetSize(family);
  const g = painter(w, h);
  g.rect(0, 0, w, h, th.bg);
  const upcoming = data.deps.filter((d) => actualOf(d) > now - 30000);
  const title = data.name + (data.platform ? "  " + data.platform : "");

  if (family === "small") {
    const pad = 14;
    g.rect(pad, pad + 3, 3, 12, "#D9262E");
    g.text(title, pad + 8, pad, w - 2 * pad - 8, 13, "semibold", th.ink);
    g.text((data.error ? "⚠︎ " : "") + fetchedText(data.fetchedAt), pad + 8, pad + 17, w - 2 * pad, 9.5, "regular", data.error ? th.orange : th.muted);
    if (!upcoming.length) {
      g.text(data.error || tr("Žádné odjezdy", "No departures"), pad, h / 2 - 6, w - 2 * pad, 11, "regular", th.muted, "center");
    }
    upcoming.slice(0, 2).forEach((d, i) => {
      const y = 50 + i * 46;
      const bw = drawBadge(g, d.line, pad, y + 4, data);
      // Big: real departure time (or timetable time while there's no GPS yet). Small: timetable + delay.
      g.text(hm(actualOf(d)), pad + bw + 8, y, w - pad - bw - 8 - pad, 20, "big", d.predicted != null ? delayColor(d, th) : th.ink);
      g.text(hm(d.scheduled), pad + bw + 8, y + 26, 36, 11, "regular", th.muted);
      g.text(delayText(d), pad + bw + 44, y + 26, 70, 11, "semibold", delayColor(d, th));
    });
    return g.dc.getImage();
  }

  // Medium / large: rail just inside the edge, shelter on the top rail, tram approaching it.
  const inset = 15, rad = 9, pad = 24;
  g.railRect(inset, rad, th.rail);
  const stopX = w - pad - 58;
  drawShelter(g, stopX, inset, th);
  if (upcoming.length) {
    // The tram's position shows how soon the next departure is: 10+ min away = far left, "now" = at the shelter.
    const m = Math.max(0, Math.min(10, (actualOf(upcoming[0]) - now) / 60000));
    const start = inset + rad + TRAM_LEN + 4, parked = stopX + TRAM_LEN / 2;
    drawTram(g, start + (parked - start) * (1 - m / 10), inset, th);
  }

  g.text(title, pad, 22, w - 2 * pad - 110, 13, "semibold", th.ink);
  g.text((data.error ? "⚠︎ " : "") + fetchedText(data.fetchedAt) + "  ↻", w - pad - 110, 24, 110, 10, "regular", data.error ? th.orange : th.muted, "right");

  const rowH = 23, top = 44;
  const rows = Math.max(1, Math.floor((h - inset - 6 - top) / rowH));
  if (!upcoming.length) {
    g.text(data.error || tr("Žádné odjezdy v příštích 90 min", "No departures in the next 90 min"), pad, h / 2, w - 2 * pad, 12, "regular", th.muted, "center");
  }
  // Columns: timetable · real time · delay ("+2", "včas", "bez polohy"). No countdown: it would go stale.
  const cdW = 62, actW = 38, schW = 38, gap = 6;
  const cdX = w - pad - cdW, actX = cdX - gap - actW, schX = actX - gap - schW;
  upcoming.slice(0, rows).forEach((d, i) => {
    const y = top + i * rowH;
    const bw = drawBadge(g, d.line, pad, y + 1, data);
    g.text(d.headsign, pad + bw + 8, y + 2, schX - (pad + bw + 8) - 4, 12, "regular", th.ink);
    g.text(hm(d.scheduled), schX, y + 2, schW, 12, "regular", th.muted, "right");
    const dm = delayMin(d);
    if (dm != null && dm !== 0) g.line(schX + schW - 28, y + 10.5, schX + schW, y + 10.5, th.muted, 0.8);
    g.text(d.predicted != null ? hm(d.predicted) : "–", actX, y + 2, actW, 12, "semibold", delayColor(d, th), "right");
    g.text(delayText(d), cdX, y + 2.5, cdW, d.predicted == null ? 10.5 : 12, "semibold", delayColor(d, th), "right");
  });
  return g.dc.getImage();
}

async function buildWidget(family) {
  const stop = savedStop();
  const data = await loadDepartures(stop);
  const widget = new ListWidget();
  widget.setPadding(0, 0, 0, 0);
  widget.backgroundColor = new Color(theme().bg);
  widget.backgroundImage = render(family, data, Date.now());
  // Ask for a refresh every minute. iOS decides the real interval (usually 5–15 min).
  widget.refreshAfterDate = new Date(Date.now() + 60 * 1000);
  // Tapping the widget opens a fresh preview in Scriptable.
  widget.url = "scriptable:///run/" + encodeURIComponent(Script.name()) + "?preview=1";
  return widget;
}

// ───────────────────────── In-app setup ─────────────────────────

const fold = (s) => s.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();

async function loadStopIndex() {
  const fm = FileManager.local();
  const path = cachePath("tramwidget-stops.json");
  const fresh = fm.fileExists(path) && Date.now() - fm.modificationDate(path).getTime() < 30 * 86400000;
  if (!fresh) {
    const req = new Request(STOPS_URL);
    fm.writeString(path, await req.loadString());
  }
  return JSON.parse(fm.readString(path)).stops;
}

async function setKey() {
  const a = new Alert();
  a.title = tr("Golemio API klíč", "Golemio API key");
  a.message = tr("Zdarma na api.golemio.cz/api-keys. Uloží se do Klíčenky v iPhonu.",
                 "Free at api.golemio.cz/api-keys. It is stored in your iPhone's Keychain.");
  a.addSecureTextField(tr("Vlož klíč", "Paste key"), "");
  a.addAction(tr("Uložit", "Save"));
  a.addCancelAction(tr("Zrušit", "Cancel"));
  if ((await a.presentAlert()) === -1) return false;
  const k = a.textFieldValue(0).trim();
  if (k) Keychain.set(KEY_KC, k);
  return !!k;
}

async function chooseStop() {
  let stops;
  try { stops = await loadStopIndex(); }
  catch (e) {
    const a = new Alert();
    a.title = tr("Seznam zastávek nejde stáhnout", "Can't download the stop list");
    a.message = tr("Zadej ID nástupiště jako parametr widgetu (např. U906Z3P).", "Enter the platform ID as the widget parameter (e.g. U906Z3P).");
    a.addAction("OK"); await a.present(); return;
  }
  const q = new Alert();
  q.title = tr("Najdi zastávku", "Find your stop");
  q.addTextField(tr("např. Anděl", "e.g. Anděl"), "");
  q.addAction(tr("Hledat", "Search"));
  q.addCancelAction(tr("Zrušit", "Cancel"));
  if ((await q.presentAlert()) === -1) return;
  const query = fold(q.textFieldValue(0).trim());
  if (query.length < 2) return;
  const found = stops.filter((s) => fold(s[0]).startsWith(query))
    .concat(stops.filter((s) => !fold(s[0]).startsWith(query) && fold(s[0]).includes(query))).slice(0, 6);
  const options = [];
  found.forEach((s) => s[2].forEach((p) => options.push({ s, p })));
  if (!options.length) { const a = new Alert(); a.title = tr("Nic nenalezeno", "Nothing found"); a.addAction("OK"); await a.present(); return; }

  const pick = new Alert();
  pick.title = tr("Vyber nástupiště", "Pick your platform");
  pick.message = tr("Linky → směr", "Lines → direction");
  options.slice(0, 14).forEach(({ s, p }) => {
    const lines = p[3].slice(0, 4).map((l) => l[0] + " → " + l[1]).join(", ");
    pick.addAction(s[0] + (p[1] ? " " + p[1] : "") + ": " + lines);
  });
  pick.addCancelAction(tr("Zrušit", "Cancel"));
  const i = await pick.presentSheet();
  if (i === -1) return;
  const { s, p } = options[i];
  const lines = [...new Set(p[3].map((l) => l[0]))];
  Keychain.set(STOP_KC, JSON.stringify({ id: p[0], name: s[0], platform: p[1], lines }));
}

async function preview() {
  const w = await buildWidget("medium");
  await w.presentMedium();
}

async function main() {
  if (config.runsInWidget) {
    Script.setWidget(await buildWidget(config.widgetFamily || "medium"));
    Script.complete();
    return;
  }
  if (args.queryParameters && args.queryParameters.preview) { await preview(); Script.complete(); return; }

  if (!apiKey()) { await setKey(); }
  const stop = savedStop();
  const menu = new Alert();
  menu.title = "Tram Widget";
  menu.message = tr("Zastávka: ", "Stop: ") + (stop.name ? stop.name + " " + (stop.platform || "") : stop.id);
  menu.addAction(tr("Náhled widgetu", "Preview widget"));
  menu.addAction(tr("Změnit zastávku", "Change stop"));
  menu.addAction(tr("Změnit API klíč", "Change API key"));
  menu.addCancelAction(tr("Hotovo", "Done"));
  const choice = await menu.presentSheet();
  if (choice === 0) await preview();
  if (choice === 1) { await chooseStop(); await preview(); }
  if (choice === 2) { await setKey(); await preview(); }
  Script.complete();
}

await main();
