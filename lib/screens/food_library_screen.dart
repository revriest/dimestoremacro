import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../database_helper.dart';
import '../models/food_item.dart';
import '../widgets/food_search_sheet.dart';
import '../widgets/support_actions.dart';

class FoodLibraryScreen extends StatefulWidget {
  const FoodLibraryScreen({super.key});
  @override
  State<FoodLibraryScreen> createState() => _FoodLibraryScreenState();
}

class _FoodLibraryScreenState extends State<FoodLibraryScreen> {
  List<Map<String, dynamic>> _foods = [];

  double _parseServingGramWeight(String? servingSize) {
    if (servingSize == null) return 0.0;
    final normalized = servingSize.toLowerCase();
    final match = RegExp(
      r'([\d,.]+)\s*(g|gram|grams|ml|milliliter|milliliters)',
    ).firstMatch(normalized);
    if (match == null) return 0.0;
    final value = double.tryParse(match.group(1)!.replaceAll(',', '.')) ?? 0.0;
    if (value <= 0) return 0.0;

    final unit = match.group(2) ?? '';
    if (unit.startsWith('ml') || unit.startsWith('milliliter')) {
      return value;
    }
    return value;
  }

  bool _hasServingData(FoodItem item) {
    final servingWeight = _parseServingGramWeight(item.servingSize);
    return servingWeight > 0 ||
        (item.servingProtein ?? 0) > 0 ||
        (item.servingCarbs ?? 0) > 0 ||
        (item.servingFat ?? 0) > 0;
  }

  Map<String, int> _resolveFoodMacros(
    FoodItem item,
    double quantity,
    bool useServing,
  ) {
    final p100 = item.proteinPer100g;
    final c100 = item.carbsPer100g;
    final f100 = item.fatPer100g;
    final pServing = item.servingProtein ?? 0;
    final cServing = item.servingCarbs ?? 0;
    final fServing = item.servingFat ?? 0;
    final servingWeight = _parseServingGramWeight(item.servingSize);

    if (useServing) {
      if (pServing > 0 || cServing > 0 || fServing > 0) {
        return {
          'protein': (pServing * quantity).round(),
          'carbs': (cServing * quantity).round(),
          'fat': (fServing * quantity).round(),
        };
      }
      if (servingWeight > 0) {
        final factor = servingWeight * quantity / 100.0;
        return {
          'protein': (p100 * factor).round(),
          'carbs': (c100 * factor).round(),
          'fat': (f100 * factor).round(),
        };
      }
      return {
        'protein': (p100 * quantity).round(),
        'carbs': (c100 * quantity).round(),
        'fat': (f100 * quantity).round(),
      };
    }

    final factor = quantity / 100.0;
    return {
      'protein': (p100 * factor).round(),
      'carbs': (c100 * factor).round(),
      'fat': (f100 * factor).round(),
    };
  }

  Future<void> _showFoodAdjustDialog(FoodItem item) async {
    final quantityController = TextEditingController();
    final hasServingData = _hasServingData(item);
    bool useServing = hasServingData;
    quantityController.text = useServing ? '1' : '100';

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1C1C1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'ADD FROM SEARCH',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: Colors.blueAccent,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (item.servingSize != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Serving size: ${item.servingSize}',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Per Serving'),
                          selected: useServing,
                          onSelected: hasServingData
                              ? (_) {
                                  setState(() {
                                    useServing = true;
                                    quantityController.text = '1';
                                  });
                                }
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Grams'),
                          selected: !useServing,
                          onSelected: (_) {
                            setState(() {
                              useServing = false;
                              quantityController.text = '100';
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: quantityController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      hintText: useServing ? 'Number of servings' : 'Amount in grams',
                      labelText: useServing ? 'Per Serving' : 'Grams',
                      suffixText: useServing ? null : 'g',
                    ),
                  ),
                  if (!hasServingData) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Per serving unavailable for this food. Use grams.',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final raw = quantityController.text.replaceAll(',', '.');
                    final quantity =
                        double.tryParse(raw) ?? (useServing ? 1.0 : 100.0);
                    final macros = _resolveFoodMacros(item, quantity, useServing);
                    final servingLabel = useServing
                        ? '${quantity % 1 == 0 ? quantity.toInt() : quantity} serving${quantity == 1.0 ? '' : 's'}'
                        : '${quantity % 1 == 0 ? quantity.toInt() : quantity}g';
                    final displayName = '${item.name} ($servingLabel)';
                    final servingGrams = _parseServingGramWeight(item.servingSize);
                    Navigator.pop(ctx);
                    await DatabaseHelper.instance.insertCustomFood(
                      displayName,
                      macros['protein']!,
                      macros['carbs']!,
                      macros['fat']!,
                      measureMode: useServing ? 'serving' : 'grams',
                      measureAmount: quantity,
                      servingGrams: servingGrams > 0 ? servingGrams : null,
                    );
                    if (!mounted) return;
                    await _loadFoods();
                  },
                  child: const Text(
                    'SAVE',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openSearchFoodDialog() async {
    final selectedItem = await showModalBottomSheet<FoodItem>(
      context: context,
      backgroundColor: const Color(0xFF111113),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (_) => FoodSearchSheet(
        onScanBarcode: () async {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Barcode scan is available from the Dashboard search.'),
              backgroundColor: Colors.blueGrey,
            ),
          );
        },
      ),
    );

    if (!mounted || selectedItem == null) return;
    await _showFoodAdjustDialog(selectedItem);
  }

