import 'dart:ui';

import 'package:hundred_core/hundred_core.dart';

/// What each entry of the food table is called, in each language.
///
/// The first name is what the diary shows; the rest are what people type —
/// plurals, synonyms, brand words. The core table holds only ids and
/// numbers, so "Eier" and "eggs" both land on `egg`.
class FoodNames {
  const FoodNames({required this.en, required this.de});

  final List<String> en;
  final List<String> de;

  List<String> forLocale(Locale locale) =>
      locale.languageCode == 'de' ? de : en;
}

const Map<String, FoodNames> kFoodNames = <String, FoodNames>{
  'egg': FoodNames(
    en: <String>['Egg', 'eggs'],
    de: <String>['Ei', 'Eier'],
  ),
  'milk': FoodNames(
    en: <String>['Milk (1.5%)', 'milk', 'semi-skimmed milk'],
    de: <String>['Milch (1,5 %)', 'milch', 'fettarme milch'],
  ),
  'whole_milk': FoodNames(
    en: <String>['Whole milk', 'full fat milk'],
    de: <String>['Vollmilch'],
  ),
  'oat_milk': FoodNames(
    en: <String>['Oat milk', 'oat drink'],
    de: <String>['Haferdrink', 'hafermilch'],
  ),
  'soy_milk': FoodNames(
    en: <String>['Soy milk', 'soya milk'],
    de: <String>['Sojadrink', 'sojamilch'],
  ),
  'natural_yogurt': FoodNames(
    en: <String>['Natural yoghurt', 'yogurt', 'yoghurt', 'plain yogurt'],
    de: <String>['Naturjoghurt', 'joghurt'],
  ),
  'greek_yogurt': FoodNames(
    en: <String>['Greek yoghurt', 'greek yogurt'],
    de: <String>['Griechischer Joghurt', 'griechischer joghurt'],
  ),
  'skyr': FoodNames(
    en: <String>['Skyr'],
    de: <String>['Skyr'],
  ),
  'quark': FoodNames(
    en: <String>['Quark (low fat)', 'quark'],
    de: <String>['Magerquark', 'quark'],
  ),
  'cottage_cheese': FoodNames(
    en: <String>['Cottage cheese'],
    de: <String>['Hüttenkäse', 'körniger frischkäse'],
  ),
  'cheese': FoodNames(
    en: <String>['Cheese (gouda)', 'cheese', 'gouda'],
    de: <String>['Käse (Gouda)', 'käse', 'gouda'],
  ),
  'mozzarella': FoodNames(
    en: <String>['Mozzarella'],
    de: <String>['Mozzarella'],
  ),
  'feta': FoodNames(
    en: <String>['Feta'],
    de: <String>['Feta', 'schafskäse'],
  ),
  'butter': FoodNames(
    en: <String>['Butter'],
    de: <String>['Butter'],
  ),
  'chicken_breast': FoodNames(
    en: <String>['Chicken breast', 'chicken'],
    de: <String>['Hähnchenbrust', 'hähnchen', 'hühnchen', 'huhn', 'hähnchenbrustfilet'],
  ),
  'turkey_breast': FoodNames(
    en: <String>['Turkey breast', 'turkey'],
    de: <String>['Putenbrust', 'pute', 'putenfleisch'],
  ),
  'ground_beef': FoodNames(
    en: <String>['Ground beef', 'minced beef', 'mince'],
    de: <String>['Rinderhack', 'hackfleisch', 'hack'],
  ),
  'steak': FoodNames(
    en: <String>['Steak', 'beef steak'],
    de: <String>['Steak', 'rindersteak'],
  ),
  'ham': FoodNames(
    en: <String>['Ham', 'cooked ham'],
    de: <String>['Kochschinken', 'schinken'],
  ),
  'salami': FoodNames(
    en: <String>['Salami'],
    de: <String>['Salami'],
  ),
  'bacon': FoodNames(
    en: <String>['Bacon'],
    de: <String>['Bacon', 'speck'],
  ),
  'salmon': FoodNames(
    en: <String>['Salmon'],
    de: <String>['Lachs', 'lachsfilet'],
  ),
  'tuna': FoodNames(
    en: <String>['Tuna (canned)', 'tuna'],
    de: <String>['Thunfisch'],
  ),
  'shrimp': FoodNames(
    en: <String>['Shrimp', 'prawns'],
    de: <String>['Garnelen', 'shrimps'],
  ),
  'white_fish': FoodNames(
    en: <String>['White fish (cod)', 'cod', 'white fish'],
    de: <String>['Seelachs', 'kabeljau', 'fisch', 'fischfilet'],
  ),
  'schnitzel': FoodNames(
    en: <String>['Schnitzel'],
    de: <String>['Schnitzel'],
  ),
  'tofu': FoodNames(
    en: <String>['Tofu'],
    de: <String>['Tofu'],
  ),
  'tempeh': FoodNames(
    en: <String>['Tempeh'],
    de: <String>['Tempeh'],
  ),
  'lentils': FoodNames(
    en: <String>['Lentils (cooked)', 'lentils'],
    de: <String>['Linsen (gekocht)', 'linsen'],
  ),
  'chickpeas': FoodNames(
    en: <String>['Chickpeas (cooked)', 'chickpeas'],
    de: <String>['Kichererbsen (gekocht)', 'kichererbsen'],
  ),
  'kidney_beans': FoodNames(
    en: <String>['Kidney beans (cooked)', 'beans', 'kidney beans'],
    de: <String>['Kidneybohnen (gekocht)', 'bohnen', 'kidneybohnen'],
  ),
  'protein_powder': FoodNames(
    en: <String>['Protein powder', 'whey', 'protein shake'],
    de: <String>['Proteinpulver', 'whey', 'proteinshake', 'eiweißpulver'],
  ),
  'oats': FoodNames(
    en: <String>['Oats', 'oatmeal', 'rolled oats'],
    de: <String>['Haferflocken'],
  ),
  'muesli': FoodNames(
    en: <String>['Muesli'],
    de: <String>['Müsli'],
  ),
  'granola': FoodNames(
    en: <String>['Granola'],
    de: <String>['Granola', 'knuspermüsli'],
  ),
  'cornflakes': FoodNames(
    en: <String>['Cornflakes'],
    de: <String>['Cornflakes'],
  ),
  'rice': FoodNames(
    en: <String>['Rice (cooked)', 'rice'],
    de: <String>['Reis (gekocht)', 'reis'],
  ),
  'pasta': FoodNames(
    en: <String>['Pasta (cooked)', 'pasta', 'spaghetti', 'noodles'],
    de: <String>['Nudeln (gekocht)', 'nudeln', 'pasta', 'spaghetti'],
  ),
  'couscous': FoodNames(
    en: <String>['Couscous (cooked)', 'couscous'],
    de: <String>['Couscous (gekocht)', 'couscous'],
  ),
  'quinoa': FoodNames(
    en: <String>['Quinoa (cooked)', 'quinoa'],
    de: <String>['Quinoa (gekocht)', 'quinoa'],
  ),
  'potatoes': FoodNames(
    en: <String>['Potatoes (boiled)', 'potato', 'potatoes'],
    de: <String>['Kartoffeln (gekocht)', 'kartoffel', 'kartoffeln'],
  ),
  'sweet_potato': FoodNames(
    en: <String>['Sweet potato'],
    de: <String>['Süßkartoffel', 'süßkartoffeln'],
  ),
  'fries': FoodNames(
    en: <String>['Fries', 'chips', 'french fries'],
    de: <String>['Pommes', 'pommes frites'],
  ),
  'wholegrain_bread': FoodNames(
    en: <String>['Wholegrain bread', 'bread', 'brown bread'],
    de: <String>['Vollkornbrot', 'brot'],
  ),
  'toast': FoodNames(
    en: <String>['Toast', 'white bread'],
    de: <String>['Toast', 'toastbrot', 'weißbrot'],
  ),
  'bread_roll': FoodNames(
    en: <String>['Bread roll', 'roll'],
    de: <String>['Brötchen', 'semmel'],
  ),
  'crispbread': FoodNames(
    en: <String>['Crispbread'],
    de: <String>['Knäckebrot'],
  ),
  'tortilla': FoodNames(
    en: <String>['Tortilla wrap', 'wrap', 'tortilla'],
    de: <String>['Tortilla-Wrap', 'wrap', 'tortilla'],
  ),
  'rice_cakes': FoodNames(
    en: <String>['Rice cakes', 'rice cake'],
    de: <String>['Reiswaffeln', 'reiswaffel'],
  ),
  'croissant': FoodNames(
    en: <String>['Croissant'],
    de: <String>['Croissant'],
  ),
  'pancake': FoodNames(
    en: <String>['Pancake', 'pancakes'],
    de: <String>['Pfannkuchen', 'pancake', 'pancakes'],
  ),
  'broccoli': FoodNames(
    en: <String>['Broccoli'],
    de: <String>['Brokkoli'],
  ),
  'spinach': FoodNames(
    en: <String>['Spinach'],
    de: <String>['Spinat'],
  ),
  'tomato': FoodNames(
    en: <String>['Tomato', 'tomatoes'],
    de: <String>['Tomate', 'tomaten'],
  ),
  'cucumber': FoodNames(
    en: <String>['Cucumber'],
    de: <String>['Gurke', 'gurken'],
  ),
  'carrot': FoodNames(
    en: <String>['Carrot', 'carrots'],
    de: <String>['Karotte', 'karotten', 'möhre', 'möhren'],
  ),
  'bell_pepper': FoodNames(
    en: <String>['Bell pepper', 'pepper', 'peppers'],
    de: <String>['Paprika'],
  ),
  'lettuce': FoodNames(
    en: <String>['Lettuce', 'salad leaves', 'salad'],
    de: <String>['Blattsalat', 'salat'],
  ),
  'onion': FoodNames(
    en: <String>['Onion', 'onions'],
    de: <String>['Zwiebel', 'zwiebeln'],
  ),
  'mushrooms': FoodNames(
    en: <String>['Mushrooms', 'mushroom'],
    de: <String>['Champignons', 'pilze'],
  ),
  'zucchini': FoodNames(
    en: <String>['Courgette', 'zucchini'],
    de: <String>['Zucchini'],
  ),
  'green_beans': FoodNames(
    en: <String>['Green beans'],
    de: <String>['Grüne Bohnen', 'grüne bohnen'],
  ),
  'sweetcorn': FoodNames(
    en: <String>['Sweetcorn', 'corn'],
    de: <String>['Mais'],
  ),
  'vegetables': FoodNames(
    en: <String>['Mixed vegetables', 'vegetables', 'veggies'],
    de: <String>['Gemüse (gemischt)', 'gemüse'],
  ),
  'avocado': FoodNames(
    en: <String>['Avocado'],
    de: <String>['Avocado'],
  ),
  'banana': FoodNames(
    en: <String>['Banana', 'bananas'],
    de: <String>['Banane', 'bananen'],
  ),
  'apple': FoodNames(
    en: <String>['Apple', 'apples'],
    de: <String>['Apfel', 'äpfel'],
  ),
  'orange': FoodNames(
    en: <String>['Orange', 'oranges'],
    de: <String>['Orange', 'orangen'],
  ),
  'pear': FoodNames(
    en: <String>['Pear', 'pears'],
    de: <String>['Birne', 'birnen'],
  ),
  'kiwi': FoodNames(
    en: <String>['Kiwi', 'kiwis'],
    de: <String>['Kiwi', 'kiwis'],
  ),
  'berries': FoodNames(
    en: <String>['Berries', 'mixed berries', 'blueberries'],
    de: <String>['Beeren', 'heidelbeeren', 'blaubeeren'],
  ),
  'strawberries': FoodNames(
    en: <String>['Strawberries', 'strawberry'],
    de: <String>['Erdbeeren', 'erdbeere'],
  ),
  'grapes': FoodNames(
    en: <String>['Grapes'],
    de: <String>['Weintrauben', 'trauben'],
  ),
  'mango': FoodNames(
    en: <String>['Mango'],
    de: <String>['Mango'],
  ),
  'dates': FoodNames(
    en: <String>['Dates (dried)', 'dates'],
    de: <String>['Datteln'],
  ),
  'raisins': FoodNames(
    en: <String>['Raisins'],
    de: <String>['Rosinen'],
  ),
  'almonds': FoodNames(
    en: <String>['Almonds'],
    de: <String>['Mandeln'],
  ),
  'walnuts': FoodNames(
    en: <String>['Walnuts'],
    de: <String>['Walnüsse'],
  ),
  'peanuts': FoodNames(
    en: <String>['Peanuts'],
    de: <String>['Erdnüsse'],
  ),
  'cashews': FoodNames(
    en: <String>['Cashews'],
    de: <String>['Cashewkerne', 'cashews'],
  ),
  'peanut_butter': FoodNames(
    en: <String>['Peanut butter'],
    de: <String>['Erdnussbutter', 'erdnussmus'],
  ),
  'chia_seeds': FoodNames(
    en: <String>['Chia seeds'],
    de: <String>['Chiasamen'],
  ),
  'olive_oil': FoodNames(
    en: <String>['Olive oil', 'oil'],
    de: <String>['Olivenöl', 'öl'],
  ),
  'hummus': FoodNames(
    en: <String>['Hummus'],
    de: <String>['Hummus'],
  ),
  'hazelnut_spread': FoodNames(
    en: <String>['Hazelnut spread', 'nutella'],
    de: <String>['Nuss-Nougat-Creme', 'nutella'],
  ),
  'honey': FoodNames(
    en: <String>['Honey'],
    de: <String>['Honig'],
  ),
  'jam': FoodNames(
    en: <String>['Jam'],
    de: <String>['Marmelade', 'konfitüre'],
  ),
  'sugar': FoodNames(
    en: <String>['Sugar'],
    de: <String>['Zucker'],
  ),
  'dark_chocolate': FoodNames(
    en: <String>['Dark chocolate'],
    de: <String>['Zartbitterschokolade', 'dunkle schokolade'],
  ),
  'milk_chocolate': FoodNames(
    en: <String>['Milk chocolate', 'chocolate'],
    de: <String>['Vollmilchschokolade', 'schokolade'],
  ),
  'gummy_bears': FoodNames(
    en: <String>['Gummy bears', 'sweets'],
    de: <String>['Gummibärchen', 'fruchtgummi'],
  ),
  'crisps': FoodNames(
    en: <String>['Crisps', 'potato chips'],
    de: <String>['Chips', 'kartoffelchips'],
  ),
  'ice_cream': FoodNames(
    en: <String>['Ice cream'],
    de: <String>['Eis', 'speiseeis'],
  ),
  'cookie': FoodNames(
    en: <String>['Cookie', 'biscuit', 'cookies', 'biscuits'],
    de: <String>['Keks', 'kekse', 'cookie'],
  ),
  'cake': FoodNames(
    en: <String>['Cake', 'slice of cake'],
    de: <String>['Kuchen', 'stück kuchen'],
  ),
  'protein_bar': FoodNames(
    en: <String>['Protein bar'],
    de: <String>['Proteinriegel'],
  ),
  'cereal_bar': FoodNames(
    en: <String>['Cereal bar', 'granola bar'],
    de: <String>['Müsliriegel'],
  ),
  'coffee': FoodNames(
    en: <String>['Coffee (black)', 'coffee', 'espresso'],
    de: <String>['Kaffee (schwarz)', 'kaffee', 'espresso'],
  ),
  'cappuccino': FoodNames(
    en: <String>['Cappuccino', 'latte', 'flat white'],
    de: <String>['Cappuccino', 'latte macchiato', 'milchkaffee'],
  ),
  'tea': FoodNames(
    en: <String>['Tea'],
    de: <String>['Tee'],
  ),
  'orange_juice': FoodNames(
    en: <String>['Orange juice', 'juice'],
    de: <String>['Orangensaft', 'saft', 'o-saft'],
  ),
  'smoothie': FoodNames(
    en: <String>['Smoothie'],
    de: <String>['Smoothie'],
  ),
  'cola': FoodNames(
    en: <String>['Cola', 'coke', 'soda'],
    de: <String>['Cola', 'limo', 'limonade'],
  ),
  'cola_zero': FoodNames(
    en: <String>['Cola Zero', 'diet coke', 'zero'],
    de: <String>['Cola Zero', 'cola light'],
  ),
  'beer': FoodNames(
    en: <String>['Beer'],
    de: <String>['Bier'],
  ),
  'wine': FoodNames(
    en: <String>['Wine', 'red wine', 'white wine'],
    de: <String>['Wein', 'rotwein', 'weißwein'],
  ),
  'pizza': FoodNames(
    en: <String>['Pizza'],
    de: <String>['Pizza'],
  ),
  'burger': FoodNames(
    en: <String>['Burger', 'hamburger', 'cheeseburger'],
    de: <String>['Burger', 'hamburger', 'cheeseburger'],
  ),
  'doner_kebab': FoodNames(
    en: <String>['Doner kebab', 'kebab', 'doner'],
    de: <String>['Döner', 'döner kebab', 'dürüm'],
  ),
  'spaghetti_bolognese': FoodNames(
    en: <String>['Spaghetti bolognese', 'bolognese'],
    de: <String>['Spaghetti Bolognese', 'bolognese'],
  ),
  'lasagna': FoodNames(
    en: <String>['Lasagne', 'lasagna'],
    de: <String>['Lasagne'],
  ),
  'currywurst': FoodNames(
    en: <String>['Currywurst', 'sausage'],
    de: <String>['Currywurst', 'bratwurst', 'wurst'],
  ),
  'sushi': FoodNames(
    en: <String>['Sushi'],
    de: <String>['Sushi'],
  ),
  'curry': FoodNames(
    en: <String>['Curry', 'chicken curry'],
    de: <String>['Curry', 'hähnchencurry'],
  ),
  'chili_con_carne': FoodNames(
    en: <String>['Chili con carne', 'chili'],
    de: <String>['Chili con Carne', 'chili'],
  ),
  'fried_rice': FoodNames(
    en: <String>['Fried rice'],
    de: <String>['Gebratener Reis'],
  ),
  'instant_noodles': FoodNames(
    en: <String>['Instant noodles', 'ramen'],
    de: <String>['Instantnudeln', 'ramen'],
  ),
  'vegetable_soup': FoodNames(
    en: <String>['Vegetable soup', 'soup'],
    de: <String>['Gemüsesuppe', 'suppe'],
  ),
  'mixed_salad': FoodNames(
    en: <String>['Mixed salad with dressing', 'salad with dressing'],
    de: <String>['Gemischter Salat mit Dressing', 'salat mit dressing'],
  ),
  'omelette': FoodNames(
    en: <String>['Omelette', 'omelet'],
    de: <String>['Omelett'],
  ),
  'scrambled_eggs': FoodNames(
    en: <String>['Scrambled eggs'],
    de: <String>['Rührei'],
  ),
  'porridge': FoodNames(
    en: <String>['Porridge'],
    de: <String>['Porridge', 'haferbrei'],
  ),
  'sandwich': FoodNames(
    en: <String>['Sandwich'],
    de: <String>['Sandwich', 'belegtes brot'],
  ),
  'falafel': FoodNames(
    en: <String>['Falafel'],
    de: <String>['Falafel'],
  ),
  'burrito': FoodNames(
    en: <String>['Burrito'],
    de: <String>['Burrito'],
  ),
};

