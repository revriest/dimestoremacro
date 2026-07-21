import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';

import '../database_helper.dart';
import '../food_repository.dart';
import '../models/food_item.dart';
import 'settings_screen.dart';
import 'barcode_scanner_screen.dart';
import 'about_screen.dart';
import '../widgets/food_search_sheet.dart';
import '../widgets/support_actions.dart';

enum _TopBarAction { stats, weightHistory, about, help, share, reset }

enum _WeightRange { week, month, threeMonths }

class DashboardScreen extends StatefulWidget {
  final VoidCallback onManageMeals;
  const DashboardScreen({super.key, required this.onManageMeals});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int currentCalories = 0, protein = 0, carbs = 0, fat = 0;
  int proteinTarget = 180,
      carbsTarget = 200,
      fatTarget = 70,
      calorieTarget = 2150;
  final _pController = TextEditingController();
  final _cController = TextEditingController();
  final _fController = TextEditingController();
  final List<TextInputFormatter> _macroInputFormatters = [
    LengthLimitingTextInputFormatter(7),
    TextInputFormatter.withFunction((oldValue, newValue) {
      final next = newValue.text;
      if (next.isEmpty) return newValue;
      final ok = RegExp(r'^\d{0,4}([.,]\d{0,1})?$').hasMatch(next);
      return ok ? newValue : oldValue;
    }),
  ];
  List<Map<String, dynamic>> _entries = [];
  List<Map<String, dynamic>> _favoriteMeals = [];
  double? _weightForSelectedDateKg;
  double? _latestWeightKg;
  DateTime? _latestWeightDate;
  String _weightUnit = 'kg';

  DateTime _selectedDate = DateTime.now();

  int _parseMacroInput(String raw) {
    final parsed = double.tryParse(raw.trim().replaceAll(',', '.'));
    if (parsed == null || parsed < 0) return 0;
    return parsed.round();
  }