  Future<void> _showAddMealOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(
                  Icons.search_rounded,
                  color: Colors.blueAccent,
                ),
                title: const Text(
                  'Search Foods',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Find a food, adjust grams/servings, then save as custom meal.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _openSearchFoodDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_rounded, color: Colors.white70),
                title: const Text(
                  'Manual Entry',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Create a meal by entering name and macros yourself.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddFoodDialog();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _loadFoods();
  }

  Future<void> _loadFoods() async {
    final foods = await DatabaseHelper.instance.getAllCustomFoods();
    bool migrated = false;

    for (final food in foods) {
      if (food['name'] == 'Protein Pancakes') {
        await DatabaseHelper.instance.updateCustomFood(
          food['id'] as int,
          'White Rice (100g)',
          3,
          28,
          0,
        );
        migrated = true;
      }
    }

    if (migrated) {
      final updatedFoods = await DatabaseHelper.instance.getAllCustomFoods();
      setState(() => _foods = updatedFoods);
    } else {
      setState(() => _foods = foods);
    }
  }

  Future<void> _toggleFavorite(Map<String, dynamic> food) async {
    final int id = food['id'] as int;
    final bool isNowFavorite = (food['is_favorite'] as int? ?? 0) == 0;
    await DatabaseHelper.instance.toggleCustomFoodFavorite(id, isNowFavorite);
    HapticFeedback.selectionClick();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isNowFavorite ? '⭐ Added to Quick Meals' : 'Removed from Quick Meals',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    _loadFoods();
  }

  Future<void> _confirmDeleteCustomMeal(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Delete custom meal?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          content: Text(
            'Remove "$name" from your custom meals? This cannot be undone.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Delete',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await DatabaseHelper.instance.deleteCustomFood(id);
      if (!mounted) return;
      _loadFoods();
    }
  }

