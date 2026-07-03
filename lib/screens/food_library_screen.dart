import 'package:flutter/material.dart';

import '../database_helper.dart';

class FoodLibraryScreen extends StatefulWidget {
  const FoodLibraryScreen({super.key});
  @override
  State<FoodLibraryScreen> createState() => _FoodLibraryScreenState();
}

class _FoodLibraryScreenState extends State<FoodLibraryScreen> {
  List<Map<String, dynamic>> _foods = [];

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
        await DatabaseHelper.instance.updateCustomFood(food['id'] as int, 'White Rice (100g)', 3, 28, 0);
        migrated = true;
      }
    }

    if (foods.isNotEmpty) {
      if (migrated) {
        final updatedFoods = await DatabaseHelper.instance.getAllCustomFoods();
        setState(() => _foods = updatedFoods);
      } else {
        setState(() => _foods = foods);
      }
    } else {
      await DatabaseHelper.instance.insertCustomFood("Chicken Breast (100g)", 31, 0, 3);
      await DatabaseHelper.instance.insertCustomFood("Egg Whites (100g)", 11, 1, 0);
      await DatabaseHelper.instance.insertCustomFood("White Rice (100g)", 3, 28, 0);

      final updatedFoods = await DatabaseHelper.instance.getAllCustomFoods();
      setState(() => _foods = updatedFoods);
    }
  }

  Future<void> _confirmDeleteCustomMeal(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Delete custom meal?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
          content: Text('Remove "$name" from your custom meals? This cannot be undone.', style: const TextStyle(color: Colors.white70)),
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
      await DatabaseHelper.instance.deleteCustomFood(id);
      if (!mounted) return;
      _loadFoods();
    }
  }

  void _showAddFoodDialog() {
    final nameCtrl = TextEditingController();
    final pCtrl = TextEditingController();
    final cCtrl = TextEditingController();
    final fCtrl = TextEditingController();

    final parentContext = context;
    showDialog(
      context: parentContext,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('ADD CUSTOM MEAL', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.blueAccent)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Meal Name')),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextField(controller: pCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'P (g)'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: cCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'C (g)'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: fCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'F (g)'))),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty) {
                Navigator.pop(ctx);
                await DatabaseHelper.instance.insertCustomFood(nameCtrl.text, int.tryParse(pCtrl.text) ?? 0, int.tryParse(cCtrl.text) ?? 0, int.tryParse(fCtrl.text) ?? 0);
                if (!mounted) return;
                _loadFoods();
              }
            },
            child: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('CUSTOM MEALS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2)),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.blueAccent,
        onPressed: _showAddFoodDialog,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New Meal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 100),
        itemCount: _foods.length,
        itemBuilder: (ctx, i) {
          final food = _foods[i];
          return Card(
            color: Colors.white.withValues(alpha: 0.03),
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
            elevation: 0,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              title: Text(food['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('P: ${food['protein']}g  •  C: ${food['carbs']}g  •  F: ${food['fat']}g',
                  style: const TextStyle(color: Colors.white70)
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.blueAccent, size: 32),
                    onPressed: () async {
                      int p = (food['protein'] as num? ?? 0).toInt();
                      int c = (food['carbs'] as num? ?? 0).toInt();
                      int f = (food['fat'] as num? ?? 0).toInt();
                      int cal = (p * 4) + (c * 4) + (f * 9);
                      DateTime n = DateTime.now();
                      String key = "${n.year}-${n.month}-${n.day}";
                      await DatabaseHelper.instance.insertDailyEntry(key, food['name'] as String? ?? 'Custom Meal', p, c, f);

                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Logged ${food['name']}! (+$cal kcal)'),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 28),
                    onPressed: () => _confirmDeleteCustomMeal(food['id'] as int, food['name'] as String? ?? 'Meal'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