/// The display name of a food in [locale].
String foodName(String foodId, Locale locale) =>
    kFoodNames[foodId]?.forLocale(locale).first ?? foodId;

/// Numbers, units and glue words for the free-text parser.
FoodVocabulary foodVocabularyFor(Locale locale) =>
    locale.languageCode == 'de' ? _german : _english;

const FoodVocabulary _german = FoodVocabulary(
  numberWords: <String, double>{
    'ein': 1,
    'eine': 1,
    'einen': 1,
    'einem': 1,
    'einer': 1,
    'eins': 1,
    'zwei': 2,
    'drei': 3,
    'vier': 4,
    'fünf': 5,
    'sechs': 6,
    'halb': 0.5,
    'halbe': 0.5,
    'halben': 0.5,
    'halbes': 0.5,
    'paar': 2,
  },
  unitWords: <String, FoodUnit>{
    'g': FoodUnit.grams,
    'gr': FoodUnit.grams,
    'gramm': FoodUnit.grams,
    'kg': FoodUnit.kilograms,
    'ml': FoodUnit.millilitres,
    'l': FoodUnit.litres,
    'liter': FoodUnit.litres,
    'stück': FoodUnit.piece,
    'stk': FoodUnit.piece,
    'scheibe': FoodUnit.slice,
    'scheiben': FoodUnit.slice,
    'portion': FoodUnit.portion,
    'portionen': FoodUnit.portion,
    'teller': FoodUnit.portion,
    'schüssel': FoodUnit.portion,
    'el': FoodUnit.tablespoon,
    'esslöffel': FoodUnit.tablespoon,
    'tl': FoodUnit.teaspoon,
    'teelöffel': FoodUnit.teaspoon,
    'tasse': FoodUnit.cup,
    'tassen': FoodUnit.cup,
    'becher': FoodUnit.cup,
    'glas': FoodUnit.glass,
    'gläser': FoodUnit.glass,
    'handvoll': FoodUnit.handful,
  },
  separators: <String>['und', 'mit', 'dazu', 'sowie'],
  fillerWords: <String>{
    'ich',
    'hatte',
    'habe',
    'hab',
    'gegessen',
    'getrunken',
    'zum',
    'frühstück',
    'mittag',
    'abend',
    'etwas',
    'bisschen',
    'x',
    'ca',
    'ca.',
    'etwa',
    'von',
  },
);

