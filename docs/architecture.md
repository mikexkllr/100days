# Architektur

## Zwei Pakete, eine Grenze

```
packages/hundred_core/     reines Dart — keine Flutter-, Netzwerk- oder
                           Dateisystemabhängigkeit
app/                       Flutter — UI, Persistenz, Transporte, Plattform
```

Die Grenze ist keine Geschmacksfrage. Alles, was stimmen *muss* — die
Kettenprüfung, die Streak-Arithmetik, die Kalorienformel, eine vollständige
Sync-Runde — liegt im Kern und ist ohne Emulator, ohne Kamera und ohne zwei
Telefone im selben WLAN testbar. Der Kern hat über 100 Tests, die in zwei
Sekunden durchlaufen.

Der Kern kennt außerdem **keine Anzeigesprache**. Er liefert Bezeichner
(`HabitCategory.noSugar`, `exerciseId`, `CoachTemplate`), die App formuliert
daraus Sätze. Siehe [`localization.md`](localization.md).

## Der Feed ist die einzige Wahrheit

Es gibt keinen Zustand "neben" dem Log. Jede Aktion — Profil setzen, Challenge
starten, Check-in, Rückfall, Streak einfrieren, Anstupser, Aufstieg — wird ein
Eintrag im eigenen Feed. Alles, was auf dem Bildschirm steht, ist eine Faltung
über diese Einträge (`projectUser`).

Das hat zwei praktische Konsequenzen:

1. **Ein fremder Streak ist berechnet, nicht behauptet.** Dein Gerät faltet die
   signierten Einträge deines Freundes selbst. Es gibt keine Zahl, die man
   fälschen könnte, ohne die Signatur zu brechen.
2. **Replikation ist trivial.** Feeds zusammenführen heißt fehlende Einträge
   anhängen. Kein Merge-Konflikt, keine Konsensrunde — jede DID schreibt nur
   ihren eigenen Feed.

```
FeedEvent { author, seq, prev, timestamp, type, payload, hash, sig }
             │      │      │                                 │     │
             │      │      └── Hash des Vorgängers ──────────┘     │
             │      └───────── lückenlos ab 1                      │
             └──────────────── did:key des einzigen Schreibers ────┘
```

`hash` ist SHA-256 über die kanonische JSON-Kodierung des Rumpfs
(Schlüssel sortiert, kein Leerraum — sonst leiten zwei Geräte
unterschiedliche Bytes aus demselben Ereignis ab und jede Prüfung schlägt
fehl). `sig` ist Ed25519 über diesen Hash.

## Schichten

```
   UI (Flutter)
      │  liest AppSnapshot, ruft AppController
   ▼
   AppController (Riverpod AsyncNotifier)
      │  debounced Neuprojektion bei jedem Feed-Ereignis
   ▼
   AppRepository ──── FeedWriter ──► FeedStore ──► SQLite
      │                                  ▲
      │                                  │
      │              FeedReplicator ─────┘   (einziger Punkt, an dem
      │                     ▲                 fremde Bytes zu Zustand werden)
      ▼                     │
   projectUser()        Syncer ◄──── PeerTransport ◄──── LAN / künftig Relay
```

**Warum die Neuprojektion entprellt ist:** Eine Sync-Runde kann zweihundert
Ereignisse in einem Rutsch anliefern. Pro Ereignis neu zu projizieren würde die
Oberfläche ruckeln lassen; 120 ms Sammelfenster reichen.

**Warum `FeedReplicator` der einzige Eingang ist:** Es soll genau eine Stelle
geben, an der ungeprüfte Bytes zu vertrauenswürdigem Zustand werden. Sie prüft
Typ, Hash, Signatur, Sequenz, Kettenglied und Zeitstempel — und bricht beim
ersten Fehler für diesen Autor ab, weil hinter einem gebrochenen Glied nichts
mehr überprüfbar ist.

## Ports und Adapter

Der Kern definiert Schnittstellen, die App liefert die Implementierungen:

| Port (Kern) | Adapter (App) | Test-Doppel |
| --- | --- | --- |
| `FeedStore` | `SqliteFeedStore` | `MemoryFeedStore` |
| `PeerTransport` / `PeerSession` | `LanTransport` / `SocketPeerSession` | `LoopbackSession` |
| `LocalLlmRuntime` | `GgufLlmRuntime` | Fake im Test |
| `CoachEngine` | — | `HeuristicCoach` ist selbst die Rückfallebene |

Die Sync-Logik ist gegen `LoopbackSession` getestet — zwei Knoten im selben
Prozess, echte Protokollrunde. Ungetestet bleibt damit nur die Socket-Klempnerei,
und das ist der Teil, den man ohnehin nicht sinnvoll simulieren kann.

## Zeit

Streaks sind an *lokale Kalendertage* gebunden, nicht an Zeitpunkte. Ein
Check-in um 23:59 und einer um 00:01 sind zwei Tage, auch wenn zwei Minuten
dazwischen liegen — genau das bedeutet ein Streak für einen Menschen. Dafür
gibt es `DayKey`; `DateTime` taucht nur an den Rändern auf.

Ereignisse tragen zwei Zeiten: den beanspruchten Tag (`payload.day`) und den
Zeitpunkt des Schreibens (`timestamp`). Weichen sie ab, war es ein Nachtrag,
und der Feed sagt das.

## Streak-Regeln

- Ein Tag zählt, wenn **alle für diesen Tag geplanten** Gewohnheiten das Ziel
  erreichen und kein Rückfall eingetragen ist. Ein halber Tag ist kein Tag.
- **Pausentage brechen nichts.** Wer viermal die Woche trainiert, wird nicht für
  Mittwoch bestraft. `kWeekdaySpread` legt fest, welche Wochentage bei N Tagen
  pro Woche belegt sind — deterministisch, damit jedes Gerät dieselbe Antwort
  berechnet.
- **Heute ist offen bis Mitternacht.** Ein noch nicht erledigter heutiger Tag
  bricht den Streak nicht, er markiert ihn als gefährdet.
- **Abstinenz zählt anders.** Ein vergessener Haken setzt keine Abstinenzserie
  zurück — nur ein eingestandener Rückfall tut das. Andernfalls steigen Leute
  aus, und das ist der schlechtere Fehler.
- **Streak-Freeze** ist knapp (drei pro Zyklus) und hält den Streak, zählt aber
  nicht als erledigter Tag. Wenn ein verpasster Tag gratis wäre, fiele der
  ganze Sinn der App in sich zusammen.

## XP, Level, Liga

XP pro Check-in skaliert mit Schwierigkeit (1–5 aus dem Katalog), Streak-Länge
(bis zu 2× bei 50 Tagen) und einem Bonus, wenn am selben Tag eingetragen wurde.
Dazu ein Bonus für den vollständigen Tag und für Meilensteintage.

Wichtig: `_computeXpByDay` spielt die Challenge Tag für Tag nach, damit jeder
Check-in mit dem Streak bewertet wird, den man *damals* hatte. Mit dem heutigen
Streak zu rechnen würde jede Vergangenheit rückwirkend aufblasen.

Die Wochenliga bucketet XP nach ISO-Woche. Auf- und Abstieg greifen erst ab
sechs Teilnehmern — darunter ist ein Rang keine Aussage.
