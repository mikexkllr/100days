# AI on the device

## Why local rather than in the cloud

A coach that is useful has to know that you relapsed yesterday, what you weigh
and who around you already trained today. That is exactly the data that has no
business on someone else's server. So the AI has no network access — not as a
setting, but by construction: the model file is loaded from the app's own
folder and runs in a worker isolate through llama.cpp. There is no request
anywhere in that path.

## What it does

| Feature | With a model | Without one |
| --- | --- | --- |
| Daily coach line | Phrased by the model, in your language | Rule-based template |
| Nudges for friends | Written by the model | Templates |
| "Describe what you ate" | Estimates dishes the food table does not know | Food table and parser only |
| Nutrition targets | Proposes new targets from a wish ("fewer carbs") | Manual editor |

Every model path falls back silently. A model that is missing, slow, crashes
or returns something unparseable never surfaces as an error: the coach falls
back to its rules, the diary to the food table. Model output that is not
plausible — 5000 kcal for an apple, a target 40 % under maintenance — is
discarded rather than shown.

## Which model, on which phone

Onboarding detects the phone (model name and physical RAM through
`device_info_plus`) and proposes the strongest model that fits:

| Phone memory | Model | Download | Why |
| --- | --- | --- | --- |
| 3–5 GB | Qwen3.5 0.8B (Q4_K_M) | 0.53 GB | Runs on almost anything; short, simple sentences |
| 6–7 GB | Qwen3.5 2B (Q4_K_M) | 1.28 GB | The sweet spot for mid-range phones |
| 8 GB and up | Gemma 4 E2B (Q4_K_M) | 3.1 GB | Google's edge model: clearly better estimates and coaching |
| 12 GB and up, opt-in | Gemma 4 E4B (Q4_K_M) | 5.0 GB | Best quality on a phone; never proposed by default |

Unknown memory gets the smallest model; a 32-bit-only Android phone gets none
and stays on the rule-based coach.

Why these: in late 2026 Qwen3.5 and Gemma 4 are the strongest open models at
phone sizes, both are properly multilingual — which matters, because the app
speaks German as well as English and an English-only model writes poor German
— and both are Apache 2.0. Q4_K_M is the usual phone trade-off between size,
speed and quality. The thresholds leave room for the context cache and for
everything else the phone keeps in memory: a model that does not fit gets the
app killed in the background.

The table lives in `app/lib/data/llm_runtime.dart` (`kModelCatalog`).

## The download

Nothing downloads without a tap — in onboarding, or later under *Settings →
On-device AI*. Then:

- **Pinned.** Every model is a fixed Hugging Face revision plus the file's
  SHA-256. What lands on the phone is exactly the file that was reviewed, not
  whatever the repository holds that day.
- **Resumable.** Bytes go to `<file>.part`; an interrupted download continues
  with an HTTP range request.
- **Verified before use.** The SHA-256 is computed in an isolate and checked
  before the file gets its real name. A mismatch deletes it. A model file is
  input to a native library; a swapped one is not something to load.
- **Visible.** Size, progress and licence are shown; the download keeps
  running while you finish the setup.

The model folder is `<Application Support>/models/`; deleting the model frees
the space and the app falls back to the rule-based coach.

## The engine

[`llamadart`](https://pub.dev/packages/llamadart) (MIT, pinned to an exact
version) binds llama.cpp for Android and iOS. Its build hook fetches the
prebuilt native runtime for each target and checks it against a pinned digest;
the app bundles the llama.cpp runtime only. `LlamaCppRuntime` implements the
core's `LocalLlmRuntime` port:

- one model, one 2 k context, generations queued rather than run side by side;
- thinking mode off — a coach line does not need a visible chain of thought,
  and on a phone it would triple the wait;
- JSON-constrained output for meal estimates and target proposals where the
  runtime supports it, defensive parsing either way;
- a hard timeout that cancels the generation instead of letting it hold the
  queue.

The home screen never waits for the model: the rule-based line shows at once,
and the model's version replaces it when it arrives.

## What is in the prompt

The coach: the goal sentence (if you have one), day number, streak, hit rate,
the habits with their runs, the time of day, and for each friend their name,
streak and whether they were active today. The nutrition assistant: what you
typed, or your current targets and your wish. As text, straight to the model
on this device. No telemetry, no intermediate storage, no network call.

The prompt is written in the language the user reads — asking a model for
German output while the prompt is English works measurably worse. That is why
`CoachPromptBuilder` and `NutritionPromptBuilder` are ports and the app
supplies localized implementations.

## The two network requests

For completeness, since "local" is the claim: the only requests the AI and
nutrition features ever make are the model download above and, when you scan
or type a barcode, an Open Food Facts lookup that carries the barcode number
and nothing else.
