import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models/food_item.dart';

class FoodRepository {
  static final FoodRepository instance = FoodRepository._();
  FoodRepository._();

  List<FoodItem>? _localFoods;
  String? _currentRegion;

  static const List<Map<String, String>> supportedRegions = [
    {'code': 'US', 'name': '\u1f1fa\u1f1f8 United States'},
    {'code': 'GB', 'name': '\u1f1ec\u1f1e7 United Kingdom'},
    {'code': 'CA', 'name': '\u1f1e8\u1f1e6 Canada'},
    {'code': 'AU', 'name': '\u1f1e6\u1f1fa Australia'},
    {'code': 'DE', 'name': '\u1f1e9\u1f1ea Germany'},
    {'code': 'FR', 'name': '\u1f1eb\u1f1f7 France'},
    {'code': 'ES', 'name': '\u1f1ea\u1f1f8 Spain'},
    {'code': 'IT', 'name': '\u1f1ee\u1f1f9 Italy'},
    {'code': 'BR', 'name': '\u1f1e7\u1f1f7 Brazil'},
    {'code': 'MX', 'name': '\u1f1f2\u1f1fd Mexico'},
    {'code': 'IN', 'name': '\u1f1ee\u1f1f3 India'},
    {'code': 'NL', 'name': '\u1f1f3\u1f1f1 Netherlands'},
    {'code': 'SE', 'name': '\u1f1f8\u1f1ea Sweden'},
    {'code': 'AE', 'name': '\u1f1e6\u1f1ea UAE'},
    {'code': 'SA', 'name': '\u1f1f8\u1f1e6 Saudi Arabia'},
    {'code': 'ZA', 'name': '\u1f1ff\u1f1e6 South Africa'},
    {'code': 'JP', 'name': '\u1f1ef\u1f1f5 Japan'},
    {'code': 'KR', 'name': '\u1f1f0\u1f1f7 South Korea'},
    {'code': 'GENERIC', 'name': '\u1f30d International (generic)'},
  ];

  Future<String> _detectDeviceRegion() async {
    final locale = ui.PlatformDispatcher.instance.locale;
    return locale.countryCode ?? 'GENERIC';
  }

  Future<String> getCurrentRegion() async {
    if (_currentRegion != null) return _currentRegion!;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('user_region');
    if (stored != null) {
      _currentRegion = stored;
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
  }

  Future<bool> hasRegionDatabase(String countryCode) async {
    try {
      await rootBundle.loadString('assets/data/foods_${countryCode.toLowerCase()}.json');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<FoodItem>> loadLocalFoods() async {
    if (_localFoods != null) return _localFoods!;
    final region = await getCurrentRegion();
    final regionFile = 'assets/data/foods_${region.toLowerCase()}.json';
    try {
      final raw = await rootBundle.loadString(regionFile);
      final data = jsonDecode(raw) as List<dynamic>;
      _localFoods = data.map((e) => FoodItem.fromJson(e as Map<String, dynamic>)).toList();
      return _localFoods!;
    } catch (_) {
      // Fall back to generic database
      final raw = await rootBundle.loadString('assets/data/generic_foods.json');
      final data = jsonDecode(raw) as List<dynamic>;
      _localFoods = data.map((e) => FoodItem.fromJson(e as Map<String, dynamic>)).toList();
      return _localFoods!;
    }
  }

  Future<List<FoodItem>> searchLocalFoods(String query) async {
    final foods = await loadLocalFoods();
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return [];
    return foods.where((food) => food.name.toLowerCase().contains(normalizedQuery)).toList();
  }

  Future<List<FoodItem>> searchUsdaFoods(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return [];

    final uri = Uri.https('api.nal.usda.gov', '/fdc/v1/foods/search', {
      'query': normalizedQuery,
      'pageSize': '12',
      'api_key': const String.fromEnvironment('USDA_API_KEY', defaultValue: 'DEMO_KEY'),
    });

    try {
      final response = await http
          .get(uri, headers: {'User-Agent': 'DimeStoreMacro/1.0'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        // ignore: avoid_print
        print('USDA API error: ${response.statusCode}');
        return [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final foods = (data['foods'] as List<dynamic>?) ?? [];
      return foods.map<FoodItem>(_foodItemFromUsda).where((item) {
        return item.proteinPer100g > 0 || item.carbsPer100g > 0 || item.fatPer100g > 0;
      }).toList();
    } on TimeoutException {
      // ignore: avoid_print
      print('USDA API timeout');
      return [];
    } on SocketException {
      // ignore: avoid_print
      print('No internet connection');
      return [];
    } catch (e) {
      // ignore: avoid_print
      print('USDA API error: $e');
      return [];
    }
  }

  Future<FoodItem?> fetchOpenFoodFactsBarcode(String barcode) async {
    final uri = Uri.https('world.openfoodfacts.org', '/api/v0/product/$barcode.json');

    try {
      final response = await http
          .get(uri, headers: {'User-Agent': 'DimeStoreMacro/1.0'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        // ignore: avoid_print
        print('OpenFoodFacts error: ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if ((data['status'] as int?) != 1) return null;

      final product = data['product'] as Map<String, dynamic>?;
      if (product == null) return null;

      final nutriments = product['nutriments'] as Map<String, dynamic>? ?? {};
      final name = product['product_name'] as String? ?? product['generic_name'] as String? ?? 'Scanned product';
      final servingSize = product['serving_size'] as String?;

      final calories = _parseDouble(nutriments['energy-kcal_100g']) ?? _parseDouble(nutriments['energy_100g']) ?? 0;
      final protein = _parseDouble(nutriments['proteins_100g']) ?? 0;
      final carbs = _parseDouble(nutriments['carbohydrates_100g']) ?? _parseDouble(nutriments['carbohydrates_value']) ?? 0;
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
        servingCarbs: _parseDouble(nutriments['carbohydrates_serving'])?.round(),
        servingFat: _parseDouble(nutriments['fat_serving'])?.round(),
      );
    } on TimeoutException {
      // ignore: avoid_print
      print('OpenFoodFacts timeout');
      return null;
    } on SocketException {
      // ignore: avoid_print
      print('No internet connection');
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('OpenFoodFacts error: $e');
      return null;
    }
  }

  FoodItem _foodItemFromUsda(dynamic rawFood) {
    final food = rawFood as Map<String, dynamic>;
    final name = food['description'] as String? ?? food['description'] as String? ?? 'USDA Food';
    final nutrients = (food['foodNutrients'] as List<dynamic>?) ?? [];

    final calories = _readNutrientValue(nutrients, '208');
    final protein = _readNutrientValue(nutrients, '203');
    final carbs = _readNutrientValue(nutrients, '205');
    final fat = _readNutrientValue(nutrients, '204');

    return FoodItem(
      name: name,
      caloriesPer100g: calories.round(),
      proteinPer100g: protein.round(),
      carbsPer100g: carbs.round(),
      fatPer100g: fat.round(),
      servingSize: food['servingSize'] as String?,
      servingProtein: null,
      servingCarbs: null,
      servingFat: null,
    );
  }

  double _readNutrientValue(List<dynamic> nutrients, String nutrientNumber) {
    for (final entry in nutrients) {
      final nutrient = entry as Map<String, dynamic>;
      final number = nutrient['nutrientNumber']?.toString() ?? nutrient['number']?.toString();
      if (number == nutrientNumber) {
        return _parseDouble(nutrient['value']) ?? 0;
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
