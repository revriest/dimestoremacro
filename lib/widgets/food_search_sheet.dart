import 'dart:async';

import 'package:flutter/material.dart';

import '../food_repository.dart';
import '../models/food_item.dart';

class FoodSearchSheet extends StatefulWidget {
  final Future<void> Function() onScanBarcode;
  const FoodSearchSheet({super.key, required this.onScanBarcode});

  @override
  State<FoodSearchSheet> createState() => _FoodSearchSheetState();
}

class _FoodSearchSheetState extends State<FoodSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  int _searchToken = 0;
  bool _isSearching = false;
  String _resultSource = 'Local results';
  String _message = 'Type a food name to search local foods.';
  List<FoodItem> _results = [];

  bool get _canRetryOnline {
    final text = _message.toLowerCase();
    return text.contains('openfoodfacts') ||
        text.contains('temporarily') ||
        text.contains('failed');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchLocalFoods(String query) async {
    final token = ++_searchToken;
    final normalizedQuery = query.trim();
    if (!mounted) return;
    if (normalizedQuery.isEmpty) {
      setState(() {
        _results = [];
        _message = 'Type a food name to search local foods.';
        _resultSource = 'Local results';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _message = 'Searching local foods...';
    });

    try {
      final localMatches = await FoodRepository.instance.searchLocalFoods(query);
      if (!mounted || token != _searchToken) return;
      if (localMatches.isNotEmpty) {
        setState(() {
          _results = localMatches;
          _message = 'Found ${localMatches.length} local matches.';
          _resultSource = 'Local results';
          _isSearching = false;
        });
        return;
      }
      await _searchOpenFoodFactsFoods(query, token: token);
    } catch (e) {
      if (!mounted || token != _searchToken) return;
      setState(() {
        _isSearching = false;
        _message = 'Search failed: ${e.toString()}';
        _results = [];
      });
    }
  }

  Future<void> _searchOpenFoodFactsFoods(String query, {int? token}) async {
    final activeToken = token ?? ++_searchToken;
    final existingResults = List<FoodItem>.from(_results);
    if (!mounted) return;
    final region = await FoodRepository.instance.getCurrentRegion();
    if (!mounted || activeToken != _searchToken) return;
    setState(() {
      _isSearching = true;
      _message = 'No local match. Searching OpenFoodFacts for $region...';
      _resultSource = 'OpenFoodFacts fallback';
    });

    try {
      final onlineResults = await FoodRepository.instance.searchOpenFoodFactsFoods(
        query,
        regionCode: region,
      );
      if (!mounted || activeToken != _searchToken) return;
      setState(() {
        if (onlineResults.isEmpty && existingResults.isNotEmpty) {
          _results = existingResults;
          _message =
              'OpenFoodFacts is temporarily unavailable. Showing previous results.';
        } else {
          _results = onlineResults;
        }
        if (onlineResults.isEmpty && existingResults.isEmpty) {
          _message = 'No OpenFoodFacts results found for "$query" in $region.';
        } else if (onlineResults.isNotEmpty) {
          _message = 'Showing ${onlineResults.length} OpenFoodFacts results for $region.';
        }
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted || activeToken != _searchToken) return;
      setState(() {
        _isSearching = false;
        _message = existingResults.isEmpty
            ? 'OpenFoodFacts search failed. Check your internet connection.'
            : 'OpenFoodFacts temporarily failed. Showing previous results.';
        _results = existingResults;
      });
    }
  }

  void _scheduleSearch(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchLocalFoods(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: SafeArea(
        top: false,
        bottom: true,
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).viewPadding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Search foods', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search local foods or region-aware OFF fallback',
                        suffixIcon: IconButton(
                          icon: Icon(_isSearching ? Icons.hourglass_top_rounded : Icons.search_rounded, color: Colors.blueAccent),
                          onPressed: _isSearching ? null : () => _searchLocalFoods(_searchController.text),
                        ),
                      ),
                      onChanged: _scheduleSearch,
                      onSubmitted: (_) => _searchLocalFoods(_searchController.text),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.blueAccent, size: 30),
                    onPressed: () {
                      _debounce?.cancel();
                      Navigator.pop(context);
                      widget.onScanBarcode();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(_resultSource, style: const TextStyle(color: Colors.white70, fontSize: 12))),
                  TextButton(
                    onPressed: _isSearching ? null : () => _searchOpenFoodFactsFoods(_searchController.text),
                    child: const Text('Search Online', style: TextStyle(color: Colors.blueAccent)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_isSearching)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (_results.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_message, style: const TextStyle(color: Colors.white60), textAlign: TextAlign.center),
                        if (_canRetryOnline) ...[
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _isSearching
                                ? null
                                : () => _searchOpenFoodFactsFoods(
                                      _searchController.text,
                                    ),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry online search'),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (context, index) => const Divider(color: Colors.white10),
                    itemBuilder: (context, index) {
                      final item = _results[index];
                      return ListTile(
                        onTap: () => Navigator.pop(context, item),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                        title: Text(item.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'P ${item.proteinPer100g}g • C ${item.carbsPer100g}g • F ${item.fatPer100g}g per 100g',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.blueAccent),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
