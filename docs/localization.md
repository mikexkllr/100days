# Mehrsprachigkeit

Die App spricht **Deutsch und Englisch** und richtet sich standardmäßig nach der
Systemsprache des Geräts. Wer das anders will, stellt es unter
*Einstellungen → Sprache* um; die Wahl überlebt Neustarts.

Der **Code ist durchgehend englisch** — Bezeichner, Kommentare,
Commit-Nachrichten. Deutsch existiert nur noch als Übersetzungsdatei.

## Die eine Regel

`hundred_core` enthält **keinen einzigen Anzeigetext**.

Das Paket liefert Bezeichner und Zahlen — `HabitCategory.noSugar`,
`exerciseId: 'back_squat'`, `AbstinenceMilestone(track: alcohol, day: 14)`,
`CoachTemplate.pressureTheySeeYourFeed`. Formuliert wird ausschließlich in der
App, gegen `AppLocalizations`.

Das ist keine Stilfrage. Ein Trainingsplan-Generator, der `nameDe` in seine
Datenstruktur schreibt, ist für englische Nutzer unbrauchbar, und eine
Streak-Berechnung, die von der Anzeigesprache abhängen kann, ist ein Fehler,
der erst beim ersten ausländischen Nutzer auffällt. Die Grenze verhindert
beides bauartbedingt: `hundred_core` importiert `flutter` nicht und kann
deshalb gar nicht auf Übersetzungen zugreifen.

## Wo was liegt

```
app/lib/l10n/
  app_en.arb            Englisch (Vorlage)
  app_de.arb            Deutsch
  generated/            von `flutter gen-l10n` erzeugt, nicht von Hand ändern
  core_l10n.dart        Gewohnheiten, Ziele, Stufen, Ligen, Einheiten, Zeiten
  plan_l10n.dart        Workouts, Splits, Mahlzeiten, Meilensteine, Makro-Text
  exercise_l10n.dart    Übungsnamen und Ausführungshinweise
  coach_l10n.dart       Coach-Direktiven, Anstupser, Plan-Tipps
  social_l10n.dart      Feed-Zeilen, Peer-Status
  prompt_l10n.dart      Prompts für das lokale Sprachmodell
  l10n.dart             Sammel-Import plus `context.l10n`
```

In einem Screen sieht das so aus:

```dart
import '../../l10n/l10n.dart';

Text(context.l10n.homeCheckOffToday)
Text(l10n.habitTitle(habit.category))
Text(l10n.coachBody(directive))
```

## Der Coach

Der Coach ist der Teil, bei dem „Text raus aus dem Core" am meisten kostet und
am meisten bringt. Statt fertiger Sätze liefert er eine **Direktive**:

```dart
CoachDirective(
  tone: CoachTone.socialPressure,
  template: CoachTemplate.pressureTheySeeYourFeed,
  peers: [PeerMention(displayName: 'Marcel', streak: 30, …)],
  streak: 12, dayNumber: 41, …
)
```

Welcher Satz zur Lage passt, entscheidet der Core — testbar, ohne auf Prosa zu
prüfen. Wie er klingt, entscheidet die Sprachdatei.

Jede Formulierungsvariante ist ein eigener `CoachTemplate`-Wert und kein Index
in eine Liste. Sonst könnte eine Übersetzung mit anderer Variantenzahl
stillschweigend den falschen Satz ziehen.

Auch der **Prompt** für das lokale Modell ist übersetzt: ein deutsches Modell
mit englischem Prompt nach deutscher Ausgabe zu fragen, funktioniert schlecht.
Deshalb ist `CoachPromptBuilder` ein Port; die App liefert
`LocalizedCoachPrompts`, das Paket selbst bringt nur eine englische Fassung
mit, damit es allein lauffähig und testbar bleibt.

## Was nicht übersetzt wird

- **Vom Nutzer geschriebener Text** — der Zielsatz, Notizen, eigene
  Gewohnheitsnamen, Anstupser-Nachrichten. Wird verbatim angezeigt.
- **Emoji.** Sprachneutral, bleiben im Core.
- **Das Wire-Format.** Ereignisse tragen Bezeichner, nie übersetzte Strings.
  Deshalb steht im `challenge.ascended`-Ereignis nur `cycle: 3` — dein
  englischer Freund liest daraus „Beyond the 100", du liest „Jenseits der 100",
  aus demselben signierten Byte-Block.

## Eine Sprache hinzufügen

1. `app/lib/l10n/app_xx.arb` anlegen, `app_en.arb` als Vorlage.
2. Locale in `kSupportedLocales` (`app/lib/data/locale_store.dart`) ergänzen.
3. `flutter gen-l10n`.
4. `flutter test test/l10n_test.dart` — der Test läuft über *jede*
   Gewohnheit, jedes Ziel, jede Übung, jeden Meilenstein, jedes
   Coach-Template und meldet, was fehlt.

Am Code ist nichts zu ändern. Wenn doch, ist etwas an der falschen Stelle.

## Wogegen die Tests absichern

`app/test/l10n_test.dart` prüft:

- beide ARB-Dateien haben **exakt dieselben Schlüssel** — eine vergessene
  Übersetzung ist ein roter Test, kein englischer Fetzen im deutschen UI
- kein leerer Wert
- **gleiche Platzhalter** in beiden Sprachen (sonst wirft `gen-l10n` zur
  Laufzeit)
- jeder Enum-Wert und jede ID aus `hundred_core` hat in **beiden** Sprachen
  Text — das fängt den vergessenen `switch`-Fall
- Plurale beugen tatsächlich („1 Tag" vs. „9 Tage", „1 day" vs. „9 days")
- Stichproben unterscheiden sich zwischen den Sprachen, sind also übersetzt
  und nicht kopiert

Dazu Widget-Tests, die denselben Zustand einmal auf Deutsch und einmal auf
Englisch rendern und prüfen, dass nichts von der anderen Sprache stehen bleibt.
