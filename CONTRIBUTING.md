# Mitmachen

## Aufsetzen

```bash
cd packages/hundred_core && dart pub get
cd ../../app             && flutter pub get
```

Flutter 3.27 oder neuer, Dart 3.6 oder neuer.

## Vor jedem Commit

```bash
cd packages/hundred_core && dart analyze && dart test
cd ../../app             && flutter analyze && flutter test
```

Beides muss ohne Befund durchlaufen. Die CI führt genau diese vier Befehle aus.

## Wo Code hingehört

**In `hundred_core`**, wenn es ohne Flutter, ohne Netzwerk und ohne
Dateisystem auskommt: Domänenlogik, Berechnungen, Protokoll, Prüfregeln. Diese
Grenze ist der Grund, warum sich die Teile testen lassen, die stimmen müssen.
Wenn du dort einen `import 'package:flutter/…'` brauchst, ist der Code an der
falschen Stelle oder die Schnittstelle fehlt noch.

**In `app`**, wenn es die Plattform berührt: UI, SQLite, Keystore, Sockets,
Benachrichtigungen, Kamera.

Neue Plattformfähigkeiten kommen als Port in den Kern und als Adapter in die
App — so wie `FeedStore`, `PeerTransport` und `LocalLlmRuntime`.

## Was wir bei Änderungen erwarten

- **Neue Ereignistypen** gehören in `FeedEventType.all`, sonst lehnt jede
  Gegenstelle sie als `unknownType` ab. Ereignisse sind für immer: Ein Feed,
  den heute jemand schreibt, muss in zwei Jahren noch prüfbar sein.
- **Änderungen am kanonischen Format** brechen jede bestehende Signatur. Wenn
  es sich nicht vermeiden lässt, braucht es eine Protokollversion.
- **Regeln zu Streaks, XP oder Plänen** brauchen einen Test. Nicht aus
  Prinzip — sondern weil ein Fehler dort erst nach Wochen sichtbar wird und
  dann die Historie schon falsch ist.
- **Kein Dark Pattern.** Die App darf unbequem sein; sie darf nicht täuschen.
  Keine erfundenen Freundesaktivitäten, keine ausgedachten Zahlen, keine
  künstliche Verknappung, die es nicht gibt.
- **Keine Anzeigetexte im Kern.** Neue Inhalte kommen als Bezeichner in
  `hundred_core` und als Übersetzung in die ARB-Dateien.

## Sprache

Code, Kommentare und Commit-Nachrichten sind **englisch**. Ohne Ausnahme.

Anzeigetexte stehen ausschließlich in `app/lib/l10n/*.arb`, in Deutsch und
Englisch. Ein deutscher String im Dart-Code ist ein Fehler; ein deutscher
String in `hundred_core` ist ein Architekturfehler — das Paket darf keine
Anzeigesprache kennen.

Der Ton: Duzform, direkt, ohne Kitsch. Auf Englisch dasselbe in zweiter Person.

Wer eine Zeichenkette hinzufügt, fügt sie in **beiden** Sprachen hinzu.
`flutter test test/l10n_test.dart` erzwingt das.
Details: [`docs/localization.md`](docs/localization.md).
