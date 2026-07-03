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
  bool _isSearching = false;
  String _resultSource = 'Local results';
  String _message = 'Type a food name to search local foods.';
  List<FoodItem> _results = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchLocalFoods(String query) async {
    if (!mounted) return;
    if (query.trim().isEmpty) {
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

    final localMatches = await FoodRepository.instance.searchLocalFoods(query);
    if (!mounted) return;
    if (localMatches.isNotEmpty) {
      setState(() {
        _results = localMatches;
        _message = 'Found ${localMatches.length} local matches.';
        _resultSource = 'Local results';
        _isSearching = false;
      });
      return;
    }

    await _searchUsdaFoods(query);
  }

  Future<void> _searchUsdaFoods(String query) async {
    if (!mounted) return;
    setState(() {
      _isSearching = true;
      _message = 'No local match. Searching USDA...';
      _resultSource = 'USDA fallback';
    });

    final onlineResults = await FoodRepository.instance.searchUsdaFoods(query);
    if (!mounted) return;
    setState(() {
      _results = onlineResults;
      if (onlineResults.isEmpty) {
        _message = 'No USDA results found for "$query".';
      } else {
        _message = 'Showing ${onlineResults.length} USDA results.';
      }
      _isSearching = false;
    });
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
                        hintText: 'Search local foods or use online fallback',
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
                    onPressed: _isSearching ? null : () => _searchUsdaFoods(_searchController.text),
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
                    child: Text(_message, style: const TextStyle(color: Colors.white60)),
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
                        subtitle: Text('P ${item.proteinPer100g}g • C ${item.carbsPer100g}g • F ${item.fatPer100g}g per 100g', style: const TextStyle(color: Colors.white70)),
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
