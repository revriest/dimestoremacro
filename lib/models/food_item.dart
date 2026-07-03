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
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      name: json['name'] as String,
      caloriesPer100g: (json['calories_per_100g'] as num).round(),
      proteinPer100g: (json['protein_per_100g'] as num).round(),
      carbsPer100g: (json['carbs_per_100g'] as num).round(),
      fatPer100g: (json['fat_per_100g'] as num).round(),
      servingSize: json['serving_size'] as String?,
      servingProtein: json['serving_protein'] is num ? (json['serving_protein'] as num).round() : null,
      servingCarbs: json['serving_carbs'] is num ? (json['serving_carbs'] as num).round() : null,
      servingFat: json['serving_fat'] is num ? (json['serving_fat'] as num).round() : null,
    );
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
    };
  }
}
