import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models/food_item.dart';

class FoodRepository {
  static final FoodRepository instance = FoodRepository._();
  FoodRepository._();

  List<FoodItem>? _localFoods;
  List<FoodItem>? _beverages;
  List<FoodItem>? _fastFoodAll;
  String? _currentRegion;

  static const List<Map<String, String>> supportedRegions = [
    {'code': 'US', 'name': '\u{1F1FA}\u{1F1F8} United States'},
    {'code': 'GB', 'name': '\u{1F1EC}\u{1F1E7} United Kingdom'},
    {'code': 'CA', 'name': '\u{1F1E8}\u{1F1E6} Canada'},
    {'code': 'AU', 'name': '\u{1F1E6}\u{1F1FA} Australia'},
    {'code': 'DE', 'name': '\u{1F1E9}\u{1F1EA} Germany'},
    {'code': 'FR', 'name': '\u{1F1EB}\u{1F1F7} France'},
    {'code': 'ES', 'name': '\u{1F1EA}\u{1F1F8} Spain'},
    {'code': 'IT', 'name': '\u{1F1EE}\u{1F1F9} Italy'},
    {'code': 'BR', 'name': '\u{1F1E7}\u{1F1F7} Brazil'},
    {'code': 'MX', 'name': '\u{1F1F2}\u{1F1FD} Mexico'},
    {'code': 'IN', 'name': '\u{1F1EE}\u{1F1F3} India'},
    {'code': 'NL', 'name': '\u{1F1F3}\u{1F1F1} Netherlands'},
    {'code': 'SE', 'name': '\u{1F1F8}\u{1F1EA} Sweden'},
    {'code': 'AE', 'name': '\u{1F1E6}\u{1F1EA} UAE'},
    {'code': 'SA', 'name': '\u{1F1F8}\u{1F1E6} Saudi Arabia'},
    {'code': 'ZA', 'name': '\u{1F1FF}\u{1F1E6} South Africa'},
    {'code': 'JP', 'name': '\u{1F1EF}\u{1F1F5} Japan'},
    {'code': 'KR', 'name': '\u{1F1F0}\u{1F1F7} South Korea'},
    {'code': 'GENERIC', 'name': '\u{1F30D} International (generic)'},
  ];

  void _log(String message) {
    if (!kDebugMode) return;
    debugPrint(message);
  }

  Future<String> _detectDeviceRegion() async {
    final locale = ui.PlatformDispatcher.instance.locale;
    final detected = locale.countryCode ?? 'GENERIC';
    _log('\u1f30d DETECTED REGION: $detected (Locale: ${locale.toString()})');
    return detected;
  }

  Future<String> getCurrentRegion() async {
    if (_currentRegion != null) {
      _log('\u1f4cd Using cached region: $_currentRegion');
      return _currentRegion!;
    }
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('user_region');
    if (stored != null) {
      _currentRegion = stored;
      _log('\u1f4be Loaded stored region: $stored');
      return stored;
    }
    final detected = await _detectDeviceRegion();
    await setRegion(detected);
    return _currentRegion!;
  }

  Future<void> setRegion(String countryCode) async {
    _currentRegion = countryCode.toUpperCase();
    _localFoods = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_region', _currentRegion!);
    _log('\u2705 Region saved: $_currentRegion');
  }