  String _getDateKey(DateTime date) => "${date.year}-${date.month}-${date.day}";
  String _getDisplayDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'TODAY';
    }
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return "${months[date.month - 1]} ${date.day}, ${date.year}";
  }

  void _changeDate(int days) {
    setState(() => _selectedDate = _selectedDate.add(Duration(days: days)));
    _loadSavedData();
  }

  double _convertKgToUnit(double kg, String unit) {
    return unit == 'lb' ? kg * 2.2046226218 : kg;
  }

  double _convertUnitToKg(double value, String unit) {
    return unit == 'lb' ? value / 2.2046226218 : value;
  }

  String _formatWeight(double kg, {String? unit}) {
    final activeUnit = unit ?? _weightUnit;
    final converted = _convertKgToUnit(kg, activeUnit);
    return '${converted.toStringAsFixed(1)} $activeUnit';
  }

  DateTime? _parseIsoDate(dynamic raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  String _formatCompactDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  int _rangeDays(_WeightRange range) {
    switch (range) {
      case _WeightRange.week:
        return 7;
      case _WeightRange.month:
        return 30;
      case _WeightRange.threeMonths:
        return 90;
    }
  }

  String _rangeLabel(_WeightRange range) {
    switch (range) {
      case _WeightRange.week:
        return '7D';
      case _WeightRange.month:
        return '30D';
      case _WeightRange.threeMonths:
        return '3M';
    }
  }

  Widget _actionMenuRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    Color textColor = Colors.white,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
      ],
    );
  }

  String _weightSummaryText() {
    if (_weightForSelectedDateKg != null) {
      return 'Weight: ${_formatWeight(_weightForSelectedDateKg!)}';
    }
    if (_latestWeightKg != null) {
      final when = _latestWeightDate != null
          ? _formatCompactDate(_latestWeightDate!)
          : 'latest';
      return 'Last: ${_formatWeight(_latestWeightKg!)} on $when';
    }
    return 'Tap to log weight';
  }

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String activeKey = _getDateKey(_selectedDate);
      final totals = await DatabaseHelper.instance.getDailyTotals(activeKey);
      final entries = await DatabaseHelper.instance.getDailyEntries(activeKey);
      final favorites = await DatabaseHelper.instance.getAllCustomFoods(
        favoritesOnly: true,
      );
      final selectedDateWeight = await DatabaseHelper.instance.getWeightForDate(
        activeKey,
      );
      final latestWeight = await DatabaseHelper.instance.getLatestWeight();

      setState(() {
        protein = totals['protein'] ?? 0;
        carbs = totals['carbs'] ?? 0;
        fat = totals['fat'] ?? 0;
        currentCalories = totals['calories'] ?? 0;
        _entries = entries;
        _favoriteMeals = favorites;
        proteinTarget = prefs.getInt('target_protein') ?? 180;
        carbsTarget = prefs.getInt('target_carbs') ?? 200;
        fatTarget = prefs.getInt('target_fat') ?? 70;
        calorieTarget = prefs.getInt('target_calories') ?? 2150;
        _weightUnit = prefs.getString('weight_unit') ?? 'kg';
        _weightForSelectedDateKg =
            (selectedDateWeight?['weight_kg'] as num?)?.toDouble();
        _latestWeightKg = (latestWeight?['weight_kg'] as num?)?.toDouble();
        _latestWeightDate = _parseIsoDate(latestWeight?['created_at']);
      });
      if (currentCalories >= calorieTarget &&
          currentCalories - calorieTarget <= 50) {
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load data: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
          action: SnackBarAction(
            label: 'RETRY',
            textColor: Colors.white,
            onPressed: _loadSavedData,
          ),
        ),
      );
    }
  }

  Future<void> _addEntry(
    String name,
    int p,
    int c,
    int f, {
    String entryMode = 'grams',
    double? measureAmount,
    int? caloriesOverride,
  }) async {
    try {
      String activeKey = _getDateKey(_selectedDate);
      await DatabaseHelper.instance.insertDailyEntry(
        activeKey,
        name,
        p,
        c,
        f,
        entryMode: entryMode,
        measureAmount: measureAmount,
        caloriesOverride: caloriesOverride,
      );
      HapticFeedback.mediumImpact();
      _pController.clear();
      _cController.clear();
      _fController.clear();
      await _loadSavedData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add entry: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _addOrMergeQuickEntry(
    String name,
    int p,
    int c,
    int f, {
    double amount = 0,
  }) async {
    try {
      final existing = _entries
          .where((row) => (row['name'] as String?) == name)
          .toList();

      if (existing.isEmpty) {
        await _addEntry(
          name,
          p,
          c,
          f,
          entryMode: 'grams',
          measureAmount: amount,
        );
        return;
      }

      final primary = existing.first;
      int totalProtein = p;
      int totalCarbs = c;
      int totalFat = f;
      double totalAmount = amount;

      for (final row in existing) {
        totalProtein += (row['protein'] as num?)?.toInt() ?? 0;
        totalCarbs += (row['carbs'] as num?)?.toInt() ?? 0;
        totalFat += (row['fat'] as num?)?.toInt() ?? 0;
        totalAmount += (row['measure_amount'] as num?)?.toDouble() ?? 0.0;
      }

      await DatabaseHelper.instance.updateDailyEntry(
        primary['id'] as int,
        name,
        totalProtein,
        totalCarbs,
        totalFat,
        entryMode: 'grams',
        measureAmount: totalAmount,
      );

      for (final row in existing.skip(1)) {
        await DatabaseHelper.instance.deleteDailyEntry(row['id'] as int);
      }

      HapticFeedback.mediumImpact();
      await _loadSavedData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed quick add: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _resetTotals() async {
    try {
      String activeKey = _getDateKey(_selectedDate);
      await DatabaseHelper.instance.deleteEntriesForDate(activeKey);
      HapticFeedback.heavyImpact();
      await _loadSavedData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete entries: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _confirmResetTotals() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Delete all entries?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          content: const Text(
            'This will remove every entry for the currently selected day. Are you sure?',
            style: TextStyle(color: Colors.white70),
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
      await _resetTotals();
    }
  }

  Future<void> _editEntry(Map<String, dynamic> entry) async {
    final nameController = TextEditingController(
      text: entry['name'] as String? ?? '',
    );
    final pController = TextEditingController(
      text: (entry['protein'] as num?)?.toInt().toString() ?? '0',
    );
    final cController = TextEditingController(
      text: (entry['carbs'] as num?)?.toInt().toString() ?? '0',
    );
    final fController = TextEditingController(
      text: (entry['fat'] as num?)?.toInt().toString() ?? '0',
    );
    final entryProtein = (entry['protein'] as num?)?.toInt() ?? 0;
    final entryCarbs = (entry['carbs'] as num?)?.toInt() ?? 0;
    final entryFat = (entry['fat'] as num?)?.toInt() ?? 0;
    final oldName = entry['name'] as String? ?? '';
    final lowerName = oldName.toLowerCase();
    final storedMode = (entry['entry_mode'] as String?)?.toLowerCase();
    final storedAmount = (entry['measure_amount'] as num?)?.toDouble();
    final hasExplicitServingInName = RegExp(r'\b\d+(?:[.,]\d+)?\s*servings?\b')
      .hasMatch(lowerName);
    final isLegacyServingPlaceholder =
      storedMode == 'serving' &&
      storedAmount != null &&
      (storedAmount - 100.0).abs() < 0.0001 &&
      !hasExplicitServingInName;
    final hasReliableStoredAmount =
      storedAmount != null && !isLegacyServingPlaceholder;
    String formatAmount(double amount) {
      if (amount.isNaN || amount.isInfinite) {
        return storedMode == 'serving' ? '1' : '100';
      }
      if (amount % 1 == 0) return amount.toInt().toString();
      return amount.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }

    final amountController = TextEditingController(
      text: hasReliableStoredAmount
          ? formatAmount(storedAmount)
          : (storedMode == 'serving' ? '1' : '100'),
    );
    FoodItem? matchedFood;
    bool hasServingData = false;
    bool useServingMode = storedMode == 'serving';
    bool resolvingFood = true;
    bool lookupStarted = false;
    bool modeInitialized = storedMode != null;
    bool amountTouched = hasReliableStoredAmount;
    String lastAmountInput = amountController.text;

    double inferAmountFromMacros(FoodItem food, bool servingMode) {
      // Legacy entries may not have measure_amount saved. Infer the amount by
      // finding the quantity whose resolved macros best match the entry.
      final double start = servingMode ? 0.1 : 1.0;
      final double end = servingMode ? 20.0 : 2000.0;
      final double step = servingMode ? 0.1 : 1.0;
      double bestAmount = servingMode ? 1.0 : 100.0;
      int bestScore = 1 << 30;

      for (double amount = start; amount <= end; amount += step) {
        final macros = _resolveFoodMacros(food, amount, servingMode);
        final score =
            (macros['protein']! - entryProtein).abs() +
            (macros['carbs']! - entryCarbs).abs() +
            (macros['fat']! - entryFat).abs();
        if (score < bestScore) {
          bestScore = score;
          bestAmount = amount;
          if (score == 0) break;
        }
      }

      return bestAmount;
    }

    void updateMacroFromFood() {
      if (matchedFood == null) return;
      final rawAmount = amountController.text.replaceAll(',', '.');
      final amount =
          double.tryParse(rawAmount) ?? (useServingMode ? 1.0 : 100.0);
      final macros = _resolveFoodMacros(matchedFood!, amount, useServingMode);
      pController.text = macros['protein']!.toString();
      cController.text = macros['carbs']!.toString();
      fController.text = macros['fat']!.toString();
    }

    bool prefersServingMode(FoodItem food) {
      if (!_hasServingData(food)) return false;

      final entryProtein = (entry['protein'] as num?)?.toDouble() ?? 0.0;
      final entryCarbs = (entry['carbs'] as num?)?.toDouble() ?? 0.0;
      final entryFat = (entry['fat'] as num?)?.toDouble() ?? 0.0;

      final servingMacros = _resolveFoodMacros(food, 1.0, true);
      final gramMacros = _resolveFoodMacros(food, 100.0, false);

      double score(Map<String, int> macros) {
        return (macros['protein']!.toDouble() - entryProtein).abs() +
            (macros['carbs']!.toDouble() - entryCarbs).abs() +
            (macros['fat']!.toDouble() - entryFat).abs();
      }

      return score(servingMacros) <= score(gramMacros);
    }

    void applyResolvedFood(FoodItem? food) {
      matchedFood = food;
      hasServingData = food != null && _hasServingData(food);
      resolvingFood = false;

      if (!modeInitialized) {
        useServingMode = food != null && prefersServingMode(food);
        if (!amountTouched && food != null) {
          final inferred = inferAmountFromMacros(food, useServingMode);
          amountController.text = formatAmount(inferred);
          lastAmountInput = amountController.text;
        } else if (!amountTouched) {
          amountController.text = useServingMode ? '1' : '100';
          lastAmountInput = amountController.text;
        }
        modeInitialized = true;
      }

      updateMacroFromFood();
    }

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            if (!lookupStarted) {
              lookupStarted = true;
              _findMatchingFoodItem(
                oldName,
                entryProtein: entryProtein,
                entryCarbs: entryCarbs,
                entryFat: entryFat,
                entryMode: storedMode,
                measureAmount: storedAmount,
                includeOnlineSearch: false,
              ).then((resolved) {
                if (!ctx.mounted) return;
                setState(() {
                  applyResolvedFood(resolved);
                });
              });
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF1C1C1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'EDIT ENTRY',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: Colors.blueAccent,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(hintText: 'Entry Name'),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Edit by',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Per Serving'),
                          selected: useServingMode,
                          onSelected: (hasServingData || resolvingFood)
                              ? (selected) {
                                  setState(() {
                                    modeInitialized = true;
                                    amountTouched = false;
                                    useServingMode = true;
                                    amountController.text = matchedFood != null
                                        ? formatAmount(
                                            inferAmountFromMacros(matchedFood!, true),
                                          )
                                        : '1';
                                    lastAmountInput = amountController.text;
                                    updateMacroFromFood();
                                  });
                                }
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Grams'),
                          selected: !useServingMode,
                          onSelected: (selected) {
                            setState(() {
                              modeInitialized = true;
                              amountTouched = false;
                              useServingMode = false;
                              amountController.text = matchedFood != null
                                  ? formatAmount(
                                      inferAmountFromMacros(matchedFood!, false),
                                    )
                                  : '100';
                              lastAmountInput = amountController.text;
                              updateMacroFromFood();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      hintText: useServingMode
                          ? 'Number of servings'
                          : 'Amount in grams',
                      labelText: useServingMode ? 'Per Serving' : 'Grams',
                      suffixText: useServingMode ? null : 'g',
                    ),
                    onChanged: (value) {
                      if (value == lastAmountInput) return;
                      lastAmountInput = value;
                      amountTouched = true;
                      // Controller updates repaint these fields without needing
                      // a full dialog rebuild on every keystroke.
                      updateMacroFromFood();
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _calculationBasisText(matchedFood, useServingMode),
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (resolvingFood)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Loading serving match...',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    )
                  else if (!hasServingData)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Per serving unavailable for this entry. Use grams.',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: pController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: _macroInputFormatters,
                          decoration: const InputDecoration(
                            hintText: 'P',
                            labelText: 'P',
                            labelStyle: TextStyle(color: Colors.blueAccent),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: cController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: _macroInputFormatters,
                          decoration: const InputDecoration(
                            hintText: 'C',
                            labelText: 'C',
                            labelStyle: TextStyle(color: Colors.greenAccent),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: fController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: _macroInputFormatters,
                          decoration: const InputDecoration(
                            hintText: 'F',
                            labelText: 'F',
                            labelStyle: TextStyle(color: Colors.amberAccent),
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
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(ctx);
                    HapticFeedback.selectionClick();
                    try {
                      final rawAmount = amountController.text.replaceAll(',', '.');
                      final amount =
                          double.tryParse(rawAmount) ?? (useServingMode ? 1.0 : 100.0);
                      await DatabaseHelper.instance.updateDailyEntry(
                        entry['id'] as int,
                        nameController.text.isNotEmpty
                            ? nameController.text
                            : 'Manual Entry',
                        _parseMacroInput(pController.text),
                        _parseMacroInput(cController.text),
                        _parseMacroInput(fController.text),
                        entryMode: useServingMode ? 'serving' : 'grams',
                        measureAmount: amount,
                      );
                      if (!mounted) return;
                      await _loadSavedData();
                    } catch (e) {
                      if (!mounted) return;
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            'Failed to update entry: ${e.toString()}',
                          ),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
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
        );
      },
    );
  }

  Future<void> _deleteEntry(int id) async {
    try {
      await DatabaseHelper.instance.deleteDailyEntry(id);
      HapticFeedback.lightImpact();
      await _loadSavedData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete entry: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

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
      // For liquids in OFF data, approximate 1 ml ~= 1 g to enable serving mode.
      return value;
    }
    return value;
  }

  Map<String, int> _scaleMacros(
    int p100,
    int c100,
    int f100,
    double multiplier,
  ) {
    return {
      'protein': (p100 * multiplier).round(),
      'carbs': (c100 * multiplier).round(),
      'fat': (f100 * multiplier).round(),
    };
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
        return _scaleMacros(p100, c100, f100, servingWeight * quantity / 100.0);
      }
      // Unknown serving info fallback: treat one serving as 100g.
      return _scaleMacros(p100, c100, f100, quantity);
    }

    return _scaleMacros(p100, c100, f100, quantity / 100.0);
  }

  int _resolveFoodCalories(
    FoodItem item,
    double quantity,
    bool useServing,
    Map<String, int> macros,
  ) {
    final caloriesPer100 = item.caloriesPer100g;
    if (caloriesPer100 > 0) {
      if (useServing) {
        final servingWeight = _parseServingGramWeight(item.servingSize);
        if (servingWeight > 0) {
          return (caloriesPer100 * servingWeight * quantity / 100.0).round();
        }
        // Unknown serving weight fallback: 1 serving = 100g.
        return (caloriesPer100 * quantity).round();
      }
      return (caloriesPer100 * quantity / 100.0).round();
    }

    return (macros['protein']! * 4) +
        (macros['carbs']! * 4) +
        (macros['fat']! * 9);
  }

  bool _hasServingData(FoodItem item) {
    final servingWeight = _parseServingGramWeight(item.servingSize);
    return servingWeight > 0 ||
        (item.servingProtein ?? 0) > 0 ||
        (item.servingCarbs ?? 0) > 0 ||
        (item.servingFat ?? 0) > 0;
  }

  String _calculationBasisText(FoodItem? item, bool useServingMode) {
    if (!useServingMode) {
      return 'Calculation basis: per 100g values.';
    }
    if (item == null) {
      return 'Calculation basis: resolving serving data...';
    }

    final pServing = item.servingProtein ?? 0;
    final cServing = item.servingCarbs ?? 0;
    final fServing = item.servingFat ?? 0;
    if (pServing > 0 || cServing > 0 || fServing > 0) {
      return 'Calculation basis: per serving macros from source data.';
    }

    final servingWeight = _parseServingGramWeight(item.servingSize);
    if (servingWeight > 0) {
      final gramsText = servingWeight % 1 == 0
          ? servingWeight.toInt().toString()
          : servingWeight.toStringAsFixed(1);
      return 'Calculation basis: $gramsText g serving converted from per 100g.';
    }

    return 'Calculation basis: 1 serving treated as 100g (no serving metadata).';
  }

  Future<FoodItem?> _findMatchingFoodItem(
    String name, {
    int? entryProtein,
    int? entryCarbs,
    int? entryFat,
    String? entryMode,
    double? measureAmount,
    bool includeOnlineSearch = true,
  }) async {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    final dbCandidates = await FoodRepository.instance.searchLocalFoods(name);
    if (dbCandidates.isNotEmpty) {
      final exactDb = dbCandidates
          .where((food) => _prepareLookupName(food.name) == _prepareLookupName(name))
          .toList();
      if (exactDb.isNotEmpty) {
        return _pickBestMacroMatch(
          exactDb,
          entryProtein,
          entryCarbs,
          entryFat,
          entryMode: entryMode,
          measureAmount: measureAmount,
        );
      }
      return _pickBestMacroMatch(
        dbCandidates,
        entryProtein,
        entryCarbs,
        entryFat,
        entryMode: entryMode,
        measureAmount: measureAmount,
      );
    }

    final localFoods = await FoodRepository.instance.loadLocalFoods();
    final beverages = await FoodRepository.instance.loadBeverages();
    final fastFood = await FoodRepository.instance.loadFastFood();
    final foods = [...localFoods, ...beverages, ...fastFood];

    final normalizedQuery = _prepareLookupName(name);
    final localExact = foods
        .where((food) => _prepareLookupName(food.name) == normalizedQuery)
        .toList();
    if (localExact.isNotEmpty) {
      return _pickBestMacroMatch(
        localExact,
        entryProtein,
        entryCarbs,
        entryFat,
        entryMode: entryMode,
        measureAmount: measureAmount,
      );
    }

    final localFuzzy = foods.where((food) {
      final candidate = _prepareLookupName(food.name);
      return candidate.contains(normalizedQuery) ||
          normalizedQuery.contains(candidate);
    }).toList();
    if (localFuzzy.isNotEmpty) {
      return _pickBestMacroMatch(
        localFuzzy,
        entryProtein,
        entryCarbs,
        entryFat,
        entryMode: entryMode,
        measureAmount: measureAmount,
      );
    }

    if (!includeOnlineSearch) return null;

    final region = await FoodRepository.instance.getCurrentRegion();
    final onlineMatches = await FoodRepository.instance.searchOpenFoodFactsFoods(
      name,
      regionCode: region,
    );

    if (onlineMatches.isEmpty) return null;

    final onlineExact = onlineMatches
        .where((candidate) => _prepareLookupName(candidate.name) == normalizedQuery)
        .toList();
    if (onlineExact.isNotEmpty) {
      return _pickBestMacroMatch(
        onlineExact,
        entryProtein,
        entryCarbs,
        entryFat,
        entryMode: entryMode,
        measureAmount: measureAmount,
      );
    }

    final onlineFuzzy = onlineMatches.where((candidate) {
      final lookup = _prepareLookupName(candidate.name);
      return lookup.contains(normalizedQuery) ||
          normalizedQuery.contains(lookup);
    }).toList();
    if (onlineFuzzy.isNotEmpty) {
      return _pickBestMacroMatch(
        onlineFuzzy,
        entryProtein,
        entryCarbs,
        entryFat,
        entryMode: entryMode,
        measureAmount: measureAmount,
      );
    }

    return null;
  }

  FoodItem _pickBestMacroMatch(
    List<FoodItem> candidates,
    int? entryProtein,
    int? entryCarbs,
    int? entryFat,
    {
    String? entryMode,
    double? measureAmount,
  }
  ) {
    if (entryProtein == null || entryCarbs == null || entryFat == null) {
      return candidates.first;
    }

    final mode = (entryMode ?? 'grams').toLowerCase();
    final useServing = mode == 'serving';
    final amount = (measureAmount != null && measureAmount > 0)
        ? measureAmount
        : (useServing ? 1.0 : 100.0);

    candidates.sort((a, b) {
      final da = _macroDistance(
        entryProtein,
        entryCarbs,
        entryFat,
        a,
        amount,
        useServing,
      );
      final db = _macroDistance(
        entryProtein,
        entryCarbs,
        entryFat,
        b,
        amount,
        useServing,
      );
      return da.compareTo(db);
    });
    return candidates.first;
  }

  int _macroDistance(
    int entryProtein,
    int entryCarbs,
    int entryFat,
    FoodItem food,
    double amount,
    bool useServing,
  ) {
    final resolved = _resolveFoodMacros(food, amount, useServing);
    return (entryProtein - (resolved['protein'] ?? 0)).abs() +
        (entryCarbs - (resolved['carbs'] ?? 0)).abs() +
        (entryFat - (resolved['fat'] ?? 0)).abs();
  }

  String _prepareLookupName(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'\([^\)]*\)'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> _showFoodPortionDialog(FoodItem item) async {
    final quantityController = TextEditingController();
    final servingWeight = _parseServingGramWeight(item.servingSize);
    final pServing = item.servingProtein ?? 0;
    final cServing = item.servingCarbs ?? 0;
    final fServing = item.servingFat ?? 0;
    final hasServingData =
      (servingWeight > 0.0) || pServing > 0 || cServing > 0 || fServing > 0;
    bool useServing = hasServingData;
    quantityController.text = useServing ? '1' : '100';

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111113),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          top: false,
          bottom: true,
          child: StatefulBuilder(
            builder: (context, setState) {
              final servingSize = item.servingSize;
              return Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 24,
                  bottom:
                      MediaQuery.of(ctx).viewInsets.bottom +
                      MediaQuery.of(ctx).viewPadding.bottom +
                      24,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (servingSize != null)
                        Text(
                          'Serving size: $servingSize',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      if (!hasServingData)
                        const Text(
                          'Per serving is unavailable for this food. Use grams.',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      if (servingSize != null) const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Add by',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ChoiceChip(
                                  label: const Text('Per Serving'),
                                  selected: useServing,
                                  onSelected: hasServingData
                                      ? (selected) {
                                          setState(() {
                                            useServing = true;
                                            quantityController.text = '1';
                                          });
                                        }
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ChoiceChip(
                                  label: const Text('Grams'),
                                  selected: !useServing,
                                  onSelected: (selected) {
                                    setState(() {
                                      useServing = false;
                                      quantityController.text = '100';
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                      TextField(
                        controller: quantityController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          hintText: useServing
                              ? 'Number of servings'
                              : 'Amount in grams',
                          labelText: useServing ? 'Per Serving' : 'Grams',
                          suffixText: useServing ? null : 'g',
                          suffixStyle: const TextStyle(color: Colors.white70),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _calculationBasisText(item, useServing),
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final rawQuantity = quantityController.text
                              .replaceAll(',', '.');
                          final quantity =
                              double.tryParse(rawQuantity) ??
                              (useServing ? 1.0 : 100.0);
                          final selection = _resolveFoodMacros(
                            item,
                            quantity,
                            useServing,
                          );
                          final calories = _resolveFoodCalories(
                            item,
                            quantity,
                            useServing,
                            selection,
                          );
                          Navigator.pop(ctx);
                          await _addEntry(
                            item.name,
                            selection['protein']!,
                            selection['carbs']!,
                            selection['fat']!,
                            entryMode: useServing ? 'serving' : 'grams',
                            measureAmount: quantity,
                            caloriesOverride: calories,
                          );
                        },
                        child: const Text(
                          'Apply',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.blueAccent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final rawQuantity = quantityController.text
                              .replaceAll(',', '.');
                          final quantity =
                              double.tryParse(rawQuantity) ??
                              (useServing ? 1.0 : 100.0);
                          final macros = _resolveFoodMacros(
                            item,
                            quantity,
                            useServing,
                          );
                          final servingLabel = useServing
                              ? '${quantity % 1 == 0 ? quantity.toInt() : quantity} serving${quantity == 1.0 ? '' : 's'}'
                              : '${quantity % 1 == 0 ? quantity.toInt() : quantity}g';
                          final displayName = '${item.name} ($servingLabel)';
                          final servingGrams = _parseServingGramWeight(
                            item.servingSize,
                          );
                          Navigator.pop(ctx);
                          await _saveFoodAsCustom(
                            displayName,
                            macros['protein']!,
                            macros['carbs']!,
                            macros['fat']!,
                            measureMode: useServing ? 'serving' : 'grams',
                            measureAmount: quantity,
                            servingGrams: servingGrams > 0
                                ? servingGrams
                                : null,
                          );
                        },
                        child: const Text('Add to custom foods'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
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
      builder: (_) => FoodSearchSheet(onScanBarcode: _openBarcodeScanner),
    );

    if (selectedItem != null) {
      _showFoodPortionDialog(selectedItem);
    }
  }

  Future<void> _openBarcodeScanner() async {
    // Request camera permission before opening scanner to avoid native null crash
    final status = await Permission.camera.request();
    if (!mounted) return;

    if (status.isPermanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Camera permission permanently denied. Enable it in Settings.',
          ),
          backgroundColor: Colors.redAccent,
          action: SnackBarAction(
            label: 'SETTINGS',
            textColor: Colors.white,
            onPressed: openAppSettings,
          ),
        ),
      );
      return;
    }

    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera permission is required to scan barcodes.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );

    if (barcode == null || barcode.isEmpty) return;

    try {
      final item = await FoodRepository.instance.fetchOpenFoodFactsBarcode(
        barcode,
      );
      if (item == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product not found or missing macro data.'),
          ),
        );
        return;
      }
      _showFoodPortionDialog(item);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Barcode scan failed: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _saveFoodAsCustom(
    String name,
    int protein,
    int carbs,
    int fat,
    {
    String measureMode = 'grams',
    double measureAmount = 100.0,
    double? servingGrams,
  }
  ) async {
    try {
      await DatabaseHelper.instance.insertCustomFood(
        name,
        protein,
        carbs,
        fat,
        measureMode: measureMode,
        measureAmount: measureAmount,
        servingGrams: servingGrams,
      );
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('$name added to custom meals')),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      HapticFeedback.lightImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save food: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _showStatsMenu() async {
    List<Map<String, dynamic>> weeklyData = [];
    final now = DateTime.now();
    int totalP = 0, totalCal = 0;
    int validDays = 0;

    for (int i = 6; i >= 0; i--) {
      DateTime checkDate = now.subtract(Duration(days: i));
      String key = _getDateKey(checkDate);
      final totals = await DatabaseHelper.instance.getDailyTotals(key);

      int cal = totals['calories'] ?? 0;
      int pro = totals['protein'] ?? 0;

      if (cal > 0) {
        totalCal += cal;
        totalP += pro;
        validDays++;
      }

      String weekday = [
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat',
        'Sun',
      ][checkDate.weekday - 1];
      weeklyData.add({'day': weekday, 'cal': cal, 'pro': pro});
    }

    int div = validDays > 0 ? validDays : 1;
    int avgP = (totalP / div).round();
    int avgCal = (totalCal / div).round();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.only(
            left: 32.0,
            right: 32.0,
            top: 32.0,
            bottom: 48.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '7-DAY TREND',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: Colors.blueAccent,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: (calorieTarget * 1.3).toDouble(),
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, m) => Text(
                            weeklyData[v.toInt()]['day'],
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: weeklyData.asMap().entries.map((e) {
                      int calories = e.value['cal'];
                      Color barColor = calories == 0
                          ? Colors.white.withValues(alpha: 0.1)
                          : (calories > calorieTarget
                                ? Colors.redAccent
                                : Colors.greenAccent);
                      return BarChartGroupData(
                        x: e.key,
                        barRods: [
                          BarChartRodData(
                            toY: calories.toDouble(),
                            color: barColor,
                            width: 16,
                            borderRadius: BorderRadius.circular(4),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: calorieTarget.toDouble(),
                              color: Colors.white.withValues(alpha: 0.02),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _statColumn('AVG KCAL', '$avgCal', Colors.white),
                  _statColumn('AVG PRO', '${avgP}g', Colors.blueAccent),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveWeightForSelectedDate(double enteredWeight, String unit) async {
    if (enteredWeight <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid weight.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('weight_unit', unit);

      final weightKg = _convertUnitToKg(enteredWeight, unit);
      final selectedDayIso = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        12,
      ).toIso8601String();

      await DatabaseHelper.instance.upsertWeightLog(
        _getDateKey(_selectedDate),
        weightKg,
        createdAt: selectedDayIso,
      );

      HapticFeedback.selectionClick();
      await _loadSavedData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save weight: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _showWeightLogSheet() async {
    String selectedUnit = _weightUnit;
    final initialKg = _weightForSelectedDateKg ?? _latestWeightKg;
    final controller = TextEditingController(
      text: initialKg == null
          ? ''
          : _convertKgToUnit(initialKg, selectedUnit).toStringAsFixed(1),
    );

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111113),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 24,
                  bottom:
                      MediaQuery.of(ctx).viewInsets.bottom +
                      MediaQuery.of(ctx).viewPadding.bottom +
                      24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Log Weight',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _getDisplayDate(_selectedDate),
                      style: const TextStyle(color: Colors.white54),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('kg'),
                          selected: selectedUnit == 'kg',
                          onSelected: (_) {
                            final parsed = double.tryParse(
                              controller.text.replaceAll(',', '.'),
                            );
                            if (parsed != null) {
                              final kgValue = _convertUnitToKg(parsed, selectedUnit);
                              controller.text = _convertKgToUnit(
                                kgValue,
                                'kg',
                              ).toStringAsFixed(1);
                            }
                            setModalState(() => selectedUnit = 'kg');
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('lb'),
                          selected: selectedUnit == 'lb',
                          onSelected: (_) {
                            final parsed = double.tryParse(
                              controller.text.replaceAll(',', '.'),
                            );
                            if (parsed != null) {
                              final kgValue = _convertUnitToKg(parsed, selectedUnit);
                              controller.text = _convertKgToUnit(
                                kgValue,
                                'lb',
                              ).toStringAsFixed(1);
                            }
                            setModalState(() => selectedUnit = 'lb');
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Weight ($selectedUnit)',
                        hintText: selectedUnit == 'kg' ? '82.5' : '181.9',
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        final parsed = double.tryParse(
                          controller.text.replaceAll(',', '.'),
                        );
                        if (parsed == null || parsed <= 0) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Enter a valid weight value.'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        await _saveWeightForSelectedDate(parsed, selectedUnit);
                      },
                      child: const Text(
                        'Save Weight',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showWeightHistorySheet();
                      },
                      child: const Text('View History'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showWeightHistorySheet() async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        _WeightRange selectedRange = _WeightRange.threeMonths;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final end = DateTime(
              _selectedDate.year,
              _selectedDate.month,
              _selectedDate.day,
              23,
              59,
              59,
            );
            final start = end.subtract(Duration(days: _rangeDays(selectedRange) - 1));

            return FutureBuilder<List<Map<String, dynamic>>>(
              future: DatabaseHelper.instance.getWeightHistoryInRange(start, end),
              builder: (context, snapshot) {
                final rows = snapshot.data ?? const [];
                final points = <FlSpot>[];
                final dates = <DateTime>[];
                for (int i = 0; i < rows.length; i++) {
                  final row = rows[i];
                  final kg = (row['weight_kg'] as num?)?.toDouble();
                  final parsedDate = _parseIsoDate(row['created_at']);
                  if (kg == null || parsedDate == null) continue;
                  points.add(
                    FlSpot(i.toDouble(), _convertKgToUnit(kg, _weightUnit)),
                  );
                  dates.add(parsedDate);
                }

                final hasData = points.isNotEmpty;
                final firstY = hasData ? points.first.y : 0.0;
                final lastY = hasData ? points.last.y : 0.0;
                final delta = hasData ? lastY - firstY : 0.0;

                double minY = 0;
                double maxY = 1;
                if (hasData) {
                  minY = points.map((p) => p.y).reduce((a, b) => a < b ? a : b);
                  maxY = points.map((p) => p.y).reduce((a, b) => a > b ? a : b);
                  if ((maxY - minY).abs() < 1.0) {
                    minY -= 0.8;
                    maxY += 0.8;
                  } else {
                    minY -= 0.6;
                    maxY += 0.6;
                  }
                }

                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Weight History',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: _WeightRange.values.map((range) {
                          return ChoiceChip(
                            label: Text(_rangeLabel(range)),
                            selected: selectedRange == range,
                            onSelected: (_) {
                              setModalState(() => selectedRange = range);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                      if (!snapshot.hasData)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (!hasData)
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: const Text(
                            'No weight entries in this range yet. Log your weight to start tracking trends.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      else ...[
                        SizedBox(
                          height: 210,
                          child: LineChart(
                            LineChartData(
                              minY: minY,
                              maxY: maxY,
                              gridData: FlGridData(
                                show: true,
                                horizontalInterval: ((maxY - minY) / 4).abs(),
                                verticalInterval: 1,
                                getDrawingHorizontalLine: (_) => FlLine(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  strokeWidth: 1,
                                ),
                                getDrawingVerticalLine: (_) => FlLine(
                                  color: Colors.transparent,
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: points,
                                  isCurved: points.length > 2,
                                  color: Colors.blueAccent,
                                  barWidth: 3,
                                  dotData: FlDotData(show: true),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: Colors.blueAccent.withValues(alpha: 0.14),
                                  ),
                                ),
                              ],
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    reservedSize: 44,
                                    showTitles: true,
                                    getTitlesWidget: (value, _) => Text(
                                      value.toStringAsFixed(1),
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: points.length > 6
                                        ? (points.length / 4).ceilToDouble()
                                        : 1,
                                    getTitlesWidget: (value, _) {
                                      final index = value.toInt();
                                      if (index < 0 || index >= dates.length) {
                                        return const SizedBox.shrink();
                                      }
                                      return Text(
                                        _formatCompactDate(dates[index]),
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 9,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _statColumn(
                              'START',
                              firstY.toStringAsFixed(1),
                              Colors.white,
                            ),
                            _statColumn(
                              'CURRENT',
                              lastY.toStringAsFixed(1),
                              Colors.blueAccent,
                            ),
                            _statColumn(
                              'CHANGE',
                              '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}',
                              delta <= 0 ? Colors.greenAccent : Colors.redAccent,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            'Unit: $_weightUnit',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _handleTopBarAction(_TopBarAction action) async {
    switch (action) {
      case _TopBarAction.reset:
        await _confirmResetTotals();
        break;
      case _TopBarAction.help:
        await SupportActions.showSupportFeedbackSheet(context);
        break;
      case _TopBarAction.about:
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AboutScreen()),
        );
        break;
      case _TopBarAction.share:
        await SupportActions.shareApp();
        break;
      case _TopBarAction.stats:
        await _showStatsMenu();
        break;
      case _TopBarAction.weightHistory:
        await _showWeightHistorySheet();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    double calProgress = calorieTarget > 0
        ? currentCalories / calorieTarget
        : 0.0;
    final quickMealsHeight = _favoriteMeals.isEmpty ? 128.0 : 110.0;
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
      appBar: AppBar(
        title: const Text(
          'BAREMACROS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          style: SupportActions.appBarActionButtonStyle(),
          icon: const Icon(Icons.tune_rounded),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
            FocusManager.instance.primaryFocus?.unfocus();
            _loadSavedData();
          },
        ),
        actions: [
          PopupMenuButton<_TopBarAction>(
            tooltip: 'More actions',
            icon: const Icon(Icons.more_horiz_rounded),
            iconColor: SupportActions.mutedColor,
            color: const Color(0xFF1A1A1D),
            onSelected: _handleTopBarAction,
            itemBuilder: (context) => [
              PopupMenuItem<_TopBarAction>(
                value: _TopBarAction.stats,
                child: _actionMenuRow(
                  icon: Icons.stacked_bar_chart_rounded,
                  iconColor: Colors.blueAccent,
                  label: 'Weekly stats',
                ),
              ),
              PopupMenuItem<_TopBarAction>(
                value: _TopBarAction.weightHistory,
                child: _actionMenuRow(
                  icon: Icons.monitor_weight_rounded,
                  iconColor: Colors.amberAccent,
                  label: 'Weight history',
                ),
              ),
              PopupMenuItem<_TopBarAction>(
                value: _TopBarAction.about,
                child: _actionMenuRow(
                  icon: Icons.info_outline_rounded,
                  iconColor: Colors.tealAccent,
                  label: 'About BareMacros',
                ),
              ),
              PopupMenuItem<_TopBarAction>(
                value: _TopBarAction.help,
                child: _actionMenuRow(
                  icon: Icons.help_outline_rounded,
                  iconColor: Colors.lightBlueAccent,
                  label: 'Help & feedback',
                ),
              ),
              PopupMenuItem<_TopBarAction>(
                value: _TopBarAction.share,
                child: _actionMenuRow(
                  icon: Icons.share_outlined,
                  iconColor: Colors.greenAccent,
                  label: 'Share BareMacros',
                ),
              ),
              PopupMenuItem<_TopBarAction>(
                value: _TopBarAction.reset,
                child: _actionMenuRow(
                  icon: Icons.delete_forever_rounded,
                  iconColor: Colors.redAccent,
                  label: 'Reset day entries',
                  textColor: Colors.redAccent,
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openSearchFoodDialog,
        backgroundColor: Colors.blueAccent,
        icon: const Icon(Icons.search_rounded),
        label: const Text(
          'Search',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: 100,
          ),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.chevron_left_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () => _changeDate(-1),
                ),
                const SizedBox(width: 12),
                Text(
                  _getDisplayDate(_selectedDate),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () => _changeDate(1),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: SizedBox(
                height: 220,
                width: 220,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: calProgress.clamp(0.0, 1.0),
                      strokeWidth: 12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        calProgress > 1.0
                            ? Colors.redAccent
                            : Colors.blueAccent,
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$currentCalories',
                          style: const TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'OF $calorieTarget',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_remainingCalories()} kcal remaining',
                          style: TextStyle(
                            fontSize: 12,
                            color: currentCalories > calorieTarget
                                ? Colors.redAccent
                                : Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: _showWeightLogSheet,
                          onLongPress: _showWeightHistorySheet,
                          child: Text(
                            _weightSummaryText(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: _weightForSelectedDateKg != null
                                  ? Colors.white70
                                  : Colors.white38,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            Row(
              children: [
                Expanded(
                  child: _macroCard(
                    'PROTEIN',
                    protein,
                    proteinTarget,
                    Colors.blueAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _macroCard(
                    'CARBS',
                    carbs,
                    carbsTarget,
                    Colors.greenAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _macroCard('FAT', fat, fatTarget, Colors.amberAccent),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _quickAddButton(
                    label: '+ 30g Pro',
                    color: Colors.blueAccent,
                    onPressed: () => _addOrMergeQuickEntry(
                      'Quick Protein',
                      30,
                      0,
                      0,
                      amount: 30,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _quickAddButton(
                    label: '+ 30g Carb',
                    color: Colors.greenAccent,
                    onPressed: () => _addOrMergeQuickEntry(
                      'Quick Carbs',
                      0,
                      30,
                      0,
                      amount: 30,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _quickAddButton(
                    label: '+ 15g Fat',
                    color: Colors.amberAccent,
                    onPressed: () => _addOrMergeQuickEntry(
                      'Quick Fat',
                      0,
                      0,
                      15,
                      amount: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(child: _inputField(_pController, 'P')),
                const SizedBox(width: 8),
                Expanded(child: _inputField(_cController, 'C')),
                const SizedBox(width: 8),
                Expanded(child: _inputField(_fController, 'F')),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Type macros and press Enter to add',
              style: TextStyle(color: Colors.white54, fontSize: 11),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Quick Meals',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: Colors.white,
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blueAccent,
                  ),
                  onPressed: widget.onManageMeals,
                  child: const Text('Manage'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap ⭐ on a meal to pin it here',
              style: TextStyle(color: Colors.white30, fontSize: 11),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: quickMealsHeight,
              child: _favoriteMeals.isEmpty
                  ? GestureDetector(
                      onTap: widget.onManageMeals,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.star_outline_rounded,
                              color: Colors.white24,
                              size: 28,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'No pinned meals yet',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap here to go to Meals, then tap ⭐ to pin',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.3),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _favoriteMeals.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 12),
                      itemBuilder: (ctx, index) {
                        final meal = _favoriteMeals[index];
                        final measureMode =
                            (meal['measure_mode'] as String?)?.toLowerCase();
                        final name = meal['name'] as String;
                        final inferredServing = RegExp(
                          r'\bservings?\b',
                          caseSensitive: false,
                        ).hasMatch(name);
                        final entryMode = (measureMode == 'serving')
                            ? 'serving'
                            : (measureMode == 'grams')
                            ? 'grams'
                            : (inferredServing ? 'serving' : 'grams');
                        return GestureDetector(
                          onTap: () => _addEntry(
                            name,
                            meal['protein'] as int,
                            meal['carbs'] as int,
                            meal['fat'] as int,
                            entryMode: entryMode,
                            measureAmount:
                                (meal['measure_amount'] as num?)?.toDouble(),
                          ),
                          child: Container(
                            width: 220,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.07),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  meal['name'] as String,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'P ${meal['protein']} • C ${meal['carbs']} • F ${meal['fat']}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                const Spacer(),
                                Row(
                                  children: const [
                                    Icon(
                                      Icons.add_circle,
                                      color: Colors.blueAccent,
                                      size: 18,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Tap to log',
                                      style: TextStyle(
                                        color: Colors.blueAccent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 24),
            if (_entries.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Today\'s Entries',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Tap to edit  •  Swipe to delete',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _entries.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (ctx, index) {
                  final entry = _entries[index];
                  return Dismissible(
                    key: Key(entry['id'].toString()),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(18),
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
                            'Delete entry?',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          content: Text(
                            'Remove "${entry['name']}"?',
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
                    onDismissed: (direction) {
                      _deleteEntry(entry['id'] as int);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        title: Builder(
                          builder: (_) {
                            final measureLabel = _entryMeasureLabel(entry);
                            return Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    entry['name'] as String? ?? 'Entry',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (measureLabel != null)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blueAccent.withValues(
                                        alpha: 0.16,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: Colors.blueAccent.withValues(
                                          alpha: 0.35,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      measureLabel,
                                      style: const TextStyle(
                                        color: Colors.blueAccent,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        subtitle: Text.rich(
                          TextSpan(
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            children: [
                              const TextSpan(
                                text: 'P: ',
                                style: TextStyle(color: Colors.blueAccent),
                              ),
                              TextSpan(
                                text: '${entry['protein']}g',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              const TextSpan(
                                text: '  •  ',
                                style: TextStyle(color: Colors.white70),
                              ),
                              const TextSpan(
                                text: 'C: ',
                                style: TextStyle(color: Colors.greenAccent),
                              ),
                              TextSpan(
                                text: '${entry['carbs']}g',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              const TextSpan(
                                text: '  •  ',
                                style: TextStyle(color: Colors.white70),
                              ),
                              const TextSpan(
                                text: 'F: ',
                                style: TextStyle(color: Colors.amberAccent),
                              ),
                              TextSpan(
                                text: '${entry['fat']}g',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              const TextSpan(
                                text: '  •  ',
                                style: TextStyle(color: Colors.white70),
                              ),
                              TextSpan(
                                text: '${entry['calories']} kcal',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        onTap: () => _editEntry(entry),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
          ),
        ),
      ),
    );
  }

  Widget _statColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white38,
          ),
        ),
      ],
    );
  }

  int _remainingCalories() =>
      (calorieTarget - currentCalories).clamp(0, calorieTarget);

  String? _entryMeasureLabel(Map<String, dynamic> entry) {
    final name = (entry['name'] as String? ?? '').toLowerCase();
    if (RegExp(r'\([^)]*(g|servings?)\)').hasMatch(name)) {
      return null;
    }

    final mode = (entry['entry_mode'] as String?)?.toLowerCase();
    final amountRaw = (entry['measure_amount'] as num?)?.toDouble();
    if (amountRaw == null || amountRaw <= 0) return null;

    final hasExplicitServingInName =
      RegExp(r'\b\d+(?:[.,]\d+)?\s*servings?\b').hasMatch(name);
    final isLegacyServingPlaceholder =
      mode == 'serving' &&
      (amountRaw - 100.0).abs() < 0.0001 &&
      !hasExplicitServingInName;
    if (isLegacyServingPlaceholder) return null;

    final amountText = amountRaw % 1 == 0
        ? amountRaw.toInt().toString()
        : amountRaw
              .toStringAsFixed(2)
              .replaceFirst(RegExp(r'0+$'), '')
              .replaceFirst(RegExp(r'\.$'), '');

    if (mode == 'serving') {
      final suffix = amountRaw == 1.0 ? 'serving' : 'servings';
      return '$amountText $suffix';
    }

    return '$amountText g';
  }

  @override
  void dispose() {
    _pController.dispose();
    _cController.dispose();
    _fController.dispose();
    super.dispose();
  }

  Widget _macroCard(String label, int current, int target, Color color) {
    double progress = target > 0 ? current / target : 0.0;
    bool isOver = progress > 1.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOver
              ? Colors.redAccent.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isOver ? Colors.redAccent : color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '$current/$target g',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
                maxLines: 1,
                overflow: TextOverflow.visible,
              ),
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: Colors.black26,
            valueColor: AlwaysStoppedAnimation<Color>(
              isOver ? Colors.redAccent : color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickAddButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        splashColor: color.withValues(alpha: 0.2),
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputField(TextEditingController controller, String label) {
    final labelColor = label == 'P'
        ? Colors.blueAccent
        : label == 'C'
        ? Colors.greenAccent
        : label == 'F'
        ? Colors.amberAccent
        : Colors.white;

    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: _macroInputFormatters,
      textAlign: TextAlign.center,
      style: const TextStyle(fontWeight: FontWeight.bold),
      textInputAction: TextInputAction.done,
      onSubmitted: (_) {
        FocusScope.of(context).unfocus();
        if (_pController.text.trim().isNotEmpty ||
            _cController.text.trim().isNotEmpty ||
            _fController.text.trim().isNotEmpty) {
          _addEntry(
            'Manual Entry',
            _parseMacroInput(_pController.text),
            _parseMacroInput(_cController.text),
            _parseMacroInput(_fController.text),
          );
        }
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: labelColor, fontWeight: FontWeight.bold),
        hintText: label,
        hintStyle: TextStyle(
          color: labelColor.withValues(alpha: 0.35),
          fontSize: 13,
        ),
      ),
    );
  }
}
