import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'models/food_item.dart';

class FoodRepository {
  static final FoodRepository instance = FoodRepository._();
  FoodRepository._();

  List<FoodItem>? _localFoods;

  Future<List<FoodItem>> loadLocalFoods() async {
    if (_localFoods != null) return _localFoods!;
    final raw = await rootBundle.loadString('assets/data/generic_foods.json');
    final data = jsonDecode(raw) as List<dynamic>;
    _localFoods = data.map((entry) => FoodItem.fromJson(entry as Map<String, dynamic>)).toList();
    return _localFoods!;
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
      'api_key': const String.fromEnvironment('USDA_API_KEY', defaultValue: 'HdGTRLyEiCAM3d2KuxRxVAyXvqpQhMFB5oDVsBAE'),
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
