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
| Plan the week; a recipe from a dish name (a planned meal in the meal sheet); a planned meal's recipe written or rewritten (recipe sheet, shopping list) — each at a cooking level | `plan` | ✓ within the allowance | ✓ |
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
  and cooking level (`recipeNamed`, `reconcileRecipe`) instead of storing a
  copy. A recipe is held to forty ingredients and twenty-four steps.
- **Kitchen basics**: a model may mark an ingredient as one (`staple`), and
  `isKitchenStaple` knows salt, pepper, oils, vinegars and a few spices by
  name — but only a little of something from a shelf can be a basic.
  Nothing fresh is one, and neither is half a kilo of flour, whatever the
  model says: a wrong mark would take the amount off the shopping list.
- **Funki's tools** (`app/lib/ai/funki/funki_tools.dart`): `set_meal` goes
  through `parseMealPlan`, `log_food` through `foodEstimateFrom` (the same
  check as a meal estimate), a training change against the exercise
  library and the user's equipment; a refused answer goes back to the
  model with why, so it can fix it. Every change — a diary entry, a
  check-in, a meal, a recipe, a line on the list, an exercise — is shown
  with an undo.

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
  costs about 1–2k, a week's plan 10–20k, a question to Funki 3–7k),
  premium 3M as fair use; both are
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
- for a plan or a recipe: the days and meals, each member's name, and — if
  they share them — their calorie and protein targets, diet, dislikes and
  allergies, the cooking level picked, the wish typed, recently planned
  dish titles; for a recipe written for a planned meal, its name and
  calories;
- for Funki, only what a tool he calls reads, when he calls it: today's
  habits and streak, the diary of a day with its targets, the week's plan,
  a recipe, the shopping list and what is always at home, the user's own
  tastes and cooking level, the training plan, today's workout and the
  last five logged, friends' display names with their streaks;
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

## Recipes, cooking levels and the shopping list

A week of meals is a week of recipes: each planned meal points at a
`Recipe` with every ingredient and steps to cook from, and the shopping
list is added up from those — deterministically, on the phone
(`buildShoppingList`). Three things keep that list honest:

- **The whole ingredient list.** The prompts ask for *every* ingredient the
  steps use — the fat for frying, salt, spices — and the example they show
  carries them (`kMealPlanJson`): a model that sees a recipe of two
  ingredients writes recipes of two ingredients.
- **Basics apart.** What a kitchen usually has is marked (`staple`) and
  listed once, without an amount, under its own heading
  (`ShopCategory.staples`): nobody buys three teaspoons of oil. What the
  household always has (its pantry) stays off the list altogether.
- **No silent gaps.** A meal typed in by hand or picked from the meal ideas
  is only a name; `mealsWithoutRecipe` finds those before a trip, the
  shopping tab names them, and their recipes are written from there.

The **cooking level** (`CookingLevel`: `convenience`, `everyday`,
`scratch`) says how much is made at home — the same salmon dinner is a
ready-to-cook fillet with beans from a can, or a side of wild salmon and
dried beans. It is picked wherever something is written — "plan the week",
a planned meal in the meal sheet, the recipe sheet, the shopping tab's
"write the recipes" — starts from each member's own default (kept among
their household preferences), and is stamped on the recipe. One name at two
levels is two recipes; a recipe written again from its sheet keeps its
name and its place in the plan (`Recipe.rewrittenAs`).

None of this needed a migration: the level is one of the recipe's tags, a
basic is a flag inside the ingredient JSON, the list's basics are a
category name, and a member's default lives in their preferences. A backend
from before stores them as they are, and an older app reads past them.

A week of more than eight meals is asked for in several calls
(`kMealsPerCall`): full recipes are some 600 tokens each, and an answer cut
off at the output limit is no plan at all. Each call is told what the ones
before it planned.

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

**His notifications are rules, not model calls.** They are scheduled on the
phone for the days to come, so nothing can be asked at the moment they
fire: `funkiReminders` and `funkiLastCalls` (core, `coach/funki_push.dart`)
pick a sentence for each day from the streak's outlook — sentences that
take turns while a streak is alive, a milestone, a last call in the
evening, and after the flame has gone out three quieter ones, a goodbye,
and then silence. The wording is in the ARB files (`push…`).

He reads and changes through tools:

| | Reads | Changes |
| --- | --- | --- |
| Today | `get_today`, `get_friends` | `check_in` |
| Diary | `get_diary` | `log_food`, `remove_food`, `eat_planned` |
| Meal plan | `get_meal_plan`, `get_recipe` | `plan_week`, `set_meal`, `write_recipe`, `move_meal`, `remove_meal`, `set_food_preferences` |
| Shopping list | `get_shopping_list` | `make_list_from_plan`, `add_to_list` (with amounts), `remove_from_list`, `tick_list_items`, `set_pantry` |
| Training | `get_training`, `get_training_plan`, `find_exercises` | `change_exercise`, `add_exercise`, `remove_exercise`, `set_training_days` |

`plan_week` and `write_recipe` ask the model themselves, through the
`MealPlanner` and its checks, at the cooking level named (`complexity`) or
the user's own: a week of full recipes passed through the conversation as
tool arguments would be paid for again with every later message, so the
conversation only ever holds the dishes' names. Training changes are saved
the way the editor saves them — a challenge update, so the days trained so
far stay as they were — and only take exercises the library has and the
user's equipment allows.

The tool declarations and the system prompt go out with every request to
the model — about 2.7k tokens together, 3.2k with a training plan, and a
question he answers with a tool is two requests. That is why the tools
that change a training plan are only declared to someone who has one, why
the cooking levels are explained once in the system prompt rather than in
each tool, and why a description says no more than the model needs.

He does not send anything to friends, change settings or calorie targets,
log a workout or log a relapse. Diary entries he writes are labelled as AI
estimates (`FoodSource.ai`); unlike a photo estimate they need no extra
confirmation — the user asked for them — and each comes with an undo.

His answers are Markdown, as a model writes it, and are drawn as such
(`app/lib/ui/funki/funki_markdown.dart`): paragraphs, headings, lists,
quotes, code, **bold**, *italic*. The parser is the app's own and small on
purpose — an answer is written out sign by sign, which a ready-made
Markdown widget does not do — and anything it does not know stays the text
it was. What the user types is shown as typed.
