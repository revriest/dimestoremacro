import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../food_repository.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _pTargetController = TextEditingController();
  final _cTargetController = TextEditingController();
  final _fTargetController = TextEditingController();
  final _calTargetController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  String _sex = 'Male';
  String _activity = 'Moderate';
  String _goal = 'Maintenance';
  String _intensity = 'Moderate';

  int? _estimatedTdee;
  int? _suggestedCalories;
  int? _suggestedProtein;
  int? _suggestedCarbs;
  int? _suggestedFat;

  @override
  void initState() {
    super.initState();
    _loadCurrentTargets();
  }

  Future<void> _loadCurrentTargets() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pTargetController.text = (prefs.getInt('target_protein') ?? 180).toString();
      _cTargetController.text = (prefs.getInt('target_carbs') ?? 200).toString();
      _fTargetController.text = (prefs.getInt('target_fat') ?? 70).toString();
      _calTargetController.text = (prefs.getInt('target_calories') ?? 2150).toString();
      _ageController.text = (prefs.getInt('profile_age') ?? 30).toString();
      _heightController.text = (prefs.getInt('profile_height') ?? 175).toString();
      _weightController.text = (prefs.getInt('profile_weight') ?? 75).toString();
      _sex = prefs.getString('profile_sex') ?? 'Male';
      _activity = prefs.getString('profile_activity') ?? 'Moderate';
      _goal = prefs.getString('profile_goal') ?? 'Maintenance';
      _intensity = prefs.getString('profile_intensity') ?? 'Moderate';
    });
  }

  Future<void> _showRegionPicker() async {
    final currentRegion = await FoodRepository.instance.getCurrentRegion();
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('SELECT REGION', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.blueAccent)),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text('Affects which local foods appear in search results.', style: TextStyle(color: Colors.white54, fontSize: 12), textAlign: TextAlign.center),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: FoodRepository.supportedRegions.length,
                itemBuilder: (_, index) {
                  final region = FoodRepository.supportedRegions[index];
                  final isSelected = region['code'] == currentRegion;
                  return ListTile(
                    title: Text(region['name']!, style: TextStyle(color: isSelected ? Colors.blueAccent : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Colors.blueAccent) : null,
                    onTap: () async {
                      await FoodRepository.instance.setRegion(region['code']!);
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      if (!mounted) return;
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Region set to ${region['name']}'),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _saveTargets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('target_protein', int.tryParse(_pTargetController.text) ?? 180);
    await prefs.setInt('target_carbs', int.tryParse(_cTargetController.text) ?? 200);
    await prefs.setInt('target_fat', int.tryParse(_fTargetController.text) ?? 70);
    await prefs.setInt('target_calories', int.tryParse(_calTargetController.text) ?? 2150);
    await prefs.setInt('profile_age', int.tryParse(_ageController.text) ?? 30);
    await prefs.setInt('profile_height', int.tryParse(_heightController.text) ?? 175);
    await prefs.setInt('profile_weight', int.tryParse(_weightController.text) ?? 75);
    await prefs.setString('profile_sex', _sex);
    await prefs.setString('profile_activity', _activity);
    await prefs.setString('profile_goal', _goal);
    await prefs.setString('profile_intensity', _intensity);
    if (!mounted) return;
    Navigator.pop(context);
  }

  double _activityMultiplier(String activity) {
    switch (activity) {
      case 'Sedentary':
        return 1.2;
      case 'Lightly active':
        return 1.375;
      case 'Moderate':
        return 1.55;
      case 'Active':
        return 1.725;
      case 'Very active':
        return 1.9;
      default:
        return 1.55;
    }
  }

  int _goalCalorieAdjustment(String goal, String intensity) {
    if (goal == 'Cutting') {
      switch (intensity) {
        case 'Aggressive':
          return -700;
        case 'Moderate':
          return -500;
        case 'Conservative':
          return -300;
        default:
          return -500;
      }
    }

    if (goal == 'Bulking') {
      switch (intensity) {
        case 'Aggressive':
          return 500;
        case 'Moderate':
          return 300;
        case 'Conservative':
          return 150;
        default:
          return 300;
      }
    }

    return 0;
  }

  double _proteinPerKg(String goal, String intensity) {
    if (goal == 'Cutting') {
      switch (intensity) {
        case 'Aggressive':
          return 2.3;
        case 'Moderate':
          return 2.2;
        case 'Conservative':
          return 2.0;
        default:
          return 2.2;
      }
    }

    if (goal == 'Bulking') {
      switch (intensity) {
        case 'Aggressive':
          return 1.9;
        case 'Moderate':
          return 1.8;
        case 'Conservative':
          return 1.7;
        default:
          return 1.8;
      }
    }

    return 2.0;
  }

  double _fatPercent(String goal, String intensity) {
    if (goal == 'Cutting') {
      switch (intensity) {
        case 'Aggressive':
          return 0.18;
        case 'Moderate':
          return 0.22;
        case 'Conservative':
          return 0.24;
        default:
          return 0.22;
      }
    }

    if (goal == 'Bulking') {
      switch (intensity) {
        case 'Aggressive':
          return 0.30;
        case 'Moderate':
          return 0.28;
        case 'Conservative':
          return 0.25;
        default:
          return 0.28;
      }
    }

    return 0.25;
  }

  Future<void> _calculateTargets() async {
    final age = int.tryParse(_ageController.text) ?? 30;
    final height = int.tryParse(_heightController.text) ?? 175;
    final weight = int.tryParse(_weightController.text) ?? 75;
    final bmr = _sex == 'Female'
        ? (10 * weight) + (6.25 * height) - (5 * age) - 161
        : (10 * weight) + (6.25 * height) - (5 * age) + 5;
    final tdee = (bmr * _activityMultiplier(_activity)).round();
    final goalCalories = (tdee + _goalCalorieAdjustment(_goal, _intensity)).clamp(1200, 9999);
    final protein = (weight * _proteinPerKg(_goal, _intensity)).round();
    final proteinCalories = protein * 4;
    final fatCalories = (goalCalories * _fatPercent(_goal, _intensity)).round();
    final fat = (fatCalories / 9).round();
    final carbsCalories = (goalCalories - proteinCalories - fatCalories).clamp(0, goalCalories);
    final carbs = (carbsCalories / 4).round();
    setState(() {
      _estimatedTdee = tdee;
      _suggestedCalories = goalCalories;
      _suggestedProtein = protein;
      _suggestedCarbs = carbs;
      _suggestedFat = fat;
      _calTargetController.text = goalCalories.toString();
      _pTargetController.text = protein.toString();
      _cTargetController.text = carbs.toString();
      _fTargetController.text = fat.toString();
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Suggested targets calculated and populated.')),
    );
  }

  Widget _dropdownField(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        border: const OutlineInputBorder(),
      ),
      dropdownColor: const Color(0xFF111113),
      style: const TextStyle(color: Colors.white),
      items: items
          .map((option) => DropdownMenuItem<String>(
                value: option,
                child: Text(option, style: const TextStyle(color: Colors.white)),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _summaryCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101113),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pTargetController.dispose();
    _cTargetController.dispose();
    _fTargetController.dispose();
    _calTargetController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Widget _settingInput(TextEditingController controller, String label, Color accentColor) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label, labelStyle: TextStyle(color: accentColor.withValues(alpha: 0.7)), border: const OutlineInputBorder()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
      appBar: AppBar(title: const Text('DAILY TARGETS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2)), centerTitle: true, backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Target calculator', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.blueAccent)),
              const SizedBox(height: 8),
              const Text('Estimate daily calories and macros from your profile, then adjust the targets manually.', style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _settingInput(_ageController, 'Age', Colors.white)),
                  const SizedBox(width: 12),
                  Expanded(child: _settingInput(_heightController, 'Height (cm)', Colors.white)),
                  const SizedBox(width: 12),
                  Expanded(child: _settingInput(_weightController, 'Weight (kg)', Colors.white)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _dropdownField('Sex', _sex, const ['Male', 'Female'], (value) {
                      if (value == null) return;
                      setState(() => _sex = value);
                    }),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dropdownField(
                      'Activity level',
                      _activity,
                      const ['Sedentary', 'Lightly active', 'Moderate', 'Active', 'Very active'],
                      (value) {
                        if (value == null) return;
                        setState(() => _activity = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _dropdownField(
                'Goal',
                _goal,
                const ['Cutting', 'Maintenance', 'Bulking'],
                (value) {
                  if (value == null) return;
                  setState(() => _goal = value);
                },
              ),
              if (_goal != 'Maintenance') ...[
                const SizedBox(height: 16),
                _dropdownField(
                  'Intensity',
                  _intensity,
                  const ['Aggressive', 'Moderate', 'Conservative'],
                  (value) {
                    if (value == null) return;
                    setState(() => _intensity = value);
                  },
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: _calculateTargets,
                child: const Text('Calculate suggested targets', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
              if (_suggestedCalories != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: const Color(0xFF111113), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Suggested targets', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      if (_estimatedTdee != null) ...[
                        Text('Estimated TDEE: $_estimatedTdee kcal', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          Expanded(child: _summaryCard('Calories', '$_suggestedCalories kcal', Colors.white)),
                          const SizedBox(width: 12),
                          Expanded(child: _summaryCard('Protein', '$_suggestedProtein g', Colors.blueAccent)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _summaryCard('Carbs', '$_suggestedCarbs g', Colors.greenAccent)),
                          const SizedBox(width: 12),
                          Expanded(child: _summaryCard('Fat', '$_suggestedFat g', Colors.amberAccent)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              const Divider(color: Colors.white12),
              const SizedBox(height: 8),
              const Text('Food database', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.blueAccent)),
              const SizedBox(height: 12),
              FutureBuilder<String>(
                future: FoodRepository.instance.getCurrentRegion(),
                builder: (context, snapshot) {
                  final regionName = FoodRepository.supportedRegions
                      .firstWhere(
                        (r) => r['code'] == (snapshot.data ?? 'GENERIC'),
                        orElse: () => {'code': 'GENERIC', 'name': '\u1f30d International (generic)'},
                      )['name']!;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.public_rounded, color: Colors.blueAccent),
                    title: const Text('Region', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    subtitle: Text(snapshot.hasData ? regionName : 'Detecting...', style: const TextStyle(color: Colors.white54)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                    onTap: _showRegionPicker,
                  );
                },
              ),
              const SizedBox(height: 8),
              const Divider(color: Colors.white12),
              const SizedBox(height: 20),
              const Text('Set your daily nutrition thresholds:', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              _settingInput(_pTargetController, 'Protein Target (g)', Colors.blueAccent),
              const SizedBox(height: 16),
              _settingInput(_cTargetController, 'Carbs Target (g)', Colors.greenAccent),
              const SizedBox(height: 16),
              _settingInput(_fTargetController, 'Fat Target (g)', Colors.amberAccent),
              const SizedBox(height: 16),
              _settingInput(_calTargetController, 'Total Calories Target (kcal)', Colors.white),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: _saveTargets,
                child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
