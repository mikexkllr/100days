# Auf dem Handy testen

## Android — der schnellste Weg

Nach jedem Push baut die CI installierbare APKs.

1. Öffne den letzten grünen Lauf unter
   **Actions → CI → android-build**.
2. Lade unten das Artefakt **`hundred-days-apk`** herunter (eine ZIP-Datei).
3. Entpacken. Für praktisch jedes Handy seit 2017 ist
   **`app-arm64-v8a-release.apk`** die richtige Datei
   (`armeabi-v7a` nur für sehr alte Geräte, `x86_64` für Emulatoren).
4. Datei aufs Handy schieben — Kabel, Google Drive, an dich selbst schicken,
   egal.
5. Antippen. Android fragt nach der Erlaubnis, Apps aus dieser Quelle zu
   installieren; erlauben, installieren.

Voraussetzung: **Android 7.0 oder neuer** (minSdk 24).

Die APK ist mit dem Debug-Schlüssel signiert. Zum Testen ist das in Ordnung —
für den Play Store bräuchte es einen eigenen Upload-Key.

## Android — selbst bauen

```bash
# Einmalig: Flutter SDK und Android Studio installieren, dann
flutter doctor          # muss "Android toolchain" grün zeigen

cd app
flutter pub get

# Handy per USB anstecken, USB-Debugging in den Entwickleroptionen an
flutter devices         # muss dein Handy auflisten
flutter run --release   # baut, installiert und startet
```

`flutter run` ohne `--release` gibt dir Hot Reload — praktisch, wenn du am Code
schraubst, aber spürbar langsamer.

Nur die Datei bauen, ohne angestecktes Gerät:

```bash
flutter build apk --release --split-per-abi
# → app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## iPhone

Hier führt kein Weg an einem **Mac mit Xcode** vorbei — Apple erlaubt das
Signieren von iOS-Apps nur dort. Ein kostenloser Apple-Account reicht, die App
läuft dann sieben Tage und muss danach neu installiert werden.

```bash
cd app
flutter pub get
cd ios && pod install && cd ..

open ios/Runner.xcworkspace
```

In Xcode: **Runner → Signing & Capabilities → Team** auf deine Apple ID
setzen und die Bundle-ID auf etwas Eindeutiges ändern
(z. B. `com.deinname.hundreddays`) — `com.hundreddays.hundred_days` ist
womöglich schon vergeben.

Dann iPhone anstecken und:

```bash
flutter devices
flutter run --release
```

Beim ersten Start meldet das iPhone einen nicht vertrauenswürdigen Entwickler.
**Einstellungen → Allgemein → VPN & Geräteverwaltung → deine Apple ID →
Vertrauen.**

Ohne Mac bleibt nur TestFlight, und dafür braucht es das
Apple-Developer-Programm (99 $/Jahr) — plus jemanden mit Mac, der den Build
hochlädt.

## Was du zu zweit testen solltest

Der interessante Teil der App braucht zwei Geräte im **selben WLAN**:

1. Auf beiden Geräten das Onboarding durchlaufen.
2. Auf Gerät A: **Freunde → Einladen**, QR-Code anzeigen.
3. Auf Gerät B: **Freunde → Scannen**, Code scannen.
4. Auf beiden Geräten etwas abhaken.
5. Nach unten ziehen zum Aktualisieren — die Einträge des anderen tauchen im
   Feed auf, mit **VERIFIZIERT**-Badge, und die Liga füllt sich.

Ohne zweites Gerät funktioniert alles außer dem sozialen Teil: Ziel setzen,
Plan bekommen, abhaken, Streak, Statistiken, Coach.

Der Coach läuft ohne Modell regelbasiert — das ist der Normalfall, kein
Fehler. Siehe [`local-ai.md`](local-ai.md).

## Wenn etwas klemmt

**"App nicht installiert"** — meistens die falsche ABI. Nimm `arm64-v8a`.
Oder es liegt eine ältere Version mit anderem Signaturschlüssel drauf: erst
deinstallieren.

**Freunde finden sich nicht** — beide Geräte im selben WLAN? Gäste-WLANs und
viele Firmennetze blockieren Multicast zwischen Clients. Notfalls den
Einladungs*link* statt des QR-Codes nutzen: er enthält die IP-Adresse.

**Keine Benachrichtigungen** — Android 13+ fragt beim ersten Start; wenn du
abgelehnt hast, hilft nur Systemeinstellungen → Apps → 100 Tage →
Benachrichtigungen.
