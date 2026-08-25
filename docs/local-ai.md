# KI auf dem Gerät

## Warum lokal, nicht in der Cloud

Ein Coach, der nützlich ist, muss wissen, dass du gestern rückfällig geworden
bist, was du wiegst und wer aus deinem Umfeld heute schon trainiert hat. Genau
diese Daten haben auf einem fremden Server nichts verloren. Deshalb hat der
Coach-Pfad keinen Netzwerkzugriff — nicht als Einstellung, sondern als Aufbau.

## Zwei Implementierungen, ein Interface

```dart
abstract class CoachEngine {
  Future<CoachMessage> dailyBriefing(CoachContext context);
  Future<List<NudgeSuggestion>> nudgeSuggestions(CoachContext context);
  Future<List<String>> planAdjustments(CoachContext context);
}
```

### `HeuristicCoach` — der Boden

Regelbasiert, kein Modell, kein Netz, sofortige Antwort. Er wählt zuerst den
**Ton** aus dem Zustand:

| Ton | Wann |
| --- | --- |
| `welcome` | Tag 1–3 |
| `socialPressure` | heute offen, Freunde waren schon dran |
| `urgent` | heute offen, nach 19 Uhr |
| `celebrate` | Meilensteintag, bereits erledigt |
| `recover` | Rückfall oder gerissener Streak |
| `raiseTheBar` | 21+ Tage bei über 90 % Trefferquote |
| `steady` | sonst |

Der Ton ist nicht Kosmetik: Jemanden zu beglückwünschen, der gerade rückfällig
geworden ist, liest sich wie Hohn — und sanft zu jemandem zu sein, der es sich
bequem macht, ist genau der Grund, warum Gewohnheits-Apps nach zwei Wochen
aufhören zu wirken.

Die Formulierung wird mit dem Tagesdatum als Seed gewählt, damit sie innerhalb
eines Tages stabil bleibt. Die App neu zu öffnen soll die Ansprache nicht neu
würfeln.

### `LocalLlmCoach` — die Kür

Nutzt dieselbe Tonauswahl, formuliert aber mit einem lokalen Modell. Fällt bei
**jedem** Fehler auf den regelbasierten Coach zurück: kein Modell installiert,
Zeitüberschreitung, leere oder unparsbare Ausgabe, Absturz der Engine. Ein
Motivationsbildschirm, auf dem "Generierung fehlgeschlagen" steht, ist
schlechter als ein etwas generischer Satz.

## Ein Modell installieren

Die App lädt nichts von selbst herunter. Lade die GGUF-Datei am Rechner und leg
sie in den Modellordner, den *Einstellungen → KI auf dem Gerät* anzeigt
(`<Application Support>/models/`). Unterstützte Dateinamen stehen ebenfalls
dort — aktuell Qwen2.5 1.5B Instruct, Gemma 2 2B IT und SmolLM2 360M, jeweils
quantisiert.

## Eine Engine anbinden

Die Modellverwaltung ist fertig, die Inferenz-Engine ist ein Steckplatz. Wer
llama.cpp per FFI, MediaPipe LLM Inference oder Core ML anbindet, ruft einmal:

```dart
GgufLlmRuntime.attachBackend((prompt, maxTokens, temperature) async {
  return myEngine.complete(prompt, maxTokens: maxTokens, temp: temperature);
});
```

Ab dann liefert `coachEngineProvider` einen `LocalLlmCoach`, sobald ein Modell
im Ordner liegt. Ohne Backend bleibt alles beim regelbasierten Coach — die App
ist vollständig benutzbar, sie redet nur weniger abwechslungsreich.

## Was im Prompt steht

Zielsatz, Tag, Streak, Trefferquote, die Gewohnheiten mit ihren Serien, die
Uhrzeit und für jeden Freund Name, Streak und ob er heute schon aktiv war. Als
Text, direkt an das Modell auf diesem Gerät. Keine Telemetrie, kein
Zwischenspeicher, kein Netzwerkaufruf.
