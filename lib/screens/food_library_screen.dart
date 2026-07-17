import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../database_helper.dart';
import '../food_repository.dart';
import '../models/food_item.dart';
import 'barcode_scanner_screen.dart';
import '../widgets/food_search_sheet.dart';
import '../widgets/support_actions.dart';

class FoodLibraryScreen extends StatefulWidget {
  const FoodLibraryScreen({super.key});
  @override
  State<FoodLibraryScreen> createState() => _FoodLibraryScreenState();
}

class _FoodLibraryScreenState extends State<FoodLibraryScreen> {
  List<Map<String, dynamic>> _foods = [];
  final List<TextInputFormatter> _macroInputFormatters = [
    LengthLimitingTextInputFormatter(7),
    TextInputFormatter.withFunction((oldValue, newValue) {
      final next = newValue.text;
      if (next.isEmpty) return newValue;
      final ok = RegExp(r'^\d{0,4}([.,]\d{0,1})?$').hasMatch(next);
      return ok ? newValue : oldValue;
    }),
  ];

  int _parseMacroInput(String raw) {
    final parsed = double.tryParse(raw.trim().replaceAll(',', '.'));
    if (parsed == null || parsed < 0) return 0;
    return parsed.round();
  }

  double? _parseServingGrams(String? servingSize) {
    if (servingSize == null || servingSize.trim().isEmpty) return null;
    final match = RegExp(
      r'([\d,.]+)\s*(g|gram|grams)',
      caseSensitive: false,
    ).firstMatch(servingSize);
    if (match == null) return null;
    final value = double.tryParse(match.group(1)!.replaceAll(',', '.'));
    if (value == null || value <= 0) return null;
    return value;
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

  Future<void> _showAddMealChooser() async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'New Meal',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                _creationOptionTile(
                  icon: Icons.search_rounded,
                  iconColor: Colors.blueAccent,
                  title: 'Search existing foods',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _showFoodSearchForMeal();
                  },
                ),
                const SizedBox(height: 8),
                _creationOptionTile(
                  icon: Icons.qr_code_scanner_rounded,
                  iconColor: Colors.greenAccent,
                  title: 'Scan barcode',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _scanFoodForMeal();
                  },
                ),
                const SizedBox(height: 8),
                _creationOptionTile(
                  icon: Icons.edit_rounded,
                  iconColor: Colors.amberAccent,
                  title: 'Manual entry',
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAddFoodDialog();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _creationOptionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: ListTile(
          leading: Icon(icon, color: iconColor),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white30),
        ),
      ),
    );
  }

  Future<void> _showFoodSearchForMeal() async {
    final selectedItem = await showModalBottomSheet<FoodItem>(
      context: context,
      backgroundColor: const Color(0xFF111113),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (_) => FoodSearchSheet(onScanBarcode: _scanFoodForMeal),
    );

    if (selectedItem != null) {
      await _showAddFoodDialog(sourceFood: selectedItem);
    }
  }

  Future<void> _scanFoodForMeal() async {
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
      await _showAddFoodDialog(sourceFood: item);
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

  Future<void> _showAddFoodDialog({FoodItem? sourceFood}) {
    final nameCtrl = TextEditingController();
    final quantityCtrl = TextEditingController(text: '100');
    final pCtrl = TextEditingController();
    final cCtrl = TextEditingController();
    final fCtrl = TextEditingController();
    final servingGrams = _parseServingGrams(sourceFood?.servingSize);

    bool hasServingData() {
      if (sourceFood == null) return false;
      return (sourceFood.servingProtein ?? 0) > 0 ||
          (sourceFood.servingCarbs ?? 0) > 0 ||
          (sourceFood.servingFat ?? 0) > 0 ||
          (servingGrams != null && servingGrams > 0);
    }

    bool useServing = hasServingData();
    quantityCtrl.text = useServing ? '1' : '100';

    void updateMacrosFromSource() {
      if (sourceFood == null) return;
      final parsedQuantity =
          double.tryParse(quantityCtrl.text.replaceAll(',', '.'));
      final quantity =
          parsedQuantity ?? (useServing ? 1.0 : 100.0);

      int p;
      int c;
      int f;

      if (useServing) {
        final pServing = sourceFood.servingProtein ?? 0;
        final cServing = sourceFood.servingCarbs ?? 0;
        final fServing = sourceFood.servingFat ?? 0;
        if (pServing > 0 || cServing > 0 || fServing > 0) {
          p = (pServing * quantity).round();
          c = (cServing * quantity).round();
          f = (fServing * quantity).round();
        } else if (servingGrams != null && servingGrams > 0) {
          final multiplier = (servingGrams * quantity) / 100.0;
          p = (sourceFood.proteinPer100g * multiplier).round();
          c = (sourceFood.carbsPer100g * multiplier).round();
          f = (sourceFood.fatPer100g * multiplier).round();
        } else {
          p = (sourceFood.proteinPer100g * quantity).round();
          c = (sourceFood.carbsPer100g * quantity).round();
          f = (sourceFood.fatPer100g * quantity).round();
        }
      } else {
        final multiplier = quantity / 100.0;
        p = (sourceFood.proteinPer100g * multiplier).round();
        c = (sourceFood.carbsPer100g * multiplier).round();
        f = (sourceFood.fatPer100g * multiplier).round();
      }

      pCtrl.text = p.toString();
      cCtrl.text = c.toString();
      fCtrl.text = f.toString();
    }

    if (sourceFood != null) {
      nameCtrl.text = sourceFood.name;
      if (!useServing && servingGrams != null) {
        quantityCtrl.text = servingGrams.toStringAsFixed(
          servingGrams % 1 == 0 ? 0 : 1,
        );
      }
      updateMacrosFromSource();
    }

    final parentContext = context;
    return showDialog(
      context: parentContext,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final String quantity = quantityCtrl.text.trim().isEmpty
            ? (useServing ? '1' : '100')
            : quantityCtrl.text.trim();
          final String macroLabel = useServing
            ? 'per serving'
            : 'per ${quantity}g';
          final String nameHint = useServing
            ? 'e.g., Protein Shake (1 serving)'
            : 'e.g., Chicken Breast';

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
                        label: const Text('Per Serving'),
                        selected: useServing,
                        onSelected: hasServingData()
                            ? (_) => setDialogState(() {
                                useServing = true;
                                quantityCtrl.text = '1';
                                updateMacrosFromSource();
                              })
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Grams'),
                        selected: !useServing,
                        onSelected: (_) => setDialogState(() {
                          useServing = false;
                          if (quantityCtrl.text.trim().isEmpty) {
                            quantityCtrl.text = '100';
                          }
                          updateMacrosFromSource();
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  useServing
                      ? 'For prepared meals (smoothie, casserole, etc.)'
                      : 'For raw ingredients (chicken, rice, etc.)',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: quantityCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setDialogState(() {
                    updateMacrosFromSource();
                  }),
                  decoration: InputDecoration(
                    labelText: useServing ? 'Per Serving' : 'Grams',
                    hintText: useServing ? '1' : '100',
                    suffixText: useServing ? null : 'g',
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: pCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: _macroInputFormatters,
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
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: _macroInputFormatters,
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
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: _macroInputFormatters,
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
                    final parsedQuantity = double.tryParse(
                      quantityCtrl.text.replaceAll(',', '.'),
                    );
                    final quantity =
                        parsedQuantity ?? (useServing ? 1.0 : 100.0);
                    final servingGrams = _parseServingGrams(sourceFood?.servingSize);
                    final String fullName = useServing
                        ? baseName
                        : '$baseName (${quantity % 1 == 0 ? quantity.toInt() : quantity}g)';
                    Navigator.pop(ctx);
                    await DatabaseHelper.instance.insertCustomFood(
                      fullName,
                      _parseMacroInput(pCtrl.text),
                      _parseMacroInput(cCtrl.text),
                      _parseMacroInput(fCtrl.text),
                      measureMode: useServing ? 'serving' : 'grams',
                      measureAmount: quantity,
                      servingGrams: servingGrams,
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
    final pCtrl = TextEditingController(text: originalP.toString());
    final cCtrl = TextEditingController(text: originalC.toString());
    final fCtrl = TextEditingController(text: originalF.toString());
    final storedMode = (food['measure_mode'] as String?)?.toLowerCase();
    final storedAmount = (food['measure_amount'] as num?)?.toDouble();
    final storedServingGrams = (food['serving_grams'] as num?)?.toDouble();
    final servingCountMatch = RegExp(
      r'\((\d+(?:\.\d+)?)\s*serving',
      caseSensitive: false,
    ).firstMatch(originalName);
    final inferredServingAmount = servingCountMatch == null
        ? 1.0
        : (double.tryParse(servingCountMatch.group(1) ?? '') ?? 1.0);
    final nameLooksServing = RegExp(
      r'\bservings?\b',
      caseSensitive: false,
    ).hasMatch(originalName);

    final originalMode = (storedMode == 'serving')
        ? 'serving'
        : (storedMode == 'grams')
        ? ((parsedGrams == null && nameLooksServing) ? 'serving' : 'grams')
        : ((parsedGrams != null || gramMatch != null) ? 'grams' : 'serving');
    final originalAmount = storedAmount ??
        (originalMode == 'grams'
            ? (parsedGrams ?? 100.0)
            : inferredServingAmount);
    final servingGrams = (storedServingGrams != null && storedServingGrams > 0)
        ? storedServingGrams
        : null;
    final servingGramsCtrl = TextEditingController(
      text: servingGrams == null
        ? ''
        : servingGrams.toStringAsFixed(servingGrams % 1 == 0 ? 0 : 1),
    );

    bool useCustomGrams = originalMode == 'grams';
    final amountCtrl = TextEditingController(
      text: useCustomGrams
          ? originalAmount.toStringAsFixed(originalAmount % 1 == 0 ? 0 : 1)
          : '1',
    );

    double parseAmount(String value, double fallback) {
      final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
      if (parsed == null || parsed <= 0) return fallback;
      return parsed;
    }

    double? parseServingGramsFromInput() {
      final parsed = double.tryParse(
        servingGramsCtrl.text.trim().replaceAll(',', '.'),
      );
      if (parsed == null || parsed <= 0) return servingGrams;
      return parsed;
    }

    void updateMacrosFromAmount() {
      final currentMode = useCustomGrams ? 'grams' : 'serving';
      final fallback = currentMode == 'grams' ? 100.0 : 1.0;
      final amount = parseAmount(amountCtrl.text, fallback);

      double multiplier;
      if (currentMode == originalMode) {
        multiplier = amount / originalAmount;
      } else if (currentMode == 'grams' && originalMode == 'serving') {
        final gramsPerServing = parseServingGramsFromInput() ?? 100.0;
        multiplier = amount / (gramsPerServing * originalAmount);
      } else {
        final gramsPerServing = parseServingGramsFromInput() ?? originalAmount;
        multiplier = (amount * gramsPerServing) / originalAmount;
      }

      pCtrl.text = (originalP * multiplier).round().toString();
      cCtrl.text = (originalC * multiplier).round().toString();
      fCtrl.text = (originalF * multiplier).round().toString();
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final amountDisplay = amountCtrl.text.trim().isEmpty
              ? (useCustomGrams ? '100' : '1')
              : amountCtrl.text.trim();
          final macroLabel = useCustomGrams
            ? 'per ${amountDisplay}g'
            : 'per serving';
          final amountLabel = useCustomGrams ? 'Grams' : 'Per Serving';
          final amountSuffix = useCustomGrams ? 'g' : null;

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
                        label: const Text('Per Serving'),
                        selected: !useCustomGrams,
                        onSelected: (_) => setDialogState(() {
                          useCustomGrams = false;
                          amountCtrl.text = '1';
                          updateMacrosFromAmount();
                        }),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Grams'),
                        selected: useCustomGrams,
                        onSelected: (_) => setDialogState(() {
                          useCustomGrams = true;
                          final defaultGrams = servingGrams ??
                              (originalMode == 'grams' ? originalAmount : 100.0);
                          amountCtrl.text = defaultGrams.toStringAsFixed(
                            defaultGrams % 1 == 0 ? 0 : 1,
                          );
                          updateMacrosFromAmount();
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: amountLabel,
                    hintText: useCustomGrams ? '100' : '1',
                    suffixText: amountSuffix,
                  ),
                  onChanged: (_) => setDialogState(() {
                    updateMacrosFromAmount();
                  }),
                ),
                const SizedBox(height: 4),
                Text(
                  useCustomGrams
                      ? 'Macros scale automatically when grams change'
                      : 'Macros scale automatically when servings change',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                if (useCustomGrams && originalMode == 'serving') ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: servingGramsCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Grams per serving',
                      hintText: 'e.g. 27',
                      suffixText: 'g',
                    ),
                    onChanged: (_) => setDialogState(() {
                      updateMacrosFromAmount();
                    }),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: pCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: _macroInputFormatters,
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
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: _macroInputFormatters,
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
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: _macroInputFormatters,
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
                    final parsedAmount = double.tryParse(
                      amountCtrl.text.trim().replaceAll(',', '.'),
                    );
                    final savedAmount = (parsedAmount == null || parsedAmount <= 0)
                        ? (useCustomGrams ? 100.0 : 1.0)
                        : parsedAmount;
                    final fullName =
                        useCustomGrams
                      ? '$base (${amountCtrl.text.trim().isEmpty ? '100' : amountCtrl.text.trim()}g)'
                        : base;
                    Navigator.pop(ctx);
                    await DatabaseHelper.instance.updateCustomFood(
                      food['id'] as int,
                      fullName,
                      _parseMacroInput(pCtrl.text),
                      _parseMacroInput(cCtrl.text),
                      _parseMacroInput(fCtrl.text),
                      measureMode: useCustomGrams ? 'grams' : 'serving',
                      measureAmount: savedAmount,
                      servingGrams: parseServingGramsFromInput(),
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
                  final String mealName = food['name'] as String? ?? 'Custom Meal';
                  final bool usesGrams = RegExp(
                    r'\((\d+(?:\.\d+)?)g\)$',
                  ).hasMatch(mealName);
                  await DatabaseHelper.instance.insertDailyEntry(
                    key,
                    mealName,
                    p,
                    c,
                    f,
                    entryMode: usesGrams ? 'grams' : 'serving',
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
        onPressed: _showAddMealChooser,
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
