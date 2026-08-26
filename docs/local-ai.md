# AI on the device

## Why local rather than in the cloud

A coach that is useful has to know that you relapsed yesterday, what you weigh
and who around you already trained today. That is exactly the data that has no
business on someone else's server. So the coach path has no network access —
not as a setting, but by construction.

## Two implementations, one interface

```dart
abstract class CoachEngine {
  Future<CoachDirective> dailyBriefing(CoachContext context);
  Future<List<NudgeSuggestion>> nudgeSuggestions(CoachContext context);
  Future<List<PlanAdvice>> planAdjustments(CoachContext context);
}
```

### `HeuristicCoach` — the floor

Rule-based, no model, no network, instant answer. It picks the **tone** from
your state first:

| Tone | When |
| --- | --- |
| `welcome` | day 1–3 |
| `socialPressure` | today still open, friends already went |
| `urgent` | today still open, after 7pm |
| `celebrate` | milestone day, already done |
| `recover` | relapse or a broken streak |
| `raiseTheBar` | 21+ days at over 90% hit rate |
| `steady` | otherwise |

The tone is not cosmetic: congratulating someone who just relapsed reads as
mockery, and being gentle with someone who is coasting is precisely why habit
apps stop working after two weeks.

From the tone it picks a `CoachTemplate` — seeded with the day's date so the
message stays stable within a day. The coach returns **no sentence**, only a
directive made of a template, numbers and names; the wording happens in the
app. That is what lets the same rules drive a German and an English user.

### `LocalLlmCoach` — the upgrade

Uses the same tone selection but phrases it with a local model. It falls back
to the rule-based coach on **every** failure: no model installed, timeout,
empty or unparseable output, engine crash. A motivation screen that says
"generation failed" is worse than a slightly generic sentence.

## Installing a model

The app downloads nothing by itself. Fetch the GGUF file on a computer and drop
it in the model folder shown under *Settings → On-device AI*
(`<Application Support>/models/`). Supported filenames are listed there too —
currently Qwen2.5 1.5B Instruct, Gemma 2 2B IT and SmolLM2 360M, quantised.

## Wiring up an engine

Model management is done; the inference engine is a socket. Anyone binding
llama.cpp over FFI, MediaPipe LLM Inference or Core ML calls this once:

```dart
GgufLlmRuntime.attachBackend((prompt, maxTokens, temperature) async {
  return myEngine.complete(prompt, maxTokens: maxTokens, temp: temperature);
});
```

From then on `coachEngineProvider` yields a `LocalLlmCoach` as soon as a model
is present in the folder. With no backend everything stays on the rule-based
coach — the app is fully usable, it just talks with less variety.

## What is in the prompt

The goal sentence, day number, streak, hit rate, the habits with their runs,
the time of day, and for each friend their name, streak and whether they were
active today. As text, straight to the model on this device. No telemetry, no
intermediate storage, no network call.

The prompt is written in the language the user reads — asking a model for
German output while the prompt is English works measurably worse. That is why
`CoachPromptBuilder` is a port and the app supplies `LocalizedCoachPrompts`.