const FoodVocabulary _english = FoodVocabulary(
  numberWords: <String, double>{
    'a': 1,
    'an': 1,
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'half': 0.5,
    'couple': 2,
  },
  unitWords: <String, FoodUnit>{
    'g': FoodUnit.grams,
    'gram': FoodUnit.grams,
    'grams': FoodUnit.grams,
    'kg': FoodUnit.kilograms,
    'ml': FoodUnit.millilitres,
    'l': FoodUnit.litres,
    'litre': FoodUnit.litres,
    'liter': FoodUnit.litres,
    'piece': FoodUnit.piece,
    'pieces': FoodUnit.piece,
    'slice': FoodUnit.slice,
    'slices': FoodUnit.slice,
    'portion': FoodUnit.portion,
    'portions': FoodUnit.portion,
    'serving': FoodUnit.portion,
    'servings': FoodUnit.portion,
    'bowl': FoodUnit.portion,
    'plate': FoodUnit.portion,
    'tbsp': FoodUnit.tablespoon,
    'tablespoon': FoodUnit.tablespoon,
    'tablespoons': FoodUnit.tablespoon,
    'tsp': FoodUnit.teaspoon,
    'teaspoon': FoodUnit.teaspoon,
    'teaspoons': FoodUnit.teaspoon,
    'cup': FoodUnit.cup,
    'cups': FoodUnit.cup,
    'mug': FoodUnit.cup,
    'glass': FoodUnit.glass,
    'glasses': FoodUnit.glass,
    'handful': FoodUnit.handful,
  },
  separators: <String>['and', 'with', 'plus'],
  fillerWords: <String>{
    'i',
    'had',
    'ate',
    'drank',
    'for',
    'breakfast',
    'lunch',
    'dinner',
    'some',
    'of',
    'x',
    'about',
    'approx',
  },
);