  Future<bool> hasRegionDatabase(String countryCode) async {
    try {
      await rootBundle.loadString(
        'assets/data/foods_${countryCode.toLowerCase()}.json',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<FoodItem>> loadLocalFoods() async {
    if (_localFoods != null) {
      _log('\u1f4e6 Using cached foods (${_localFoods!.length} items)');
      return _localFoods!;
    }
    final region = await getCurrentRegion();
    final regionFile = 'assets/data/foods_${region.toLowerCase()}.json';

    final upperRegion = region.toUpperCase();
    final filesByPriority = <String>[];
    switch (upperRegion) {
      case 'AU':
        filesByPriority.addAll([
          'assets/data/app_database_seed.json',
          regionFile,
        ]);
        break;
      case 'US':
        filesByPriority.addAll([
          'assets/data/usda_database_seed.json',
          regionFile,
        ]);
        break;
      case 'GB':
        filesByPriority.addAll([
          'assets/data/uk_database_seed.json',
          regionFile,
          'assets/data/usda_database_seed.json',
        ]);
        break;
      default:
        filesByPriority.addAll([
          regionFile,
          'assets/data/usda_database_seed.json',
        ]);
        break;
    }

    final merged = <String, FoodItem>{};
    for (final file in filesByPriority) {
      final loaded = await _loadFoodItemsFromFile(file);
      for (final item in loaded) {
        final key = _prepareForSearch(item.name);
        if (key.isEmpty) continue;
        merged.putIfAbsent(key, () => item);
      }
    }

    if (merged.isNotEmpty) {
      _localFoods = merged.values.toList();
      _log(
        '\u2705 SUCCESS: Loaded $upperRegion merged local database from ${filesByPriority.length} source files (${_localFoods!.length} unique items)',
      );
      return _localFoods!;
    }

    _log('\u1f504 Falling back to generic foods...');
    try {
      final raw = await rootBundle.loadString(
        'assets/data/foods_generic.json',
      );
      final data = jsonDecode(raw) as List<dynamic>;
      _localFoods = data
          .map(
            (e) => _withCategory(
              FoodItem.fromJson(e as Map<String, dynamic>),
              null,
            ),
          )
          .toList();
      _log(
        '\u2705 SUCCESS: Loaded ${_localFoods!.length} foods from foods_generic.json',
      );
      return _localFoods!;
    } catch (_) {
      _log(
        '\u26a0\ufe0f  foods_generic.json not found, trying legacy generic_foods.json...',
      );
      final raw = await rootBundle.loadString(
        'assets/data/generic_foods.json',
      );
      final data = jsonDecode(raw) as List<dynamic>;
      _localFoods = data
          .map(
            (e) => _withCategory(
              FoodItem.fromJson(e as Map<String, dynamic>),
              null,
            ),
          )
          .toList();
      _log(
        '\u2705 SUCCESS: Loaded ${_localFoods!.length} foods from legacy generic_foods.json',
      );
      return _localFoods!;
    }
  }

  Future<List<FoodItem>> _loadFoodItemsFromFile(String file) async {
    _log('\u1f50d Attempting to load: $file');
    try {
      final raw = await rootBundle.loadString(file);
      final data = jsonDecode(raw) as List<dynamic>;
      return data
          .map(
            (e) => _withCategory(
              FoodItem.fromJson(e as Map<String, dynamic>),
              null,
            ),
          )
          .toList();
    } catch (e) {
      _log('\u26a0\ufe0f  Could not load $file: $e');
      return [];
    }
  }

  Future<List<FoodItem>> searchLocalFoods(String query) async {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return [];
    final preparedQuery = _prepareForSearch(query);
    final queryTokens = preparedQuery
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toList();

    final results = await Future.wait([
      loadLocalFoods(),
      loadBeverages(),
      loadFastFood(),
    ]);

    final allFoods = [...results[0], ...results[1], ...results[2]];
    final rankedResults = allFoods
        .map((food) => (
              food: food,
              score: _searchScore(food, preparedQuery, queryTokens),
            ))
        .where((item) => item.score > 0)
        .toList()
      ..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) return byScore;
        return a.food.name.compareTo(b.food.name);
      });

    final seen = <String>{};
    final searchResults = <FoodItem>[];
    for (final item in rankedResults) {
      final dedupeKey = _prepareForSearch(item.food.name);
      if (!seen.add(dedupeKey)) continue;
      searchResults.add(item.food);
    }

    _log(
      '\u1f50d Search "$query": ${searchResults.length} results from ${allFoods.length} total foods',
    );
    return searchResults;
  }

