import 'package:flutter/material.dart';

import 'screens/dashboard_screen.dart';
import 'screens/food_library_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dime Store Macro',
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
      home: const MainScreen(),
    );
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

