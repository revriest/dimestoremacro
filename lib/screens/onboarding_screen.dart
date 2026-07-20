import 'package:flutter/material.dart';

import '../food_repository.dart';

class OnboardingScreen extends StatefulWidget {
  final Future<void> Function() onFinish;

  const OnboardingScreen({super.key, required this.onFinish});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isCompleting = false;
  bool _isDownloadingRegionPack = false;

  static const List<_OnboardingData> _pages = [
    _OnboardingData(
      title: 'Welcome to BareMacros',
      subtitle: 'Track Your Macros Effortlessly',
      icon: Icons.waving_hand_rounded,
    ),
    _OnboardingData(
      title: 'Search 1000s of Foods',
      subtitle: 'Or Scan Barcodes',
      icon: Icons.qr_code_scanner_rounded,
    ),
    _OnboardingData(
      title: 'Set Daily Goals',
      subtitle: 'Track Your Progress',
      icon: Icons.track_changes_rounded,
    ),
    _OnboardingData(
      title: 'Optional region pack',
      subtitle: 'Improve local search and offline results. You can download it anytime later from Settings.',
      icon: Icons.cloud_download_rounded,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _nextOrFinish() async {
    if (_currentPage < _pages.length - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
      return;
    }

    if (_isCompleting) return;
    setState(() => _isCompleting = true);
    await widget.onFinish();
    if (!mounted) return;
    setState(() => _isCompleting = false);
  }

  Future<void> _downloadRegionPack() async {
    if (_isDownloadingRegionPack) return;
    setState(() => _isDownloadingRegionPack = true);

    try {
      final region = await FoodRepository.instance.getCurrentRegion();
      final result = await FoodRepository.instance.downloadRegionalDatabase(region);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isDownloadingRegionPack = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0A0B), Color(0xFF11131A), Color(0xFF0A0A0B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.45)),
                            ),
                            child: Icon(page.icon, size: 56, color: Colors.blueAccent),
                          ),
                          const SizedBox(height: 30),
                          Text(
                            page.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            page.subtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Row(
                  children: [
                    Row(
                      children: List.generate(
                        _pages.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsets.only(right: 8),
                          width: _currentPage == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? Colors.blueAccent
                                : Colors.white24,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _isCompleting ? null : widget.onFinish,
                      child: const Text('Skip'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isCompleting ? null : _nextOrFinish,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isCompleting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_currentPage == _pages.length - 1 ? 'Get Started' : 'Next'),
                    ),
                  ],
                ),
              ),
              if (_currentPage == _pages.length - 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Recommended for better local search and offline results. You can also do this later in Settings.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.35),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _isDownloadingRegionPack ? null : _downloadRegionPack,
                        icon: _isDownloadingRegionPack
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.cloud_download_rounded),
                        label: Text(
                          _isDownloadingRegionPack ? 'Downloading...' : 'Download region pack now',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.blueAccent),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingData {
  final String title;
  final String subtitle;
  final IconData icon;

  const _OnboardingData({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}