  String _prepareForSearch(String value) {
    final cleaned = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleaned.isEmpty) return cleaned;
    final normalizedTokens = cleaned
        .split(' ')
        .where((token) => token.isNotEmpty)
        .map(_normalizeSearchToken)
        .toList();
    return normalizedTokens.join(' ');
  }

  String _normalizeSearchToken(String token) {
    if (token.length <= 3) return token;
    if (token.endsWith('ies') && token.length > 4) {
      return '${token.substring(0, token.length - 3)}y';
    }
    if (token.endsWith('s') &&
        !token.endsWith('ss') &&
        !token.endsWith('us') &&
        !token.endsWith('is')) {
      return token.substring(0, token.length - 1);
    }
    return token;
  }

  int _searchScore(FoodItem food, String preparedQuery, List<String> queryTokens) {
    if (preparedQuery.isEmpty || queryTokens.isEmpty) return 0;

    final preparedName = _prepareForSearch(food.name);
    final preparedAliases = food.searchAliases
        .map(_prepareForSearch)
        .where((alias) => alias.isNotEmpty)
        .toList();

    bool allTokensIn(String target) => queryTokens.every(target.contains);

    bool tokensInOrder(String target) {
      var index = 0;
      for (final token in queryTokens) {
        final foundAt = target.indexOf(token, index);
        if (foundAt < 0) return false;
        index = foundAt + token.length;
      }
      return true;
    }

    var score = 0;

    if (preparedName == preparedQuery) {
      score = 140;
    } else if (preparedName.startsWith(preparedQuery)) {
      score = 120;
    } else if (preparedName.contains(preparedQuery)) {
      score = 100;
    } else if (tokensInOrder(preparedName)) {
      score = 88;
    } else if (queryTokens.length == 1 && allTokensIn(preparedName)) {
      score = 80;
    } else if (queryTokens.length > 1 && allTokensIn(preparedName)) {
      // Keep as low-confidence fallback only.
      score = 25;
    }

    for (final alias in preparedAliases) {
      if (alias == preparedQuery) {
        score = score < 135 ? 135 : score;
      } else if (alias.startsWith(preparedQuery)) {
        score = score < 115 ? 115 : score;
      } else if (alias.contains(preparedQuery)) {
        score = score < 90 ? 90 : score;
      } else if (tokensInOrder(alias)) {
        score = score < 84 ? 84 : score;
      } else if (queryTokens.length == 1 && allTokensIn(alias)) {
        score = score < 75 ? 75 : score;
      }
    }

    final isFastFood = food.category?.contains('Fast Food') ?? false;
    if (isFastFood) {
      score -= 8;
    }

    if (queryTokens.length > 1 && _isGenericFoodName(preparedName)) {
      score -= 20;
    }

    return score;
  }

  bool _isGenericFoodName(String preparedName) {
    const genericNames = {
      'fish',
      'meat',
      'poultry',
      'bread',
      'rice',
      'pasta',
      'oil',
      'salad',
      'milk',
      'yogurt',
      'yoghurt',
      'cheese',
      'potato',
      'chicken',
      'beef',
      'snacks',
      'fruit',
      'vegetable',
    };
    return genericNames.contains(preparedName);
  }

  String _detectCategory(String foodName, String? sourceDatabase) {
    final name = foodName.toLowerCase();
    if (sourceDatabase == 'mcdonalds' ||
        sourceDatabase == 'kfc' ||
        sourceDatabase == 'subway' ||
        sourceDatabase == 'starbucks' ||
        name.contains('burger') ||
        name.contains('pizza')) {
      return '\u{1F354} Fast Food';
    }
    if (sourceDatabase == 'beverages' ||
        name.contains('coffee') ||
        name.contains('latte') ||
        name.contains('flat white') ||
        name.contains('cappuccino') ||
        name.contains('juice') ||
        name.contains('milk shake') ||
        name.contains('smoothie')) {
      return '\u{2615} Beverages';
    }
    if (name.contains('chicken') ||
        name.contains('beef') ||
        name.contains('pork') ||
        name.contains('fish') ||
        name.contains('salmon') ||
        name.contains('tuna') ||
        name.contains('egg') ||
        name.contains('protein') ||
        name.contains('whey') ||
        name.contains('turkey')) {
      return '\u{1F969} Protein';
    }
    if (name.contains('milk') ||
        name.contains('yogurt') ||
        name.contains('cheese') ||
        name.contains('cream')) {
      return '\u{1F95B} Dairy';
    }
    if (name.contains('rice') ||
        name.contains('bread') ||
        name.contains('pasta') ||
        name.contains('oats') ||
        name.contains('cereal') ||
        name.contains('bagel')) {
      return '\u{1F35E} Grains';
    }
    if (name.contains('broccoli') ||
        name.contains('carrot') ||
        name.contains('spinach') ||
        name.contains('lettuce') ||
        name.contains('tomato') ||
        name.contains('pepper')) {
      return '\u{1F96C} Vegetables';
    }
    if (name.contains('apple') ||
        name.contains('banana') ||
        name.contains('orange') ||
        name.contains('berry') ||
        name.contains('grape') ||
        name.contains('mango')) {
      return '\u{1F34E} Fruits';
    }
    if (name.contains('almond') ||
        name.contains('walnut') ||
        name.contains('peanut') ||
        name.contains('cashew') ||
        name.contains('seed')) {
      return '\u{1F95C} Nuts & Seeds';
    }
    return '\u{1F37D}\u{FE0F} Other';
  }

  FoodItem _withCategory(FoodItem item, String? source) {
    if (item.category != null) return item;
    return FoodItem(
      name: item.name,
      caloriesPer100g: item.caloriesPer100g,
      proteinPer100g: item.proteinPer100g,
      carbsPer100g: item.carbsPer100g,
      fatPer100g: item.fatPer100g,
      servingSize: item.servingSize,
      servingProtein: item.servingProtein,
      servingCarbs: item.servingCarbs,
      servingFat: item.servingFat,
      category: _detectCategory(item.name, source),
      searchAliases: item.searchAliases,
    );
  }

  Future<List<FoodItem>> loadBeverages() async {
    if (_beverages != null) return _beverages!;
    try {
      final raw = await rootBundle.loadString(
        'assets/data/foods_beverages.json',
      );
      final data = jsonDecode(raw) as List<dynamic>;
      _beverages = data
          .map(
            (e) => _withCategory(
              FoodItem.fromJson(e as Map<String, dynamic>),
              'beverages',
            ),
          )
          .toList();
      _log('\u2705 Loaded ${_beverages!.length} beverages');
      return _beverages!;
    } catch (e) {
      _log('\u26a0\ufe0f  Could not load beverages: $e');
      _beverages = [];
      return [];
    }
  }

  Future<List<FoodItem>> loadFastFood() async {
    if (_fastFoodAll != null) return _fastFoodAll!;
    _fastFoodAll = [];
    const chains = ['mcdonalds', 'kfc', 'subway', 'starbucks'];
    for (final chain in chains) {
      try {
        final raw = await rootBundle.loadString(
          'assets/data/foods_$chain.json',
        );
        final data = jsonDecode(raw) as List<dynamic>;
        final items = data.map((e) {
          final item = FoodItem.fromJson(e as Map<String, dynamic>);
          final branded = !item.name.contains('(')
              ? FoodItem(
                  name: '${item.name} (${_capitalizeChain(chain)})',
                  caloriesPer100g: item.caloriesPer100g,
                  proteinPer100g: item.proteinPer100g,
                  carbsPer100g: item.carbsPer100g,
                  fatPer100g: item.fatPer100g,
                  servingSize: item.servingSize,
                  servingProtein: item.servingProtein,
                  servingCarbs: item.servingCarbs,
                  servingFat: item.servingFat,
                )
              : item;
          return _withCategory(branded, chain);
        }).toList();
        _fastFoodAll!.addAll(items);
        _log('\u2705 Loaded ${items.length} items from $chain');
      } catch (_) {
        // File doesn't exist yet — silently skip
      }
    }
    _log('\u2705 Total fast food items: ${_fastFoodAll!.length}');
    return _fastFoodAll!;
  }

  String _capitalizeChain(String chain) {
    switch (chain) {
      case 'mcdonalds':
        return "McDonald's";
      case 'kfc':
        return 'KFC';
      case 'subway':
        return 'Subway';
      case 'starbucks':
        return 'Starbucks';
      default:
        return chain[0].toUpperCase() + chain.substring(1);
    }
  }

  Future<List<FoodItem>> searchUsdaFoods(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return [];

    final uri = Uri.https('api.nal.usda.gov', '/fdc/v1/foods/search', {
      'query': normalizedQuery,
      'pageSize': '12',
      'api_key': const String.fromEnvironment(
        'USDA_API_KEY',
        defaultValue: 'DEMO_KEY',
      ),
    });

    try {
      final response = await http
          .get(uri, headers: {'User-Agent': 'DimeStoreMacro/1.0'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 429) {
        _log(
          '\u26a0\ufe0f USDA rate limit hit (DEMO_KEY allows 30 req/hour). Register a free key at fdc.nal.usda.gov',
        );
        throw UsdaRateLimitException();
      }
      if (response.statusCode != 200) {
        _log('USDA API error: ${response.statusCode}');
        return [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final foods = (data['foods'] as List<dynamic>?) ?? [];
      _log('\u1f30d USDA: ${foods.length} raw results for "$normalizedQuery"');
      final parsed = foods.map<FoodItem>(_foodItemFromUsda).where((item) {
        return item.proteinPer100g > 0 ||
            item.carbsPer100g > 0 ||
            item.fatPer100g > 0;
      }).toList();
      _log('\u2705 USDA: ${parsed.length} items after macro filter');
      return parsed;
    } on TimeoutException {
      _log('USDA API timeout');
      return [];
    } on SocketException {
      _log('No internet connection');
      return [];
    } catch (e) {
      _log('USDA API error: $e');
      return [];
    }
  }

  Future<FoodItem?> fetchOpenFoodFactsBarcode(String barcode) async {
    final uri = Uri.https(
      'world.openfoodfacts.org',
      '/api/v0/product/$barcode.json',
    );

    try {
      final response = await http
          .get(uri, headers: {'User-Agent': 'DimeStoreMacro/1.0'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        _log('OpenFoodFacts error: ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if ((data['status'] as int?) != 1) return null;

      final product = data['product'] as Map<String, dynamic>?;
      if (product == null) return null;

      final nutriments = product['nutriments'] as Map<String, dynamic>? ?? {};
      final name =
          product['product_name'] as String? ??
          product['generic_name'] as String? ??
          'Scanned product';
      final servingSize = product['serving_size'] as String?;

      final calories =
          _parseDouble(nutriments['energy-kcal_100g']) ??
          _parseDouble(nutriments['energy_100g']) ??
          0;
      final protein = _parseDouble(nutriments['proteins_100g']) ?? 0;
      final carbs =
          _parseDouble(nutriments['carbohydrates_100g']) ??
          _parseDouble(nutriments['carbohydrates_value']) ??
          0;
      final fat = _parseDouble(nutriments['fat_100g']) ?? 0;

      if (protein == 0 && carbs == 0 && fat == 0) return null;

      return FoodItem(
        name: name,
        caloriesPer100g: calories.round(),
        proteinPer100g: protein.round(),
        carbsPer100g: carbs.round(),
        fatPer100g: fat.round(),
        servingSize: servingSize,
        servingProtein: _parseDouble(nutriments['proteins_serving'])?.round(),
        servingCarbs: _parseDouble(
          nutriments['carbohydrates_serving'],
        )?.round(),
        servingFat: _parseDouble(nutriments['fat_serving'])?.round(),
      );
    } on TimeoutException {
      _log('OpenFoodFacts timeout');
      return null;
    } on SocketException {
      _log('No internet connection');
      return null;
    } catch (e) {
      _log('OpenFoodFacts error: $e');
      return null;
    }
  }

  FoodItem _foodItemFromUsda(dynamic rawFood) {
    final food = rawFood as Map<String, dynamic>;
    final name = food['description'] as String? ?? 'USDA Food';
    final nutrients = (food['foodNutrients'] as List<dynamic>?) ?? [];

    final calories = _readNutrientValue(nutrients, '208');
    final protein = _readNutrientValue(nutrients, '203');
    final carbs = _readNutrientValue(nutrients, '205');
    final fat = _readNutrientValue(nutrients, '204');

    // servingSize in USDA response is a number (e.g. 28.35), not a string
    final servingSizeRaw = food['servingSize'];
    final servingSizeUnit = food['servingSizeUnit'] as String? ?? 'g';
    final servingSizeStr = servingSizeRaw != null
        ? '${_parseDouble(servingSizeRaw)?.toStringAsFixed(1) ?? servingSizeRaw} $servingSizeUnit'
        : null;

    return FoodItem(
      name: name,
      caloriesPer100g: calories.round(),
      proteinPer100g: protein.round(),
      carbsPer100g: carbs.round(),
      fatPer100g: fat.round(),
      servingSize: servingSizeStr,
      servingProtein: null,
      servingCarbs: null,
      servingFat: null,
    );
  }

  double _readNutrientValue(List<dynamic> nutrients, String nutrientNumber) {
    for (final entry in nutrients) {
      final nutrient = entry as Map<String, dynamic>;

      // Flat structure: branded foods search results
      final flatNumber =
          nutrient['nutrientNumber']?.toString() ??
          nutrient['number']?.toString();
      if (flatNumber == nutrientNumber) {
        return _parseDouble(nutrient['value']) ??
            _parseDouble(nutrient['amount']) ??
            0;
      }

      // Nested structure: Foundation / SR Legacy foods
      final nested = nutrient['nutrient'] as Map<String, dynamic>?;
      if (nested != null) {
        final nestedNumber = nested['number']?.toString();
        if (nestedNumber == nutrientNumber) {
          return _parseDouble(nutrient['amount']) ?? 0;
        }
      }
    }
    return 0;
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '.'));
    return null;
  }
}

/// Thrown when the USDA API returns HTTP 429 (rate limit exceeded).
class UsdaRateLimitException implements Exception {
  @override
  String toString() =>
      'USDA rate limit exceeded. Try again later or use a registered API key.';
}
