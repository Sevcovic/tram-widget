# Tram Widget pro iPhone · for iPhone

[Česky](#česky) · [English](#english)

---

## Česky

Živé odjezdy z tvé zastávky PID na ploše iPhonu: čas podle jízdního řádu, skutečný čas a zpoždění. Tramvajka nahoře se blíží k zastávce podle toho, kdy jede nejbližší spoj.

### Co potřebuješ
1. **Scriptable**, zdarma v App Store (autor Simon B. Støvring).
2. **Golemio API klíč**, zdarma na [api.golemio.cz/api-keys](https://api.golemio.cz/api-keys). Registrace zabere minutu.
3. **Skript** [`TramWidget.js`](TramWidget.js), celý jeho obsah.

### Postup
1. Otevři Scriptable a klepni na **+** vpravo nahoře.
2. Vlož celý skript (zkopíruj všechno od prvního do posledního řádku).
3. Nahoře klepni na název skriptu a pojmenuj ho **Tram Widget**. Klepni **Done**.
4. Klepni na ▶︎ (spustit). Skript se zeptá na **API klíč**: vlož ho a dej **Uložit**. Klíč se uloží do Klíčenky v iPhonu, ve skriptu není.
5. V menu zvol **Změnit zastávku**, napiš název (např. *Anděl*) a vyber nástupiště. Uvidíš linky a směr, tak vybereš tu správnou stranu ulice.
6. Zobrazí se náhled widgetu. Když vypadá dobře, přidej ho na plochu.

### Přidání na plochu
1. Podrž prst na prázdném místě plochy, až se ikony rozvlní.
2. Vlevo nahoře klepni na **Upravit** → **Přidat widget**.
3. Najdi **Scriptable**, vyber **střední** velikost (nebo malou / velkou) a klepni **Přidat widget**.
4. Klepni na přidaný widget (pořád v režimu úprav). U **Script** vyber **Tram Widget**.
5. **When Interacting** nech na **Run Script**. Klepnutí na widget pak otevře čerstvý náhled.
6. Klepni mimo a pak **Hotovo**.

### Víc zastávek
Přidej další widget Scriptable se stejným skriptem a do pole **Parameter** napiš ID nástupiště, např. `U906Z3P` (Zelená C). Parametr má přednost před uloženou zastávkou. ID najdeš ve výběru zastávek na [tram-widget.petrbuild.app](https://tram-widget.petrbuild.app).

### Dobré vědět
- **Obnovování:** skript si říká o novou verzi každou minutu, ale kdy widget opravdu obnoví, rozhoduje iOS. Obvykle je to každých 5–15 minut. Vpravo nahoře vidíš, kdy se data naposledy načetla („načteno 22:32“). Widget je obrázek, který iOS překresluje jen občas, proto neodpočítává minuty; ukazuje časy odjezdů a zpoždění, které zůstávají pravdivé.
- **„bez polohy“** znamená, že spoj ještě nevyjel nebo zatím neposlal polohu. Do té doby platí čas z jízdního řádu.
- **⚠︎** znamená, že se data nepodařilo načíst. Widget ukazuje poslední známé odjezdy.
- **Tmavý režim:** skript se řídí vzhledem iPhonu. Chceš-li ho napevno, změň na začátku skriptu `THEME` na `"light"` nebo `"dark"`.

---

## English

Live departures from your Prague (PID) stop on your iPhone home screen: timetable time, real time and delay. The little tram on top moves toward the stop as the next departure gets closer.

### What you need
1. **Scriptable**, free on the App Store (by Simon B. Støvring).
2. **A Golemio API key**, free at [api.golemio.cz/api-keys](https://api.golemio.cz/api-keys). Signing up takes a minute.
3. **The script** [`TramWidget.js`](TramWidget.js), all of it.

### Steps
1. Open Scriptable and tap **+** in the top right.
2. Paste the whole script (copy everything from the first line to the last).
3. Tap the script name at the top and call it **Tram Widget**. Tap **Done**.
4. Tap ▶︎ (run). The script asks for your **API key**: paste it and tap **Save**. The key goes into your iPhone's Keychain, not into the script.
5. In the menu pick **Change stop**, type a name (e.g. *Anděl*) and choose your platform. You'll see the lines and directions, so you can pick the right side of the street.
6. A preview of the widget appears. If it looks right, add it to your home screen.

### Add it to your home screen
1. Touch and hold an empty spot on the home screen until the icons jiggle.
2. Tap **Edit** in the top left → **Add Widget**.
3. Find **Scriptable**, choose the **medium** size (or small / large) and tap **Add Widget**.
4. Tap the new widget (still in edit mode). Under **Script** choose **Tram Widget**.
5. Leave **When Interacting** on **Run Script**. Tapping the widget then opens a fresh preview.
6. Tap outside, then **Done**.

### More stops
Add another Scriptable widget with the same script and type a platform ID into **Parameter**, e.g. `U906Z3P` (Zelená C). The parameter wins over the saved stop. Find IDs in the stop picker on [tram-widget.petrbuild.app](https://tram-widget.petrbuild.app).

### Good to know
- **Refreshing:** the script asks for a refresh every minute, but iOS decides when it actually happens, usually every 5–15 minutes. The top right shows when the data was loaded ("updated 22:32"). The widget is an image that iOS only redraws now and then, so it doesn't count down minutes; it shows departure times and delays, which stay true.
- **"no GPS yet"** means the vehicle hasn't started or hasn't reported its position yet. Until then the timetable time applies.
- **⚠︎** means loading failed. The widget shows the last known departures.
- **Dark mode:** the script follows your iPhone's appearance. To fix it, change `THEME` at the top of the script to `"light"` or `"dark"`.
