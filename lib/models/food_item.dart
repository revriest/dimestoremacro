class FoodItem {
  final String name;
  final int caloriesPer100g;
  final int proteinPer100g;
  final int carbsPer100g;
  final int fatPer100g;
  final String? servingSize;
  final int? servingProtein;
  final int? servingCarbs;
  final int? servingFat;
  final String? category;
  final List<String> searchAliases;

  const FoodItem({
    required this.name,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.servingSize,
    this.servingProtein,
    this.servingCarbs,
    this.servingFat,
    this.category,
    this.searchAliases = const [],
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    final macros = json['macros'] as Map<String, dynamic>?;
    final bool isSeedSchema = macros != null;

    final caloriesPer100g = isSeedSchema
      ? _readNum(macros['calories'])
        : _readNum(json['calories_per_100g']);
    final proteinPer100g = isSeedSchema
      ? _readNum(macros['protein_g'])
        : _readNum(json['protein_per_100g']);
    final carbsPer100g = isSeedSchema
      ? _readNum(macros['carbs_g'])
        : _readNum(json['carbs_per_100g']);
    final fatPer100g = isSeedSchema
      ? _readNum(macros['fat_g'])
        : _readNum(json['fat_per_100g']);
    final computedCalories =
        ((proteinPer100g * 4) + (carbsPer100g * 4) + (fatPer100g * 9)).round();

    int sanitizedCalories = caloriesPer100g;
    if (sanitizedCalories < 0) {
      sanitizedCalories = computedCalories;
    } else {
      final calorieDiff = (sanitizedCalories - computedCalories).abs();
      // Guard against clearly bad source calorie values (e.g. zero calories with non-zero macros).
      if ((sanitizedCalories == 0 && computedCalories > 0) || calorieDiff > 50) {
        sanitizedCalories = computedCalories;
      }
    }

    String? servingSize = json['serving_size'] as String?;
    int? servingProtein = json['serving_protein'] is num
        ? (json['serving_protein'] as num).round()
        : null;
    int? servingCarbs = json['serving_carbs'] is num
        ? (json['serving_carbs'] as num).round()
        : null;
    int? servingFat = json['serving_fat'] is num
        ? (json['serving_fat'] as num).round()
        : null;

    if (isSeedSchema) {
      final servings = json['servings'] as List<dynamic>? ?? const [];
      Map<String, dynamic>? pickedServing;
      for (final item in servings) {
        if (item is! Map<String, dynamic>) continue;
        final label = (item['label'] ?? '').toString().toLowerCase();
        final weight = _readDouble(item['weight_g']);
        if (weight <= 0) continue;
        if (label.contains('density')) continue;
        pickedServing = item;
        break;
      }

      if (pickedServing != null) {
        final label = (pickedServing['label'] ?? 'Serving').toString();
        final weight = _readDouble(pickedServing['weight_g']);
        servingSize = '$label (${weight.toStringAsFixed(0)}g)';
        final multiplier = weight / 100.0;
        servingProtein = (proteinPer100g * multiplier).round();
        servingCarbs = (carbsPer100g * multiplier).round();
        servingFat = (fatPer100g * multiplier).round();
      }
    }

    final aliases = json['search_aliases'] is List
      ? (json['search_aliases'] as List)
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList()
      : const <String>[];

    return FoodItem(
      name: (json['name'] ?? '').toString(),
      caloriesPer100g: sanitizedCalories,
      proteinPer100g: proteinPer100g,
      carbsPer100g: carbsPer100g,
      fatPer100g: fatPer100g,
      servingSize: servingSize,
      servingProtein: servingProtein,
      servingCarbs: servingCarbs,
      servingFat: servingFat,
      category: json['category'] as String?,
      searchAliases: aliases,
    );
  }

  FoodItem copyWith({
    String? name,
    int? caloriesPer100g,
    int? proteinPer100g,
    int? carbsPer100g,
    int? fatPer100g,
    String? servingSize,
    int? servingProtein,
    int? servingCarbs,
    int? servingFat,
    String? category,
    List<String>? searchAliases,
  }) {
    return FoodItem(
      name: name ?? this.name,
      caloriesPer100g: caloriesPer100g ?? this.caloriesPer100g,
      proteinPer100g: proteinPer100g ?? this.proteinPer100g,
      carbsPer100g: carbsPer100g ?? this.carbsPer100g,
      fatPer100g: fatPer100g ?? this.fatPer100g,
      servingSize: servingSize ?? this.servingSize,
      servingProtein: servingProtein ?? this.servingProtein,
      servingCarbs: servingCarbs ?? this.servingCarbs,
      servingFat: servingFat ?? this.servingFat,
      category: category ?? this.category,
      searchAliases: searchAliases ?? this.searchAliases,
    );
  }

  static int _readNum(dynamic value) {
    if (value is num) return value.round();
    if (value is String) {
      final parsed = double.tryParse(value.replaceAll(',', '.'));
      return parsed?.round() ?? 0;
    }
    return 0;
  }

  static double _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'calories_per_100g': caloriesPer100g,
      'protein_per_100g': proteinPer100g,
      'carbs_per_100g': carbsPer100g,
      'fat_per_100g': fatPer100g,
      if (servingSize != null) 'serving_size': servingSize,
      if (servingProtein != null) 'serving_protein': servingProtein,
      if (servingCarbs != null) 'serving_carbs': servingCarbs,
      if (servingFat != null) 'serving_fat': servingFat,
      if (category != null) 'category': category,
      if (searchAliases.isNotEmpty) 'search_aliases': searchAliases,
    };
  }
}
