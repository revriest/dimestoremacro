import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';

import '../database_helper.dart';
import '../food_repository.dart';
import '../models/food_item.dart';
import 'settings_screen.dart';
import 'barcode_scanner_screen.dart';
import '../widgets/food_search_sheet.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onManageMeals;
  const DashboardScreen({super.key, required this.onManageMeals});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int currentCalories = 0, protein = 0, carbs = 0, fat = 0;
  int proteinTarget = 180, carbsTarget = 200, fatTarget = 70, calorieTarget = 2150;
  final _pController = TextEditingController();
  final _cController = TextEditingController();
  final _fController = TextEditingController();
  List<Map<String, dynamic>> _entries = [];
  List<Map<String, dynamic>> _favoriteMeals = [];

  DateTime _selectedDate = DateTime.now();

  String _getDateKey(DateTime date) => "${date.year}-${date.month}-${date.day}";
  String _getDisplayDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'TODAY';
    }
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return "${months[date.month - 1]} ${date.day}, ${date.year}";
  }

  void _changeDate(int days) {
    setState(() => _selectedDate = _selectedDate.add(Duration(days: days)));
    _loadSavedData();
  }

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    String activeKey = _getDateKey(_selectedDate);
    final totals = await DatabaseHelper.instance.getDailyTotals(activeKey);
    final entries = await DatabaseHelper.instance.getDailyEntries(activeKey);
    final favorites = await DatabaseHelper.instance.getAllCustomFoods();

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
    });
  }

  Future<void> _addEntry(String name, int p, int c, int f) async {
    String activeKey = _getDateKey(_selectedDate);
    await DatabaseHelper.instance.insertDailyEntry(activeKey, name, p, c, f);
    _pController.clear();
    _cController.clear();
    _fController.clear();
    await _loadSavedData();
  }

  Future<void> _resetTotals() async {
    String activeKey = _getDateKey(_selectedDate);
    await DatabaseHelper.instance.deleteEntriesForDate(activeKey);
    await _loadSavedData();
  }

  Future<void> _confirmResetTotals() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Delete all entries?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
          content: const Text('This will remove every entry for the currently selected day. Are you sure?', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
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
    final nameController = TextEditingController(text: entry['name'] as String? ?? '');
    final pController = TextEditingController(text: (entry['protein'] as num?)?.toInt().toString() ?? '0');
    final cController = TextEditingController(text: (entry['carbs'] as num?)?.toInt().toString() ?? '0');
    final fController = TextEditingController(text: (entry['fat'] as num?)?.toInt().toString() ?? '0');
    final oldName = entry['name'] as String? ?? '';
    final matchedFood = await _findMatchingFoodItem(oldName);
    final amountController = TextEditingController(text: '100');
    bool useServingMode = matchedFood != null && matchedFood.servingSize != null;

    void updateMacroFromFood() {
      if (matchedFood == null) return;
      final rawAmount = amountController.text.replaceAll(',', '.');
      final amount = double.tryParse(rawAmount) ?? (useServingMode ? 1.0 : 100.0);
      final macros = _resolveFoodMacros(matchedFood, amount, useServingMode);
      pController.text = macros['protein']!.toString();
      cController.text = macros['carbs']!.toString();
      fController.text = macros['fat']!.toString();
    }

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1C1C1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('EDIT ENTRY', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.blueAccent)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameController, decoration: const InputDecoration(hintText: 'Entry Name')),
                  const SizedBox(height: 12),
                  if (matchedFood != null) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Edit by', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Per Serving'),
                            selected: useServingMode,
                            onSelected: (selected) {
                              setState(() {
                                useServingMode = true;
                                if (matchedFood.servingSize != null) {
                                  amountController.text = '1';
                                }
                                updateMacroFromFood();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Grams'),
                            selected: !useServingMode,
                            onSelected: (selected) {
                              setState(() {
                                useServingMode = false;
                                amountController.text = '100';
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
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: useServingMode ? 'Number of servings' : 'Amount in grams',
                        labelText: useServingMode ? 'Per Serving' : 'Grams',
                        suffixText: useServingMode ? null : 'g',
                      ),
                      onChanged: (_) {
                        setState(updateMacroFromFood);
                      },
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    Text('Match not found. Edit macros directly.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 12),
                  ],
                  Row(children: [
                    Expanded(child: TextField(controller: pController, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'P', labelText: 'P', labelStyle: TextStyle(color: Colors.blueAccent)))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: cController, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'C', labelText: 'C', labelStyle: TextStyle(color: Colors.greenAccent)))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: fController, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'F', labelText: 'F', labelStyle: TextStyle(color: Colors.amberAccent)))),
                  ]),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await DatabaseHelper.instance.updateDailyEntry(
                      entry['id'] as int,
                      nameController.text.isNotEmpty ? nameController.text : 'Manual Entry',
                      int.tryParse(pController.text) ?? 0,
                      int.tryParse(cController.text) ?? 0,
                      int.tryParse(fController.text) ?? 0,
                    );
                    if (!mounted) return;
                    await _loadSavedData();
                  },
                  child: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteEntry(int id) async {
    await DatabaseHelper.instance.deleteDailyEntry(id);
    await _loadSavedData();
  }

  double _parseServingGramWeight(String? servingSize) {
    if (servingSize == null) return 0.0;
    final match = RegExp(r'([\d,.]+)\s*(g|gram|grams)')
        .firstMatch(servingSize.toLowerCase());
    if (match == null) return 0.0;
    return double.tryParse(match.group(1)!.replaceAll(',', '.')) ?? 0.0;
  }

  Map<String, int> _scaleMacros(int p100, int c100, int f100, double multiplier) {
    return {
      'protein': (p100 * multiplier).round(),
      'carbs': (c100 * multiplier).round(),
      'fat': (f100 * multiplier).round(),
    };
  }

  Map<String, int> _resolveFoodMacros(FoodItem item, double quantity, bool useServing) {
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
      return _scaleMacros(p100, c100, f100, quantity / 100.0);
    }

    return _scaleMacros(p100, c100, f100, quantity / 100.0);
  }

  Future<FoodItem?> _findMatchingFoodItem(String name) async {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    final foods = await FoodRepository.instance.loadLocalFoods();
    try {
      return foods.firstWhere((food) {
        final foodName = food.name.toLowerCase();
        return foodName == normalized || foodName.contains(normalized) || normalized.contains(foodName);
      });
    } catch (_) {
      return null;
    }
  }

  Future<void> _showFoodPortionDialog(FoodItem item) async {
    final quantityController = TextEditingController();
    final servingWeight = _parseServingGramWeight(item.servingSize);
    final pServing = item.servingProtein ?? 0;
    final cServing = item.servingCarbs ?? 0;
    final fServing = item.servingFat ?? 0;
    bool useServing = (servingWeight > 0.0) || pServing > 0 || cServing > 0 || fServing > 0;
    quantityController.text = useServing ? '1' : '100';

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111113),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).viewPadding.bottom + 24,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                      const SizedBox(height: 8),
                      if (servingSize != null)
                        Text('Serving size: $servingSize', style: const TextStyle(color: Colors.white70)),
                      if (servingSize != null) const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Add by', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ChoiceChip(
                                  label: const Text('Per Serving'),
                                  selected: useServing,
                                  onSelected: (selected) {
                                    setState(() {
                                      useServing = true;
                                      quantityController.text = '1';
                                    });
                                  },
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
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          hintText: useServing ? 'Number of servings' : 'Amount in grams',
                          labelText: useServing ? 'Per Serving' : 'Grams',
                          suffixText: useServing ? null : 'g',
                          suffixStyle: const TextStyle(color: Colors.white70),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: () async {
                          final rawQuantity = quantityController.text.replaceAll(',', '.');
                          final quantity = double.tryParse(rawQuantity) ?? (useServing ? 1.0 : 100.0);
                          final selection = _resolveFoodMacros(item, quantity, useServing);
                          Navigator.pop(ctx);
                          await _addEntry(item.name, selection['protein']!, selection['carbs']!, selection['fat']!);
                        },
                        child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.blueAccent),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          await _saveFoodAsCustom(item);
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (_) => FoodSearchSheet(onScanBarcode: _openBarcodeScanner),
    );

    if (selectedItem != null) {
      _showFoodPortionDialog(selectedItem);
    }
  }

  Future<void> _openBarcodeScanner() async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );

    if (barcode == null || barcode.isEmpty) return;

    final item = await FoodRepository.instance.fetchOpenFoodFactsBarcode(barcode);
    if (item == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product not found or missing macro data.')));
      return;
    }

    _showFoodPortionDialog(item);
  }

  Future<void> _saveFoodAsCustom(FoodItem item) async {
    await DatabaseHelper.instance.insertCustomFood(item.name, item.proteinPer100g, item.carbsPer100g, item.fatPer100g);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${item.name} added to custom foods.')));
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

      String weekday = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][checkDate.weekday - 1];
      weeklyData.add({'day': weekday, 'cal': cal, 'pro': pro});
    }

    int div = validDays > 0 ? validDays : 1;
    int avgP = (totalP / div).round();
    int avgCal = (totalCal / div).round();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1D),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.only(left: 32.0, right: 32.0, top: 32.0, bottom: 48.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('7-DAY TREND', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.blueAccent)),
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
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) => Text(weeklyData[v.toInt()]['day'], style: const TextStyle(fontSize: 10, color: Colors.grey)))),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: weeklyData.asMap().entries.map((e) {
                      int calories = e.value['cal'];
                      Color barColor = calories == 0 ? Colors.white.withValues(alpha: 0.1) : (calories > calorieTarget ? Colors.redAccent : Colors.greenAccent);
                      return BarChartGroupData(x: e.key, barRods: [BarChartRodData(toY: calories.toDouble(), color: barColor, width: 16, borderRadius: BorderRadius.circular(4), backDrawRodData: BackgroundBarChartRodData(show: true, toY: calorieTarget.toDouble(), color: Colors.white.withValues(alpha: 0.02)))]);
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

  @override
  Widget build(BuildContext context) {
    double calProgress = calorieTarget > 0 ? currentCalories / calorieTarget : 0.0;
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
      appBar: AppBar(
        title: const Text('DIME-STORE MACRO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2)),
        centerTitle: true, backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.tune_rounded, color: Colors.grey), onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())); _loadSavedData(); }),
        actions: [
          IconButton(icon: const Icon(Icons.search_rounded, color: Colors.white), onPressed: _openSearchFoodDialog),
          IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.grey), onPressed: _confirmResetTotals),
          IconButton(icon: const Icon(Icons.bar_chart_rounded, color: Colors.blueAccent), onPressed: _showStatsMenu),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
                  onPressed: () => _changeDate(-1),
                ),
                const SizedBox(width: 12),
                Text(_getDisplayDate(_selectedDate), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white)),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, color: Colors.white),
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
                      valueColor: AlwaysStoppedAnimation<Color>(calProgress > 1.0 ? Colors.redAccent : Colors.blueAccent),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$currentCalories', style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        Text('OF $calorieTarget', style: const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 8),
                        Text(
                          '${_remainingCalories()} kcal remaining',
                          style: TextStyle(
                            fontSize: 12,
                            color: currentCalories > calorieTarget ? Colors.redAccent : Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            Row(children: [Expanded(child: _macroCard('PROTEIN', protein, proteinTarget, Colors.blueAccent)), const SizedBox(width: 12), Expanded(child: _macroCard('CARBS', carbs, carbsTarget, Colors.greenAccent)), const SizedBox(width: 12), Expanded(child: _macroCard('FAT', fat, fatTarget, Colors.amberAccent))]),
            const SizedBox(height: 24),
            Row(children: [Expanded(child: ElevatedButton(onPressed: () => _addEntry('Quick Protein', 30, 0, 0), child: const Text('＋ 30g Pro'))), const SizedBox(width: 12), Expanded(child: ElevatedButton(onPressed: () => _addEntry('Quick Carbs', 0, 30, 0), child: const Text('＋ 30g Carb'))), const SizedBox(width: 12), Expanded(child: ElevatedButton(onPressed: () => _addEntry('Quick Fat', 0, 0, 15), child: const Text('＋ 15g Fat')))]),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(child: _inputField(_pController, 'P')),
                const SizedBox(width: 8),
                Expanded(child: _inputField(_cController, 'C')),
                const SizedBox(width: 8),
                Expanded(child: _inputField(_fController, 'F')),
                const SizedBox(width: 12),
                Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(16)),
                  child: IconButton(
                    icon: const Icon(Icons.add_rounded),
                    onPressed: () => _addEntry(
                      'Manual Entry',
                      int.tryParse(_pController.text) ?? 0,
                      int.tryParse(_cController.text) ?? 0,
                      int.tryParse(_fController.text) ?? 0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Quick Meals', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white)),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.blueAccent),
                  onPressed: widget.onManageMeals,
                  child: const Text('Manage'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: _favoriteMeals.isEmpty
                ? Center(child: Text('Add meals in the Meals tab to use quick inserts.', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _favoriteMeals.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 12),
                    itemBuilder: (ctx, index) {
                      final meal = _favoriteMeals[index];
                      return GestureDetector(
                        onTap: () => _addEntry(meal['name'] as String, meal['protein'] as int, meal['carbs'] as int, meal['fat'] as int),
                        child: Container(
                          width: 220,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.07))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(meal['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                              const SizedBox(height: 8),
                              Text('P ${meal['protein']} • C ${meal['carbs']} • F ${meal['fat']}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              const Spacer(),
                              Row(children: const [Icon(Icons.add_circle, color: Colors.blueAccent, size: 18), SizedBox(width: 6), Text('Tap to log', style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold))]),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            ),
            const SizedBox(height: 24),
            if (_entries.isNotEmpty) ...[
              const Text('Today\'s Entries', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white)),
              const SizedBox(height: 12),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _entries.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (ctx, index) {
                  final entry = _entries[index];
                  return Container(
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      title: Text(entry['name'] as String? ?? 'Entry', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text.rich(
                        TextSpan(
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                          children: [
                            const TextSpan(text: 'P: ', style: TextStyle(color: Colors.blueAccent)),
                            TextSpan(text: '${entry['protein']}g', style: const TextStyle(color: Colors.white70)),
                            const TextSpan(text: '  •  ', style: TextStyle(color: Colors.white70)),
                            const TextSpan(text: 'C: ', style: TextStyle(color: Colors.greenAccent)),
                            TextSpan(text: '${entry['carbs']}g', style: const TextStyle(color: Colors.white70)),
                            const TextSpan(text: '  •  ', style: TextStyle(color: Colors.white70)),
                            const TextSpan(text: 'F: ', style: TextStyle(color: Colors.amberAccent)),
                            TextSpan(text: '${entry['fat']}g', style: const TextStyle(color: Colors.white70)),
                            const TextSpan(text: '  •  ', style: TextStyle(color: Colors.white70)),
                            TextSpan(text: '${entry['calories']} kcal', style: const TextStyle(color: Colors.white70)),
                          ],
                        ),
                      ),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.edit_rounded, color: Colors.blueAccent), onPressed: () => _editEntry(entry)),
                        IconButton(icon: const Icon(Icons.delete_rounded, color: Colors.redAccent), onPressed: () => _deleteEntry(entry['id'] as int)),
                      ]),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statColumn(String label, String value, Color color) {
    return Column(children: [Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)), const SizedBox(height: 4), Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white38))]);
  }

  int _remainingCalories() => (calorieTarget - currentCalories).clamp(0, calorieTarget);

  @override
  void dispose() {
    _pController.dispose(); _cController.dispose(); _fController.dispose();
    super.dispose();
  }

  Widget _macroCard(String label, int current, int target, Color color) {
    double progress = target > 0 ? current / target : 0.0;
    bool isOver = progress > 1.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(20), border: Border.all(color: isOver ? Colors.redAccent.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: isOver ? Colors.redAccent : color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '$current/$target g',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                maxLines: 1,
                overflow: TextOverflow.visible,
              ),
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: progress.clamp(0.0, 1.0), minHeight: 6, backgroundColor: Colors.black26, valueColor: AlwaysStoppedAnimation<Color>(isOver ? Colors.redAccent : color)),
        ],
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
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: const TextStyle(fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: labelColor, fontWeight: FontWeight.bold),
        hintText: label,
        hintStyle: TextStyle(color: labelColor.withValues(alpha: 0.35), fontSize: 13),
      ),
    );
  }
}
