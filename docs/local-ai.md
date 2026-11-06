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
`device_info_plus`), proposes the strongest model that fits — and lists every
**smaller** model that fits right underneath, one tap away: less storage,
less battery, quicker answers, simpler sentences. Settings also list the
larger ones and, marked, the ones that are too big.

| Model | Download | Quantisation | Offered from | Proposed for |
| --- | --- | --- | --- | --- |
| Qwen3.5 0.8B | 0.53 GB | Q4_K_M | 3 GB | 3–5 GB phones |
| Qwen3.5 2B | 1.28 GB | Q4_K_M | 6 GB | 6–7 GB phones |
| Gemma 4 E2B Mobile | 2.19 GB | QAT, 2-bit mix | 6 GB | never — the compact alternative |
| Gemma 4 E2B | 2.62 GB | QAT Q4 | 8 GB | 8–11 GB phones |
| Gemma 4 E4B Mobile | 3.22 GB | QAT, 2-bit mix | 12 GB | 12 GB and up |

Unknown memory gets the smallest model; a 32-bit-only Android phone gets none
and stays on the rule-based coach. Only one model stays on the phone: a new
one replaces the old one once its download has been verified.

**Checked in November 2026.** Qwen3.5 Small (March 2026) is still Qwen's
newest small line — Qwen3.6 and 3.8 only come in large sizes. Gemma 4 E2B and
E4B are still Google's on-device line; since June there are
quantisation-aware-trained (QAT) checkpoints, used here in Unsloth's GGUF
builds. They are smaller than a plain Q4_K_M and closer to the original:
by Unsloth's measurements the E2B QAT file picks the same next token as the
full-precision model 98.2 % of the time (a naive Q4_0: 89.3 %), and the E4B
mobile file 98.8 % at 3.2 GB instead of 5 GB. All five are multilingual —
which matters, because the app speaks German as well as English — and
Apache 2.0.

Not in the catalog, and why:

- **Liquid AI LFM3-1.7B** (October 2026): a new architecture (`lfm3`) the
  bundled llama.cpp does not know yet, and a licence of its own (LFM 1.0)
  rather than Apache 2.0. A candidate once the engine is updated.
- **IBM Granite 4.2 3B** (August 2026, Apache 2.0): the bundled engine
  knows its architecture, but at 2.2 GB it overlaps with Gemma 4 E2B and has
  not been run through the smoke test below.
- **Gemma 4 E4B QAT Q4** (4.2 GB): larger than the E4B mobile file and, by
  the same measurements, no better.

The thresholds leave room for the context cache and for everything else the
phone keeps in memory: a model that does not fit gets the app killed in the
background. The table lives in `app/lib/data/llm_runtime.dart`
(`kModelCatalog`).

## Trying the models for real

`app/test/llm_smoke_test.dart` downloads catalog models with the app's own
downloader (SHA-256 check included), loads them through llamadart and asks
for a German sentence, a coach line and a meal estimate. It is skipped
unless you name the models:

```bash
LLM_SMOKE_MODELS=qwen3.5-2b-q4,gemma-4-e2b-qat flutter test test/llm_smoke_test.dart
```

It runs on the host's CPU (Linux, macOS), not on a phone, so its timings are
an indication rather than a promise.

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