/// Finds foods by name in one language, with the other as a fallback —
/// "Pizza" is Pizza in both, and people mix.
class FoodIndex {
  FoodIndex(Locale locale) {
    final other = locale.languageCode == 'de' ? const Locale('en') : const Locale('de');
    for (final Locale l in <Locale>[locale, other]) {
      kFoodNames.forEach((String id, FoodNames names) {
        for (final String name in names.forLocale(l)) {
          _byName.putIfAbsent(_normalise(name), () => id);
        }
      });
    }
    _names = _byName.keys.toList()
      ..sort((String a, String b) => b.length.compareTo(a.length));
  }

  final Map<String, String> _byName = <String, String>{};
  late final List<String> _names;

  static String _normalise(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'\(.*?\)'), '')
      .replaceAll(RegExp(r'[^a-zäöüß0-9 -]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Best table entry for the food words of one item, or null.
  FoodItem? lookup(String phrase) {
    final wanted = _normalise(phrase);
    if (wanted.isEmpty) return null;
    final exact = _byName[wanted];
    if (exact != null) return kFoodById[exact];
    // The longest known name inside the phrase: "griechischer joghurt mit
    // honig" is Greek yoghurt, not plain yoghurt.
    final padded = ' $wanted ';
    for (final String name in _names) {
      if (padded.contains(' $name ')) return kFoodById[_byName[name]!];
    }
    // A word that starts a known name: "hähnchenbrustfilet", "bananen".
    for (final String word in wanted.split(' ')) {
      if (word.length < 4) continue;
      for (final String name in _names) {
        if (name.startsWith(word) ||
            (word.startsWith(name) && name.length >= 4)) {
          return kFoodById[_byName[name]!];
        }
      }
    }
    return null;
  }

  /// Foods whose name matches [query], best first.
  List<FoodItem> search(String query, {int limit = 30}) {
    final wanted = _normalise(query);
    if (wanted.isEmpty) return const <FoodItem>[];
    final starts = <String>[];
    final contains = <String>[];
    _byName.forEach((String name, String id) {
      if (name.startsWith(wanted) ||
          name.split(' ').any((String w) => w.startsWith(wanted))) {
        if (!starts.contains(id)) starts.add(id);
      } else if (name.contains(wanted)) {
        if (!contains.contains(id)) contains.add(id);
      }
    });
    return <String>{...starts, ...contains}
        .take(limit)
        .map((String id) => kFoodById[id]!)
        .toList();
  }
}