  void _showAddFoodDialog() {
    final nameCtrl = TextEditingController();
    final gramsCtrl = TextEditingController(text: '100');
    final pCtrl = TextEditingController();
    final cCtrl = TextEditingController();
    final fCtrl = TextEditingController();
    bool useCustomGrams = true;

    final parentContext = context;
    showDialog(
      context: parentContext,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final String grams = gramsCtrl.text.trim().isEmpty
              ? '100'
              : gramsCtrl.text.trim();
          final String macroLabel = useCustomGrams
              ? 'per ${grams}g'
              : 'per serving';
          final String nameHint = useCustomGrams
              ? 'e.g., Chicken Breast'
              : 'e.g., Protein Shake (1 serving)';

          return AlertDialog(
            backgroundColor: const Color(0xFF1C1C1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'ADD CUSTOM MEAL',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: Colors.blueAccent,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(hintText: nameHint),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Custom grams'),
                        selected: useCustomGrams,
                        onSelected: (_) =>
                            setDialogState(() => useCustomGrams = true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Per Serving'),
                        selected: !useCustomGrams,
                        onSelected: (_) =>
                            setDialogState(() => useCustomGrams = false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  useCustomGrams
                      ? 'For raw ingredients (chicken, rice, etc.)'
                      : 'For prepared meals (smoothie, casserole, etc.)',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                if (useCustomGrams) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: gramsCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Serving size',
                      hintText: '100',
                      suffixText: 'g',
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: pCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: '0',
                          labelText: 'P ($macroLabel)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: cCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: '0',
                          labelText: 'C ($macroLabel)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: fCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: '0',
                          labelText: 'F ($macroLabel)',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'CANCEL',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  if (nameCtrl.text.isNotEmpty) {
                    final String baseName = nameCtrl.text.trim();
                    final String fullName = useCustomGrams
                        ? '$baseName (${gramsCtrl.text.trim().isEmpty ? '100' : gramsCtrl.text.trim()}g)'
                        : baseName;
                    Navigator.pop(ctx);
                    await DatabaseHelper.instance.insertCustomFood(
                      fullName,
                      int.tryParse(pCtrl.text) ?? 0,
                      int.tryParse(cCtrl.text) ?? 0,
                      int.tryParse(fCtrl.text) ?? 0,
                    );
                    if (!mounted) return;
                    _loadFoods();
                  }
                },
                child: const Text(
                  'SAVE',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditFoodDialog(Map<String, dynamic> food) {
    final originalP = (food['protein'] as num? ?? 0).toInt();
    final originalC = (food['carbs'] as num? ?? 0).toInt();
    final originalF = (food['fat'] as num? ?? 0).toInt();
    final originalName = food['name'] as String? ?? '';

    // Try to parse the existing gram amount from the name, e.g. "Chicken Breast (50g)"
    final gramMatch = RegExp(r'\((\d+(?:\.\d+)?)g\)$').firstMatch(originalName);
    final baseName = gramMatch != null
        ? originalName.substring(0, gramMatch.start).trim()
        : originalName;
    final parsedGrams = gramMatch != null
        ? double.tryParse(gramMatch.group(1)!)
        : null;

    final nameCtrl = TextEditingController(text: baseName);
    final gramsCtrl = TextEditingController(
      text: parsedGrams?.toStringAsFixed(0) ?? '',
    );
    final pCtrl = TextEditingController(text: originalP.toString());
    final cCtrl = TextEditingController(text: originalC.toString());
    final fCtrl = TextEditingController(text: originalF.toString());
    bool useCustomGrams = parsedGrams != null || gramMatch != null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final grams = gramsCtrl.text.trim().isEmpty
              ? '100'
              : gramsCtrl.text.trim();
          final macroLabel = useCustomGrams ? 'per ${grams}g' : 'per serving';

          return AlertDialog(
            backgroundColor: const Color(0xFF1C1C1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'EDIT MEAL',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: Colors.blueAccent,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Meal name'),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Custom grams'),
                        selected: useCustomGrams,
                        onSelected: (_) =>
                            setDialogState(() => useCustomGrams = true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Per Serving'),
                        selected: !useCustomGrams,
                        onSelected: (_) =>
                            setDialogState(() => useCustomGrams = false),
                      ),
                    ),
                  ],
                ),
                if (useCustomGrams) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: gramsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Serving size',
                      suffixText: 'g',
                    ),
                    onChanged: (val) {
                      final newGrams = double.tryParse(val);
                      if (newGrams != null && newGrams > 0) {
                        setDialogState(() {
                          pCtrl.text =
                              ((originalP * newGrams / (parsedGrams ?? 100))
                                      .round())
                                  .toString();
                          cCtrl.text =
                              ((originalC * newGrams / (parsedGrams ?? 100))
                                      .round())
                                  .toString();
                          fCtrl.text =
                              ((originalF * newGrams / (parsedGrams ?? 100))
                                      .round())
                                  .toString();
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Macros scale automatically when grams change',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: pCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: '0',
                          labelText: 'P ($macroLabel)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: cCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: '0',
                          labelText: 'C ($macroLabel)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: fCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: '0',
                          labelText: 'F ($macroLabel)',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'CANCEL',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  if (nameCtrl.text.isNotEmpty) {
                    final base = nameCtrl.text.trim();
                    final fullName =
                        useCustomGrams && gramsCtrl.text.trim().isNotEmpty
                        ? '$base (${gramsCtrl.text.trim()}g)'
                        : base;
                    Navigator.pop(ctx);
                    await DatabaseHelper.instance.updateCustomFood(
                      food['id'] as int,
                      fullName,
                      int.tryParse(pCtrl.text) ?? 0,
                      int.tryParse(cCtrl.text) ?? 0,
                      int.tryParse(fCtrl.text) ?? 0,
                    );
                    if (!mounted) return;
                    _loadFoods();
                  }
                },
                child: const Text(
                  'SAVE',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showMealOptions(Map<String, dynamic> food) {
    final int p = (food['protein'] as num? ?? 0).toInt();
    final int c = (food['carbs'] as num? ?? 0).toInt();
    final int f = (food['fat'] as num? ?? 0).toInt();
    final int cal = (p * 4) + (c * 4) + (f * 9);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final bool isFav = (food['is_favorite'] as int? ?? 0) == 1;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      if (isFav)
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 16,
                        ),
                      if (isFav) const SizedBox(width: 6),
                      Text(
                        food['name'] as String? ?? 'Meal',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'P ${p}g  •  C ${c}g  •  F ${f}g  •  $cal kcal',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ),
              const Divider(color: Colors.white12, height: 24),
              ListTile(
                leading: const Icon(
                  Icons.add_circle_outline_rounded,
                  color: Colors.blueAccent,
                ),
                title: const Text(
                  'Add to Today',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final DateTime n = DateTime.now();
                  final String key = "${n.year}-${n.month}-${n.day}";
                  await DatabaseHelper.instance.insertDailyEntry(
                    key,
                    food['name'] as String? ?? 'Custom Meal',
                    p,
                    c,
                    f,
                    entryMode: (food['measure_mode'] as String?) ?? 'grams',
                    measureAmount:
                        (food['measure_amount'] as num?)?.toDouble() ?? 100.0,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Logged ${food['name']}! (+$cal kcal)'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: Colors.amber,
                ),
                title: Text(
                  isFav ? 'Remove from Quick Meals' : 'Pin to Quick Meals',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _toggleFavorite(food);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: Colors.white70),
                title: const Text(
                  'Edit Meal',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditFoodDialog(food);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteCustomMeal(
                    food['id'] as int,
                    food['name'] as String? ?? 'Meal',
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'CUSTOM MEALS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
        actions: SupportActions.appBarActions(context),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.blueAccent,
        onPressed: _showAddMealOptions,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'New Meal',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _foods.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.restaurant_menu_rounded,
                    size: 56,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No custom meals yet',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap "New Meal" to add one',
                    style: TextStyle(color: Colors.white30, fontSize: 13),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: 100,
              ),
              itemCount: _foods.length,
              itemBuilder: (ctx, i) {
                final food = _foods[i];
                return Dismissible(
                  key: Key(food['id'].toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.delete_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  confirmDismiss: (direction) async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF1C1C1E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        title: const Text(
                          'Delete meal?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        content: Text(
                          'Remove "${food['name']}"?',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text(
                              'Delete',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                    return confirmed ?? false;
                  },
                  onDismissed: (_) async {
                    await DatabaseHelper.instance.deleteCustomFood(
                      food['id'] as int,
                    );
                    if (mounted) _loadFoods();
                  },
                  child: GestureDetector(
                    onLongPress: () => _showMealOptions(food),
                    child: Card(
                      color: Colors.white.withValues(alpha: 0.03),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      elevation: 0,
                      child: ListTile(
                        onTap: () => _showMealOptions(food),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        title: Text(
                          food['name'] ?? 'Unknown',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'P: ${food['protein']}g  •  C: ${food['carbs']}g  •  F: ${food['fat']}g',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () => _toggleFavorite(food),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 12,
                                ),
                                child: Icon(
                                  (food['is_favorite'] as int? ?? 0) == 1
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  color: (food['is_favorite'] as int? ?? 0) == 1
                                      ? Colors.amber
                                      : Colors.white24,
                                  size: 24,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white24,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
