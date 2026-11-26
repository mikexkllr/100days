/// Core of the 100 Days challenge app.
///
/// Nothing in this package touches Flutter, the network stack or the file
/// system: it is the part of the product that must be correct — the feed
/// fold, streak arithmetic, XP, plan generation, the checks on what a
/// language model answers — kept testable in isolation from the platform.
library hundred_core;

export 'src/ai/llm_client.dart';
export 'src/coach/coach.dart';
export 'src/coach/funki_push.dart';
export 'src/coach/heuristic_coach.dart';
export 'src/coach/llm_coach.dart';
export 'src/coach/prompts.dart';
export 'src/domain/challenge.dart';
export 'src/domain/check_in.dart';
export 'src/domain/flame.dart';
export 'src/domain/goal.dart';
export 'src/domain/habit.dart';
export 'src/domain/outlook.dart';
export 'src/domain/peer.dart';
export 'src/domain/progression.dart';
export 'src/domain/reward.dart';
export 'src/domain/schedule.dart';
export 'src/domain/streak.dart';
export 'src/domain/workout_log.dart';
export 'src/feed/event.dart';
export 'src/feed/feed_store.dart';
export 'src/feed/feed_writer.dart';
export 'src/mealplan/cadence.dart';
export 'src/mealplan/meal_plan.dart';
export 'src/mealplan/planner.dart';
export 'src/mealplan/recipe.dart';
export 'src/mealplan/shopping.dart';
export 'src/nutrition/food_entry.dart';
export 'src/nutrition/food_parser.dart';
export 'src/nutrition/foods.dart';
export 'src/nutrition/meal_ideas.dart';
export 'src/nutrition/nutrition_assistant.dart';
export 'src/plan/abstinence.dart';
export 'src/plan/exercises.dart';
export 'src/plan/nutrition.dart';
export 'src/plan/plan.dart';
export 'src/plan/training.dart';
export 'src/privacy/sharing.dart';
export 'src/social/activity.dart';
export 'src/social/friends.dart';
export 'src/social/projection.dart';
export 'src/util/codec.dart';
export 'src/util/dates.dart';
