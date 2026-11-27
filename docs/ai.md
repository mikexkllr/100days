# AI

Every language model call goes through [dartantic_ai](https://pub.dev/packages/dartantic_ai),
in one of two ways:

- **The gateway** (default): the app's Google provider points at the
  `llm-gateway` edge function, which holds the provider key as a secret and
  counts every request against the user's monthly allowance.
- **The user's own key** (Settings → AI): Google, Anthropic or OpenAI,
  stored in the phone's keychain and checked with one request before it is
  saved. Requests then go straight from the phone to the provider; the
  allowance does not apply.

The app does not run models on the phone any more: the ones that fit a
phone were too slow and too unreliable for photos, plans and Funki.

Where a model supports it, answers that have to be JSON are asked for with
a JSON Schema (structured output): `LlmClient.generate(schema: …)` hands it
to dartantic, which passes it to Gemini as `responseJsonSchema` (and maps it
for OpenAI and Anthropic with one's own key). A schema fixes the shape, not
the sense — the checks below still run on every answer.

## What it does

| Feature | Purpose header | Free | Premium / own key |
| --- | --- | --- | --- |
| Meal from a photo | `food` | ✓ within the allowance | ✓ |
| Meal from a description ("what did you eat?" — calories optional), meal ideas, target proposals | `food` | ✓ within the allowance | ✓ |
| Plan the week, a recipe from a dish name (a planned meal in the meal sheet) | `plan` | ✓ within the allowance | ✓ |
| A training plan from what the user says they have and want (onboarding, plan editor) | `plan` | ✓ within the allowance | ✓ |
| Funki, the coach, to talk to (tools on everything) | `chat` | ✓ within the allowance | ✓ |
| The coach's daily line, nudge texts | `coach` | rule-based | ✓ |

Every answer is checked before it counts, and every check lives in
`hundred_core`, where it is tested:

- **Meals** (`NutritionAssistant`): dropped when the calories break physics
  (more than 9.5 kcal a gram) or the portion is absurd. Nothing reaches the
  diary until the user confirms it, and the entry is labelled as an
  estimate.
- **Plans** (`MealPlanner`, `parseMealPlan`): only meals inside the
  requested days and slots, with calories within 30 % of their macros, and
  ingredients in units a shopping list can add up. One meal per slot, and
  each dish once a week — a dish already planned on a slot the plan leaves
  alone is dropped. A drafted single recipe must land within 30 % of the
  calories asked for. Saving reuses the household's recipe of the same name
  (`recipeNamed`, `reconcileRecipe`) instead of storing a copy.
- **Training plans** (`TrainingAssistant`, `parseTrainingProposal`): a
  split the app knows, every one of its sessions, only exercises from the
  library that the equipment allows (one the model invents or cannot do
  there is left out; a plan made mostly of those is refused), sets and reps
  held to what a slot allows, effort and rest from the app's own
  prescription. A refused answer goes back once with why. The plan lands
  in the form with an undo; nothing is saved until the user saves.
- **Funki's tools** (`app/lib/ai/funki/funki_tools.dart`): `set_meal` goes
  through `parseMealPlan`, `log_food` through `foodEstimateFrom` (the same
  check as a meal estimate); a refused answer goes back to the model with
  why, so it can fix it. Every change — a diary entry, a check-in, a meal,
  a line on the list — is shown with an undo.

Every failure — no allowance, network, nonsense — falls back: the coach to
its rules, the diary to the food table, the planner to planning by hand.
When the allowance runs out, the app says so and offers premium or one's
own key.

## The gateway

[`supabase/functions/llm-gateway`](../supabase/functions/llm-gateway) is a
thin, authenticated pass-through to the Gemini REST API in its native
protocol, so tool calls, JSON mode and images work unchanged:

- **One model** on the allowlist, `gemini-3.5-flash-lite` — the cheapest
  current one, for everything. A different one is a change to `MODELS` in
  `gateway.ts` and `kAiModel` in the app, gateway first.
- **Parts**: text, tool calls and inline images (JPEG, PNG, WebP, at most
  2 MB each and four per request). No file references, no search grounding,
  no code execution.
- **Allowance**: `ai_usage` per user and month. Free 50k tokens (a photo
  costs about 1–2k, a week's plan 10–20k), premium 3M as fair use; both are
  secrets (`FREE_AI_TOKENS_PER_MONTH`, `PREMIUM_AI_TOKENS_PER_MONTH`), plus
  `AI_REQUESTS_PER_MINUTE`. An exhausted allowance answers 402, not 429, so
  client libraries do not retry it.

## Meal photos

The photo is turned upright, scaled to at most 1024 px and re-encoded as a
new JPEG on the phone — which is what drops EXIF, the GPS position and the
camera's serial before anything is sent. It is sent once and not stored;
what lands in the diary is only what the user confirms.

## What is sent

Only what a feature needs, when the user uses it:

- a meal photo or description;
- for a training plan: the goal sentence, training days, experience,
  equipment, the plan in the form, and what the user typed;
- for a plan: the days and meals, each member's name, and — if they share
  them — their calorie and protein targets, diet, dislikes and allergies,
  the wish typed, recently planned dish titles;
- for Funki, only what a tool he calls reads, when he calls it: today's
  habits and streak, the diary of a day with its targets, the week's plan,
  a recipe, the shopping list, today's workout and the last five logged,
  friends' display names with their streaks;
- for the coach (premium): streak, day number, habits and friends' first
  names.

Through the gateway it goes to Google's Gemini API under the terms of the
operator's API account — check them for your project before you run your
own instance, in particular whether requests may be used for training. The
backend keeps the month's token count, nothing else. With one's own key it
goes to that provider under the user's own terms.

## Prompts

Prompts are written in the language the user reads; asking a small model
for German output with an English prompt works measurably worse. That is
why `NutritionPromptBuilder`, `CoachPromptBuilder` and
`MealPlanPromptBuilder` are ports and the app supplies localized ones from
the ARB files. Funki's system prompt (`promptFunki`) is in the ARB files
too; his tool descriptions stay English, like the JSON they describe.

## Funki

Funki — the flame — is the coach. He is asked in **one place**: a sheet
that comes up over the screen the user is on (`showFunki`,
`app/lib/ui/funki/funki_sheet.dart`). The ways into it look the same
everywhere — Funki and a line of words (`FunkiAskButton`): under his line
of the day on Today, in the meal plan, and as his face in the top bar of the
diary and of the other tabs. He knows where he was called (`FunkiFocus`),
and a conversation closed and opened again goes on where it stopped
(`FunkiSession`, one conversation per place and day, until "new
conversation" or the end of the session).

Wherever he speaks he is the flame itself (`FunkiAvatar`: the user's own
Funki, at the stage of their streak): he writes his words out, hops while
he thinks and jumps when he has changed something.

**Entering food is not a conversation.** "What did you eat?" takes a
description and, optionally, calories (`composeFood`,
`app/lib/ui/nutrition/food_compose.dart`): the food table reads what it
knows — free and offline — and the rest goes to the model as one estimate
(`NutritionAssistant.estimateFoods`); calories the user gave are kept and
the foods scaled to them. That is the diary's first line, the "eaten" side
of the meal sheet, the describe tab and a manual entry without calories.
The "planned" side of the meal sheet makes a full recipe of a dish name
through `MealPlanner.draftMeal`. Asked in his sheet, Funki logs food
through `log_food` — told to enter what was said rather than discuss it.

**Building a training plan is not a conversation either.** Where the plan
is set up — the split step of onboarding and the plan editor — Funki has a
line of his own (`FunkiTrainingLine`): "dumbbells up to 20 kg, touchy
knees" becomes a split with its exercises, and the equipment level if what
was said changes it, straight into the form, with an undo.

**His notifications are rules, not model calls.** They are scheduled on the
phone for the days to come, so nothing can be asked at the moment they
fire: `funkiReminders` and `funkiLastCalls` (core, `coach/funki_push.dart`)
pick a sentence for each day from the streak's outlook — sentences that
take turns while a streak is alive, a milestone, a last call in the
evening, and after the flame has gone out three quieter ones, a goodbye,
and then silence. The wording is in the ARB files (`push…`).

He reads and changes through tools: `get_today`, `check_in`, `get_diary`,
`log_food`, `remove_food`, `eat_planned`, `get_meal_plan`, `get_recipe`,
`set_meal`, `remove_meal`, `get_shopping_list`, `add_to_list`,
`remove_from_list`, `make_list_from_plan`, `get_training`, `get_friends`.
He does not send anything to friends, change settings or targets, or log a
relapse. Diary entries he writes are labelled as AI estimates
(`FoodSource.ai`); unlike a photo estimate they need no extra
confirmation — the user asked for them — and each comes with an undo.
