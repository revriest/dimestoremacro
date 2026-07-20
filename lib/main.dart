import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'food_repository.dart';
import 'screens/dashboard_screen.dart';
import 'screens/food_library_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BareMacros',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent, brightness: Brightness.dark),
        inputDecorationTheme: InputDecorationTheme(
          filled: true, fillColor: Colors.white.withValues(alpha: 0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
      ),
      home: const AppEntryGate(),
    );
  }
}

class AppEntryGate extends StatefulWidget {
  const AppEntryGate({super.key});

  @override
  State<AppEntryGate> createState() => _AppEntryGateState();
}

class _AppEntryGateState extends State<AppEntryGate> {
  static const String _kSeenOnboarding = 'has_seen_onboarding';
  static const String _kConfirmedRegion = 'has_confirmed_region';
  static const String _kSeenLaunchGoalPrompt = 'has_seen_launch_goal_prompt';

  bool _isInitializing = true;
  bool _showOnboarding = false;
  bool _regionPromptScheduled = false;
  int _mainScreenRevision = 0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final seenOnboarding = prefs.getBool(_kSeenOnboarding) ?? false;

    if (!mounted) return;
    setState(() {
      _showOnboarding = !seenOnboarding;
      _isInitializing = false;
    });

    if (!seenOnboarding) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runFirstLaunchPrompts();
    });
  }

  Future<void> _handleOnboardingFinished() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSeenOnboarding, true);

    if (!mounted) return;
    setState(() => _showOnboarding = false);
    await _runFirstLaunchPrompts();
  }

  Future<void> _runFirstLaunchPrompts() async {
    await _showRegionConfirmationIfNeeded();
    await _showLaunchGoalPromptIfNeeded();
  }

  Future<void> _showRegionConfirmationIfNeeded() async {
    if (_regionPromptScheduled) return;
    _regionPromptScheduled = true;

    final prefs = await SharedPreferences.getInstance();
    final hasConfirmedRegion = prefs.getBool(_kConfirmedRegion) ?? false;
    if (hasConfirmedRegion) return;

    final regionCode = await FoodRepository.instance.getCurrentRegion();
    final regionName = _regionDisplayName(regionCode);

    if (!mounted) return;
    await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Is $regionName the correct region for you?',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: const Text(
            'This affects local food suggestions. You can change your region anytime from the top-right settings menu, and download your region database later for faster offline search.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No, I will change it in Settings'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              child: const Text('Yes, Continue'),
            ),
          ],
        );
      },
    );

    await prefs.setBool(_kConfirmedRegion, true);
  }

  Future<void> _showLaunchGoalPromptIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenPrompt = prefs.getBool(_kSeenLaunchGoalPrompt) ?? false;
    if (hasSeenPrompt) return;
    if (!mounted) return;

    final shouldOpenSettings = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Quick Start',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: const Text(
            'Nutrition values can contain inaccuracies and BareMacros is not medical advice.\n\nSet your goal now (cutting, maintenance, bulking) with the TDEE calculator, or do it later in Settings. Inside Settings, tap Calculate suggested targets, then Save Changes to apply them.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Later'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Set goal now'),
            ),
          ],
        );
      },
    );

    await prefs.setBool(_kSeenLaunchGoalPrompt, true);

    if (shouldOpenSettings == true && mounted) {
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );

      if (saved == true && mounted) {
        setState(() => _mainScreenRevision++);
      }
    }
  }

  String _regionDisplayName(String code) {
    final region = FoodRepository.supportedRegions.firstWhere(
      (item) => item['code'] == code,
      orElse: () => {'code': code, 'name': code},
    );
    final fullName = region['name'] ?? code;
    final splitIndex = fullName.indexOf(' ');
    return splitIndex > 0 ? fullName.substring(splitIndex + 1) : fullName;
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_showOnboarding) {
      return OnboardingScreen(onFinish: _handleOnboardingFinished);
    }

    return MainScreen(key: ValueKey(_mainScreenRevision));
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return PopScope<bool>(
      canPop: _currentIndex != 1,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentIndex == 1) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            final offsetAnimation = Tween<Offset>(
              begin: Offset(_currentIndex == 1 ? 1.0 : -1.0, 0),
              end: Offset.zero,
            ).animate(animation);
            return SlideTransition(
              position: offsetAnimation,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: _currentIndex == 0
            ? DashboardScreen(key: const ValueKey('dashboard'), onManageMeals: () => setState(() => _currentIndex = 1))
            : const FoodLibraryScreen(key: ValueKey('meals')),
        ),
        bottomNavigationBar: NavigationBar(
          backgroundColor: const Color(0xFF0D0D0F),
          indicatorColor: Colors.blueAccent.withValues(alpha: 0.3),
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) => setState(() => _currentIndex = index),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Track'),
            NavigationDestination(icon: Icon(Icons.restaurant_menu_rounded), label: 'Meals'),
          ],
        ),
      ),
    );
  }
}

