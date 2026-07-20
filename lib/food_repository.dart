import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'models/food_item.dart';

class RegionalDatabaseStatus {
  final bool supported;
  final bool downloaded;
  final bool upToDate;
  final String latestVersion;
  final String? installedVersion;

  const RegionalDatabaseStatus({
    required this.supported,
    required this.downloaded,
    required this.upToDate,
    required this.latestVersion,
    required this.installedVersion,
  });
}

class RegionalDatabaseDownloadResult {
  final bool success;
  final bool alreadyUpToDate;
  final String message;

  const RegionalDatabaseDownloadResult({
    required this.success,
    required this.alreadyUpToDate,
    required this.message,
  });
}

class FoodRepository {
  static final FoodRepository instance = FoodRepository._();
  FoodRepository._();

  List<FoodItem>? _localFoods;
  List<FoodItem>? _beverages;
  List<FoodItem>? _fastFoodAll;
  String? _currentRegion;
  final Map<String, Database> _regionalSearchDatabases = {};

  static const Map<String, String> _regionalDbAssets = {
    'AU': 'foods_aus.db',
    'US': 'foods_usa.db',
    'GB': 'foods_uk.db',
  };

  static const String _regionalDbReleaseVersion = 'v1.0.2';
  static const Map<String, String> _regionalDbDownloadUrls = {
    'AU': 'https://github.com/revriest/dimestoremacro/releases/download/v1.0.2/foods_aus.db',
    'US': 'https://github.com/revriest/dimestoremacro/releases/download/v1.0.2/foods_usa.db',
    'GB': 'https://github.com/revriest/dimestoremacro/releases/download/v1.0.2/foods_uk.db',
  };

  static const List<Map<String, String>> supportedRegions = [
    {'code': 'US', 'name': '\u{1F1FA}\u{1F1F8} United States'},
    {'code': 'GB', 'name': '\u{1F1EC}\u{1F1E7} United Kingdom'},
    {'code': 'CA', 'name': '\u{1F1E8}\u{1F1E6} Canada'},
    {'code': 'AU', 'name': '\u{1F1E6}\u{1F1FA} Australia'},
    {'code': 'DE', 'name': '\u{1F1E9}\u{1F1EA} Germany'},
    {'code': 'FR', 'name': '\u{1F1EB}\u{1F1F7} France'},
    {'code': 'ES', 'name': '\u{1F1EA}\u{1F1F8} Spain'},
    {'code': 'IT', 'name': '\u{1F1EE}\u{1F1F9} Italy'},
    {'code': 'BR', 'name': '\u{1F1E7}\u{1F1F7} Brazil'},
    {'code': 'MX', 'name': '\u{1F1F2}\u{1F1FD} Mexico'},
    {'code': 'IN', 'name': '\u{1F1EE}\u{1F1F3} India'},
    {'code': 'NL', 'name': '\u{1F1F3}\u{1F1F1} Netherlands'},
    {'code': 'SE', 'name': '\u{1F1F8}\u{1F1EA} Sweden'},
    {'code': 'AE', 'name': '\u{1F1E6}\u{1F1EA} UAE'},
    {'code': 'SA', 'name': '\u{1F1F8}\u{1F1E6} Saudi Arabia'},
    {'code': 'ZA', 'name': '\u{1F1FF}\u{1F1E6} South Africa'},
    {'code': 'JP', 'name': '\u{1F1EF}\u{1F1F5} Japan'},
    {'code': 'KR', 'name': '\u{1F1F0}\u{1F1F7} South Korea'},
    {'code': 'GENERIC', 'name': '\u{1F30D} International (generic)'},
  ];

  void _log(String message) {
    if (!kDebugMode) return;
    debugPrint(message);
  }

  Future<String> _detectDeviceRegion() async {
    final locale = ui.PlatformDispatcher.instance.locale;
    final detected = locale.countryCode ?? 'GENERIC';
    _log('\u1f30d DETECTED REGION: $detected (Locale: ${locale.toString()})');
    return detected;
  }

  Future<String> getCurrentRegion() async {
    if (_currentRegion != null) {
      _log('\u1f4cd Using cached region: $_currentRegion');
      return _currentRegion!;
    }
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('user_region');
    if (stored != null) {
      _currentRegion = stored;
      _log('\u1f4be Loaded stored region: $stored');
      return stored;
    }
    final detected = await _detectDeviceRegion();
    await setRegion(detected);
    return _currentRegion!;
  }

  Future<void> setRegion(String countryCode) async {
    _currentRegion = countryCode.toUpperCase();
    _localFoods = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_region', _currentRegion!);
    _log('\u2705 Region saved: $_currentRegion');
  }

  Future<bool> hasRegionDatabase(String countryCode) async {
    try {
      await rootBundle.loadString(
        'assets/data/foods_${countryCode.toLowerCase()}.json',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<RegionalDatabaseStatus> getRegionalDatabaseStatus(
    String regionCode,
  ) async {
    final normalized = _normalizeRegionalDbCode(regionCode);
    final supported = _regionalDbAssets.containsKey(normalized);
    final prefs = await SharedPreferences.getInstance();
    final installedVersion = prefs.getString(
      _regionalDbVersionPreferenceKey(normalized),
    );
    final downloaded = await File(
      await _regionalDatabasePath(normalized),
    ).exists();
    return RegionalDatabaseStatus(
      supported: supported,
      downloaded: downloaded,
      upToDate: supported && downloaded && installedVersion == _regionalDbReleaseVersion,
      latestVersion: _regionalDbReleaseVersion,
      installedVersion: installedVersion,
    );
  }

  Future<RegionalDatabaseDownloadResult> downloadRegionalDatabase(
    String regionCode,
  ) async {
    final normalized = _normalizeRegionalDbCode(regionCode);
    final downloadUrl = _regionalDbDownloadUrls[normalized];
    final assetName = _regionalDbAssets[normalized];
    if (downloadUrl == null || assetName == null) {
      return const RegionalDatabaseDownloadResult(
        success: false,
        alreadyUpToDate: false,
        message: 'No downloadable database is available for this region.',
      );
    }

    final status = await getRegionalDatabaseStatus(normalized);
    if (status.upToDate) {
      return const RegionalDatabaseDownloadResult(
        success: true,
        alreadyUpToDate: true,
        message: 'Regional database is already up to date.',
      );
    }

    final response = await http
        .get(Uri.parse(downloadUrl), headers: {'User-Agent': 'DimeStoreMacro/1.0'})
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      return RegionalDatabaseDownloadResult(
        success: false,
        alreadyUpToDate: false,
        message: 'Download failed (${response.statusCode}).',
      );
    }

    final dbPath = await _regionalDatabasePath(normalized);
    final file = File(dbPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(response.bodyBytes, flush: true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _regionalDbVersionPreferenceKey(normalized),
      _regionalDbReleaseVersion,
    );

    final cached = _regionalSearchDatabases.remove(normalized);
    await cached?.close();

    return RegionalDatabaseDownloadResult(
      success: true,
      alreadyUpToDate: false,
      message: 'Downloaded ${normalized.toUpperCase()} regional database.',
    );
  }

  Future<List<FoodItem>> loadLocalFoods() async {
    if (_localFoods != null) {
      _log('\u1f4e6 Using cached foods (${_localFoods!.length} items)');
      return _localFoods!;
    }
    final region = await getCurrentRegion();
    final regionFile = 'assets/data/foods_${region.toLowerCase()}.json';
    _log('\u1f50d Attempting to load: $regionFile');
    try {
      final raw = await rootBundle.loadString(regionFile);
      final data = jsonDecode(raw) as List<dynamic>;
      _localFoods = data
          .map(
            (e) => _withCategory(
              FoodItem.fromJson(e as Map<String, dynamic>),
              null,
            ),
          )
          .toList();
      _log(
        '\u2705 SUCCESS: Loaded ${_localFoods!.length} foods from $region database',
      );
      return _localFoods!;
    } catch (e) {
      _log('\u26a0\ufe0f  Region file not found: $regionFile');
      _log('\u1f504 Falling back to generic foods...');
      try {
        final raw = await rootBundle.loadString(
          'assets/data/foods_generic.json',
        );
        final data = jsonDecode(raw) as List<dynamic>;
        _localFoods = data
            .map(
              (e) => _withCategory(
                FoodItem.fromJson(e as Map<String, dynamic>),
                null,
              ),
            )
            .toList();
        _log(
          '\u2705 SUCCESS: Loaded ${_localFoods!.length} foods from foods_generic.json',
        );
        return _localFoods!;
      } catch (_) {
        _log(
          '\u26a0\ufe0f  foods_generic.json not found, trying legacy generic_foods.json...',
        );
        final raw = await rootBundle.loadString(
          'assets/data/generic_foods.json',
        );
        final data = jsonDecode(raw) as List<dynamic>;
        _localFoods = data
            .map(
              (e) => _withCategory(
                FoodItem.fromJson(e as Map<String, dynamic>),
                null,
              ),
            )
            .toList();
        _log(
          '\u2705 SUCCESS: Loaded ${_localFoods!.length} foods from legacy generic_foods.json',
        );
        return _localFoods!;
      }
    }
  }

  Future<List<FoodItem>> searchLocalFoods(String query) async {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return [];
    final queryVariants = _buildQueryVariants(normalizedQuery);

    final region = await getCurrentRegion();
    List<FoodItem> primaryMatches = [];

    try {
      final dbMatches = await _searchRegionalFoodsForVariants(
        queryVariants,
        region,
      );
      if (dbMatches.isNotEmpty) {
        primaryMatches = dbMatches;
        _log(
          'SQLite FTS local search "$query" (${region.toUpperCase()}): ${primaryMatches.length} results',
        );
      }
    } catch (e) {
      _log('SQLite FTS local search error for region $region: $e');
    }

    if (primaryMatches.isEmpty) {
      try {
        primaryMatches = await _searchAcrossRegionalFtsForVariants(
          queryVariants,
          excludeRegionCode: region,
        );
        if (primaryMatches.isNotEmpty) {
          _log(
            'SQLite FTS cross-region search "$query": ${primaryMatches.length} results',
          );
        }
      } catch (e) {
        _log('SQLite FTS cross-region search error: $e');
      }
    }

    if (primaryMatches.isEmpty) {
      final localFoods = await loadLocalFoods();
      primaryMatches = localFoods
          .where((food) => _matchesFoodQuery(food, queryVariants))
          .toList();
    }

    final extras = await Future.wait([loadBeverages(), loadFastFood()]);
    final extraMatches = [...extras[0], ...extras[1]]
        .where((food) => _matchesFoodQuery(food, queryVariants))
        .toList();

    final deduped = <String, FoodItem>{};
    for (final item in [...primaryMatches, ...extraMatches]) {
      deduped[item.name.toLowerCase()] = item;
    }
    final searchResults = _rankSearchResults(
      normalizedQuery,
      queryVariants,
      deduped.values.toList(),
    );

    _log(
      '\u1f50d Search "$query": ${searchResults.length} total local results',
    );
    return searchResults;
  }

  List<FoodItem> _searchDedupByName(List<FoodItem> items) {
    final deduped = <String, FoodItem>{};
    for (final item in items) {
      deduped[item.name.toLowerCase()] = item;
    }
    return deduped.values.toList();
  }

  Future<List<FoodItem>> _searchRegionalFoodsForVariants(
    List<String> queryVariants,
    String regionCode,
  ) async {
    final collected = <FoodItem>[];
    for (final variant in queryVariants) {
      final results = await _searchRegionalFoodsFromFts(variant, regionCode);
      collected.addAll(results);
      if (collected.length >= 60) break;
    }
    return _searchDedupByName(collected).take(60).toList();
  }

  Future<List<FoodItem>> _searchAcrossRegionalFtsForVariants(
    List<String> queryVariants, {
    required String excludeRegionCode,
  }) async {
    final excluded = _normalizeRegionalDbCode(excludeRegionCode);
    final deduped = <String, FoodItem>{};

    for (final region in _regionalDbAssets.keys) {
      if (region == excluded) continue;
      final matches = await _searchRegionalFoodsForVariants(queryVariants, region);
      for (final item in matches) {
        deduped[item.name.toLowerCase()] = item;
      }
      if (deduped.length >= 60) break;
    }

    return deduped.values.take(60).toList();
  }

  List<String> _buildQueryVariants(String normalizedQuery) {
    final variants = <String>{normalizedQuery};
    final tokens = _tokenize(normalizedQuery);
    if (tokens.isNotEmpty) {
      final singularizedTokens = tokens.map(_singularizeToken).toList();
      final singularized = singularizedTokens.join(' ').trim();
      if (singularized.isNotEmpty) {
        variants.add(singularized);
      }
    }
    return variants.toList();
  }

  bool _matchesFoodQuery(FoodItem food, List<String> queryVariants) {
    final normalizedName = _normalizeSearchText(food.name);
    final normalizedAliases = food.searchAliases
        .map(_normalizeSearchText)
        .where((alias) => alias.isNotEmpty)
        .toList();

    for (final query in queryVariants) {
      if (normalizedName.contains(query)) return true;
      for (final alias in normalizedAliases) {
        if (alias.contains(query)) return true;
      }
    }
    return false;
  }

  List<FoodItem> _rankSearchResults(
    String query,
    List<String> queryVariants,
    List<FoodItem> items,
  ) {
    final scored = items
        .map((item) => (_scoreFoodMatch(item, query, queryVariants), item))
        .toList();
    scored.sort((a, b) {
      final byScore = b.$1.compareTo(a.$1);
      if (byScore != 0) return byScore;

      final aName = _normalizeSearchText(a.$2.name);
      final bName = _normalizeSearchText(b.$2.name);
      final byLength = aName.length.compareTo(bName.length);
      if (byLength != 0) return byLength;
      return aName.compareTo(bName);
    });

    return scored.map((entry) => entry.$2).take(60).toList();
  }

  int _scoreFoodMatch(FoodItem item, String query, List<String> queryVariants) {
    final name = _normalizeSearchText(item.name);
    if (name.isEmpty || query.isEmpty) return 0;

    final words = name.split(' ').where((w) => w.isNotEmpty).toList();
    final singularWords = words.map(_singularizeToken).toList();
    final queryTokens = _tokenize(query);
    final singularQueryTokens = queryTokens.map(_singularizeToken).toList();
    final singularQuery = singularQueryTokens.join(' ').trim();

    var score = 0;

    if (name == query) score += 10000;
    if (name.startsWith('$query ')) score += 6000;
    if (name.startsWith(query)) score += 4500;

    if (singularQuery.isNotEmpty && name == singularQuery) score += 8500;
    if (singularQuery.isNotEmpty && name.startsWith('$singularQuery ')) {
      score += 4800;
    }

    final index = name.indexOf(query);
    if (index == 0) {
      score += 2500;
    } else if (index > 0) {
      score += 1200 - (index > 120 ? 120 : index);
    }

    var matchedToken = false;
    for (var i = 0; i < words.length; i++) {
      final word = words[i];
      final singularWord = singularWords[i];
      if (_tokenMatchesQuery(word, query)) {
        score += i == 0 ? 3800 : 2300;
        matchedToken = true;
      } else if (queryTokens.any((token) => _tokenMatchesQuery(word, token))) {
        score += i == 0 ? 2200 : 1300;
      } else if (singularQueryTokens.any((token) => singularWord == token)) {
        score += i == 0 ? 2200 : 1300;
      } else if (word.startsWith(query)) {
        score += i == 0 ? 1800 : 900;
      }
    }

    for (final alias in item.searchAliases) {
      final normalizedAlias = _normalizeSearchText(alias);
      if (normalizedAlias == query) {
        score += 2600;
      } else if (normalizedAlias.startsWith('$query ') ||
          normalizedAlias.startsWith(query)) {
        score += 1400;
      } else if (normalizedAlias.contains(query)) {
        score += 600;
      }
    }

    if (name.contains(query) && !matchedToken) {
      score += 700;
    }

    for (final variant in queryVariants) {
      if (variant == query || variant.isEmpty) continue;
      if (name == variant) {
        score += 7000;
      } else if (name.startsWith('$variant ')) {
        score += 3800;
      } else if (name.contains(variant)) {
        score += 900;
      }
    }

    score += _stapleIntentBoost(name, words, singularWords, singularQueryTokens);

    if (query.length <= 4 && words.length > 2) {
      score -= (words.length - 2) * 180;
    }
    if (query.length <= 4 && name.contains('(')) {
      score -= 220;
    }

    final lengthPenalty = name.length > 140 ? 140 : name.length;
    score -= lengthPenalty;

    return score;
  }

  int _stapleIntentBoost(
    String normalizedName,
    List<String> words,
    List<String> singularWords,
    List<String> singularQueryTokens,
  ) {
    if (singularQueryTokens.length != 1) return 0;
    final token = singularQueryTokens.first;
    if (token.isEmpty) return 0;

    final preferred = _preferredStapleDescriptors[token];
    if (preferred == null) return 0;

    var bonus = 0;
    for (final descriptor in preferred) {
      if (words.contains(descriptor) || singularWords.contains(descriptor)) {
        bonus += 1200;
      }
      if (normalizedName.startsWith('$token $descriptor')) {
        bonus += 1800;
      }
    }

    for (final term in _processedFoodTerms) {
      if (words.contains(term) || singularWords.contains(term)) {
        bonus -= 950;
      }
    }

    return bonus;
  }

  static const Map<String, List<String>> _preferredStapleDescriptors = {
    'chicken': ['breast', 'thigh', 'tenderloin', 'fillet'],
    'egg': ['whole', 'white', 'boiled', 'poached', 'scrambled'],
    'beef': ['lean', 'mince', 'steak'],
    'rice': ['white', 'brown', 'basmati', 'jasmine'],
  };

  static const Set<String> _processedFoodTerms = {
    'ball',
    'balls',
    'nugget',
    'nuggets',
    'crispy',
    'fried',
    'patty',
    'pattie',
    'dumpling',
    'dumplings',
    'candy',
    'chocolate',
    'cookie',
    'cookies',
  };

  bool _tokenMatchesQuery(String token, String query) {
    final normalizedToken = _singularizeToken(token);
    final normalizedQuery = _singularizeToken(query);
    if (normalizedToken == normalizedQuery) return true;
    return token == query;
  }

  List<String> _tokenize(String value) {
    return _normalizeSearchText(value)
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toList();
  }

  String _singularizeToken(String token) {
    if (token.length <= 3) return token;
    if (token.endsWith('ies') && token.length > 4) {
      return '${token.substring(0, token.length - 3)}y';
    }
    if (token.endsWith('es') && token.length > 4) {
      final stem = token.substring(0, token.length - 2);
      if (stem.endsWith('s') ||
          stem.endsWith('x') ||
          stem.endsWith('z') ||
          stem.endsWith('ch') ||
          stem.endsWith('sh')) {
        return stem;
      }
    }
    if (token.endsWith('s') && !token.endsWith('ss')) {
      return token.substring(0, token.length - 1);
    }
    return token;
  }

  String _normalizeSearchText(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _normalizeRegionalDbCode(String regionCode) {
    final normalized = regionCode.trim().toUpperCase();
    switch (normalized) {
      case 'AUS':
        return 'AU';
      case 'USA':
        return 'US';
      case 'UK':
        return 'GB';
      default:
        return normalized;
    }
  }

  Future<Database?> _openRegionalFtsDatabase(String regionCode) async {
    final normalized = _normalizeRegionalDbCode(regionCode);
    final dbAsset = _regionalDbAssets[normalized];
    if (dbAsset == null) return null;

    final existing = _regionalSearchDatabases[normalized];
    if (existing != null && existing.isOpen) {
      return existing;
    }

    final dbPath = await _regionalDatabasePath(normalized);
    final file = File(dbPath);
    if (!await file.exists()) {
      return null;
    }

    final db = await openDatabase(dbPath, readOnly: true);
    _regionalSearchDatabases[normalized] = db;
    return db;
  }

  Future<String> _regionalDatabasePath(String normalizedRegionCode) async {
    final dbAsset = _regionalDbAssets[normalizedRegionCode];
    if (dbAsset == null) {
      throw ArgumentError('Unsupported region: $normalizedRegionCode');
    }
    final dbDir = await getDatabasesPath();
    return '$dbDir/$dbAsset';
  }

  String _regionalDbVersionPreferenceKey(String normalizedRegionCode) {
    return 'downloaded_region_db_release_version_$normalizedRegionCode';
  }

  String _buildFtsPrefixQuery(String query) {
    final cleaned = query
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return '';
    final tokens = cleaned
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toList();
    return tokens.map((token) => '$token*').join(' ');
  }

  Future<List<FoodItem>> _searchRegionalFoodsFromFts(
    String query,
    String regionCode,
  ) async {
    final db = await _openRegionalFtsDatabase(regionCode);
    if (db == null) return [];

    final ftsQuery = _buildFtsPrefixQuery(query);
    if (ftsQuery.isEmpty) return [];

    List<Map<String, Object?>> rows;
    try {
      rows = await db.rawQuery(
        '''
        SELECT
          f.code,
          f.product_name,
          f.brands,
          f.serving_size,
          f.energy_kcal_100g,
          f.proteins_100g,
          f.carbohydrates_100g,
          f.fat_100g
        FROM foods_fts s
        JOIN foods f ON f.rowid = s.rowid
        WHERE foods_fts MATCH ?
        ORDER BY bm25(foods_fts)
        LIMIT 60
        ''',
        [ftsQuery],
      );
    } catch (e) {
      _log('FTS query failed for $regionCode, using SQL LIKE fallback: $e');
      rows = const [];
    }

    if (rows.isEmpty) {
      final likeRows = await db.rawQuery(
        '''
        SELECT
          code,
          product_name,
          brands,
          serving_size,
          energy_kcal_100g,
          proteins_100g,
          carbohydrates_100g,
          fat_100g
        FROM foods
        WHERE lower(product_name) LIKE ?
           OR lower(brands) LIKE ?
        LIMIT 60
        ''',
        ['%$query%', '%$query%'],
      );
      return _rowsToFoodItems(likeRows);
    }

    return _rowsToFoodItems(rows);
  }

  List<FoodItem> _rowsToFoodItems(List<Map<String, Object?>> rows) {
    return rows.map((row) {
      final productName = (row['product_name'] as String?)?.trim() ?? '';
      final brands = (row['brands'] as String?)?.trim() ?? '';
      final displayName =
          (brands.isNotEmpty && !productName.toLowerCase().contains(brands.toLowerCase()))
          ? '$productName ($brands)'
          : productName;

      final protein = _parseDouble(row['proteins_100g']) ?? 0;
      final carbs = _parseDouble(row['carbohydrates_100g']) ?? 0;
      final fat = _parseDouble(row['fat_100g']) ?? 0;
      final calories = _parseDouble(row['energy_kcal_100g']) ??
          ((protein * 4) + (carbs * 4) + (fat * 9));

      return FoodItem(
        name: displayName.isNotEmpty ? displayName : 'Unknown food',
        caloriesPer100g: calories.round(),
        proteinPer100g: protein.round(),
        carbsPer100g: carbs.round(),
        fatPer100g: fat.round(),
        servingSize: (row['serving_size'] as String?)?.trim(),
      );
    }).toList();
  }

  String _detectCategory(String foodName, String? sourceDatabase) {
    final name = foodName.toLowerCase();
    if (sourceDatabase == 'mcdonalds' ||
        sourceDatabase == 'kfc' ||
        sourceDatabase == 'subway' ||
        sourceDatabase == 'starbucks' ||
        name.contains('burger') ||
        name.contains('pizza')) {
      return '\u{1F354} Fast Food';
    }
    if (sourceDatabase == 'beverages' ||
        name.contains('coffee') ||
        name.contains('latte') ||
        name.contains('flat white') ||
        name.contains('cappuccino') ||
        name.contains('juice') ||
        name.contains('milk shake') ||
        name.contains('smoothie')) {
      return '\u{2615} Beverages';
    }
    if (name.contains('chicken') ||
        name.contains('beef') ||
        name.contains('pork') ||
        name.contains('fish') ||
        name.contains('salmon') ||
        name.contains('tuna') ||
        name.contains('egg') ||
        name.contains('protein') ||
        name.contains('whey') ||
        name.contains('turkey')) {
      return '\u{1F969} Protein';
    }
    if (name.contains('milk') ||
        name.contains('yogurt') ||
        name.contains('cheese') ||
        name.contains('cream')) {
      return '\u{1F95B} Dairy';
    }
    if (name.contains('rice') ||
        name.contains('bread') ||
        name.contains('pasta') ||
        name.contains('oats') ||
        name.contains('cereal') ||
        name.contains('bagel')) {
      return '\u{1F35E} Grains';
    }
    if (name.contains('broccoli') ||
        name.contains('carrot') ||
        name.contains('spinach') ||
        name.contains('lettuce') ||
        name.contains('tomato') ||
        name.contains('pepper')) {
      return '\u{1F96C} Vegetables';
    }
    if (name.contains('apple') ||
        name.contains('banana') ||
        name.contains('orange') ||
        name.contains('berry') ||
        name.contains('grape') ||
        name.contains('mango')) {
      return '\u{1F34E} Fruits';
    }
    if (name.contains('almond') ||
        name.contains('walnut') ||
        name.contains('peanut') ||
        name.contains('cashew') ||
        name.contains('seed')) {
      return '\u{1F95C} Nuts & Seeds';
    }
    return '\u{1F37D}\u{FE0F} Other';
  }

  FoodItem _withCategory(FoodItem item, String? source) {
    if (item.category != null) return item;
    return FoodItem(
      name: item.name,
      caloriesPer100g: item.caloriesPer100g,
      proteinPer100g: item.proteinPer100g,
      carbsPer100g: item.carbsPer100g,
      fatPer100g: item.fatPer100g,
      servingSize: item.servingSize,
      servingProtein: item.servingProtein,
      servingCarbs: item.servingCarbs,
      servingFat: item.servingFat,
      category: _detectCategory(item.name, source),
    );
  }

  Future<List<FoodItem>> loadBeverages() async {
    if (_beverages != null) return _beverages!;
    try {
      final raw = await rootBundle.loadString(
        'assets/data/foods_beverages.json',
      );
      final data = jsonDecode(raw) as List<dynamic>;
      _beverages = data
          .map(
            (e) => _withCategory(
              FoodItem.fromJson(e as Map<String, dynamic>),
              'beverages',
            ),
          )
          .toList();
      _log('\u2705 Loaded ${_beverages!.length} beverages');
      return _beverages!;
    } catch (e) {
      _log('\u26a0\ufe0f  Could not load beverages: $e');
      _beverages = [];
      return [];
    }
  }

  Future<List<FoodItem>> loadFastFood() async {
    if (_fastFoodAll != null) return _fastFoodAll!;
    _fastFoodAll = [];
    const chains = ['mcdonalds', 'kfc', 'subway', 'starbucks'];
    for (final chain in chains) {
      try {
        final raw = await rootBundle.loadString(
          'assets/data/foods_$chain.json',
        );
        final data = jsonDecode(raw) as List<dynamic>;
        final items = data.map((e) {
          final item = FoodItem.fromJson(e as Map<String, dynamic>);
          final branded = !item.name.contains('(')
              ? FoodItem(
                  name: '${item.name} (${_capitalizeChain(chain)})',
                  caloriesPer100g: item.caloriesPer100g,
                  proteinPer100g: item.proteinPer100g,
                  carbsPer100g: item.carbsPer100g,
                  fatPer100g: item.fatPer100g,
                  servingSize: item.servingSize,
                  servingProtein: item.servingProtein,
                  servingCarbs: item.servingCarbs,
                  servingFat: item.servingFat,
                )
              : item;
          return _withCategory(branded, chain);
        }).toList();
        _fastFoodAll!.addAll(items);
        _log('\u2705 Loaded ${items.length} items from $chain');
      } catch (_) {
        // File doesn't exist yet — silently skip
      }
    }
    _log('\u2705 Total fast food items: ${_fastFoodAll!.length}');
    return _fastFoodAll!;
  }

  String _capitalizeChain(String chain) {
    switch (chain) {
      case 'mcdonalds':
        return "McDonald's";
      case 'kfc':
        return 'KFC';
      case 'subway':
        return 'Subway';
      case 'starbucks':
        return 'Starbucks';
      default:
        return chain[0].toUpperCase() + chain.substring(1);
    }
  }

  Future<List<FoodItem>> searchUsdaFoods(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return [];

    final uri = Uri.https('api.nal.usda.gov', '/fdc/v1/foods/search', {
      'query': normalizedQuery,
      'pageSize': '12',
      'api_key': const String.fromEnvironment(
        'USDA_API_KEY',
        defaultValue: 'DEMO_KEY',
      ),
    });

    try {
      final response = await http
          .get(uri, headers: {'User-Agent': 'DimeStoreMacro/1.0'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 429) {
        _log(
          '\u26a0\ufe0f USDA rate limit hit (DEMO_KEY allows 30 req/hour). Register a free key at fdc.nal.usda.gov',
        );
        throw UsdaRateLimitException();
      }
      if (response.statusCode != 200) {
        _log('USDA API error: ${response.statusCode}');
        return [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final foods = (data['foods'] as List<dynamic>?) ?? [];
      _log('\u1f30d USDA: ${foods.length} raw results for "$normalizedQuery"');
      final parsed = foods.map<FoodItem>(_foodItemFromUsda).where((item) {
        return item.proteinPer100g > 0 ||
            item.carbsPer100g > 0 ||
            item.fatPer100g > 0;
      }).toList();
      _log('\u2705 USDA: ${parsed.length} items after macro filter');
      return parsed;
    } on TimeoutException {
      _log('USDA API timeout');
      return [];
    } on SocketException {
      _log('No internet connection');
      return [];
    } catch (e) {
      _log('USDA API error: $e');
      return [];
    }
  }

  Future<List<FoodItem>> searchOpenFoodFactsFoods(
    String query, {
    String? regionCode,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return [];

    final targetRegion =
        (regionCode ?? await getCurrentRegion()).trim().toUpperCase();
    final uri = Uri.https('world.openfoodfacts.org', '/cgi/search.pl', {
      'search_terms': normalizedQuery,
      'search_simple': '1',
      'action': 'process',
      'json': '1',
      'page_size': '24',
      'fields': 'product_name,generic_name,brands,serving_size,serving_quantity,serving_quantity_unit,nutrition_data_per,nutriments,countries_tags',
    });

    try {
      final response = await http
          .get(uri, headers: {'User-Agent': 'DimeStoreMacro/1.0'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        _log('OpenFoodFacts search error: ${response.statusCode}');
        return [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final products = (data['products'] as List<dynamic>?) ?? const [];

      final filtered = products
          .whereType<Map<String, dynamic>>()
          .where((p) => _matchesOpenFoodFactsRegion(p, targetRegion))
          .map(_foodItemFromOpenFoodFactsSearch)
          .whereType<FoodItem>()
          .toList();

      _log(
        'OpenFoodFacts search "$normalizedQuery": ${filtered.length} items for region $targetRegion',
      );
      return filtered;
    } on TimeoutException {
      _log('OpenFoodFacts search timeout');
      return [];
    } on SocketException {
      _log('No internet connection');
      return [];
    } catch (e) {
      _log('OpenFoodFacts search error: $e');
      return [];
    }
  }

  bool _matchesOpenFoodFactsRegion(
    Map<String, dynamic> product,
    String regionCode,
  ) {
    if (regionCode.isEmpty || regionCode == 'GENERIC') return true;

    final tagsRaw = product['countries_tags'];
    if (tagsRaw is! List || tagsRaw.isEmpty) return true;

    final aliases = _regionAliasesForOpenFoodFacts(regionCode);
    for (final tag in tagsRaw) {
      final normalizedTag = tag
          .toString()
          .toLowerCase()
          .replaceFirst(RegExp(r'^[a-z]{2}:'), '');
      if (aliases.any((alias) => normalizedTag.contains(alias))) {
        return true;
      }
    }
    return false;
  }

  List<String> _regionAliasesForOpenFoodFacts(String code) {
    switch (code) {
      case 'US':
        return const ['united-states', 'usa', 'us'];
      case 'GB':
        return const ['united-kingdom', 'uk', 'gb', 'great-britain'];
      case 'AE':
        return const ['united-arab-emirates', 'uae', 'ae'];
      case 'SA':
        return const ['saudi-arabia', 'saudi', 'sa'];
      case 'KR':
        return const ['south-korea', 'korea', 'kr'];
      default:
        return [code.toLowerCase()];
    }
  }

  FoodItem? _foodItemFromOpenFoodFactsSearch(Map<String, dynamic> product) {
    final nutriments = product['nutriments'] as Map<String, dynamic>? ?? {};
    final nutritionPer =
        (product['nutrition_data_per'] as String?)?.toLowerCase() ?? '';
    final name =
        (product['product_name'] as String?)?.trim() ??
        (product['generic_name'] as String?)?.trim() ??
        '';
    if (name.isEmpty) return null;

    final protein = _readOffPer100g(nutriments, 'proteins', nutritionPer);
    final carbs = _readOffPer100g(nutriments, 'carbohydrates', nutritionPer);
    final fat = _readOffPer100g(nutriments, 'fat', nutritionPer);
    final calories = _sanitizeOffCalories(
      _parseOffCalories(nutriments, nutritionPer),
      nutriments,
      protein,
      carbs,
      fat,
      nutritionPer,
    );

    if (protein == 0 && carbs == 0 && fat == 0) return null;

    final brands = (product['brands'] as String?)?.trim();
    final displayName = (brands != null && brands.isNotEmpty)
        ? '$name ($brands)'
        : name;

    final servingSize = _offServingSize(product);

    return FoodItem(
      name: displayName,
      caloriesPer100g: calories.round(),
      proteinPer100g: protein.round(),
      carbsPer100g: carbs.round(),
      fatPer100g: fat.round(),
      servingSize: servingSize,
      servingProtein: _readOffServing(
        nutriments,
        'proteins',
        nutritionPer,
      )?.round(),
      servingCarbs: _readOffServing(
        nutriments,
        'carbohydrates',
        nutritionPer,
      )?.round(),
      servingFat: _readOffServing(nutriments, 'fat', nutritionPer)?.round(),
    );
  }

  Future<FoodItem?> fetchOpenFoodFactsBarcode(String barcode) async {
    final uri = Uri.https(
      'world.openfoodfacts.org',
      '/api/v0/product/$barcode.json',
    );

    try {
      final response = await http
          .get(uri, headers: {'User-Agent': 'DimeStoreMacro/1.0'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        _log('OpenFoodFacts error: ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if ((data['status'] as int?) != 1) return null;

      final product = data['product'] as Map<String, dynamic>?;
      if (product == null) return null;

      final nutriments = product['nutriments'] as Map<String, dynamic>? ?? {};
      final nutritionPer =
          (product['nutrition_data_per'] as String?)?.toLowerCase() ?? '';
      final name =
          product['product_name'] as String? ??
          product['generic_name'] as String? ??
          'Scanned product';
      final servingSize = _offServingSize(product);

      final protein = _readOffPer100g(nutriments, 'proteins', nutritionPer);
      final carbs = _readOffPer100g(nutriments, 'carbohydrates', nutritionPer);
      final fat = _readOffPer100g(nutriments, 'fat', nutritionPer);
      final calories = _sanitizeOffCalories(
        _parseOffCalories(nutriments, nutritionPer),
        nutriments,
        protein,
        carbs,
        fat,
        nutritionPer,
      );

      if (protein == 0 && carbs == 0 && fat == 0) return null;

      return FoodItem(
        name: name,
        caloriesPer100g: calories.round(),
        proteinPer100g: protein.round(),
        carbsPer100g: carbs.round(),
        fatPer100g: fat.round(),
        servingSize: servingSize,
        servingProtein: _readOffServing(
          nutriments,
          'proteins',
          nutritionPer,
        )?.round(),
        servingCarbs: _readOffServing(
          nutriments,
          'carbohydrates',
          nutritionPer,
        )?.round(),
        servingFat: _readOffServing(nutriments, 'fat', nutritionPer)?.round(),
      );
    } on TimeoutException {
      _log('OpenFoodFacts timeout');
      return null;
    } on SocketException {
      _log('No internet connection');
      return null;
    } catch (e) {
      _log('OpenFoodFacts error: $e');
      return null;
    }
  }

  FoodItem _foodItemFromUsda(dynamic rawFood) {
    final food = rawFood as Map<String, dynamic>;
    final name = food['description'] as String? ?? 'USDA Food';
    final nutrients = (food['foodNutrients'] as List<dynamic>?) ?? [];

    final calories = _readNutrientValue(nutrients, '208');
    final protein = _readNutrientValue(nutrients, '203');
    final carbs = _readNutrientValue(nutrients, '205');
    final fat = _readNutrientValue(nutrients, '204');

    // servingSize in USDA response is a number (e.g. 28.35), not a string
    final servingSizeRaw = food['servingSize'];
    final servingSizeUnit = food['servingSizeUnit'] as String? ?? 'g';
    final servingSizeStr = servingSizeRaw != null
        ? '${_parseDouble(servingSizeRaw)?.toStringAsFixed(1) ?? servingSizeRaw} $servingSizeUnit'
        : null;

    return FoodItem(
      name: name,
      caloriesPer100g: calories.round(),
      proteinPer100g: protein.round(),
      carbsPer100g: carbs.round(),
      fatPer100g: fat.round(),
      servingSize: servingSizeStr,
      servingProtein: null,
      servingCarbs: null,
      servingFat: null,
    );
  }

  double _readNutrientValue(List<dynamic> nutrients, String nutrientNumber) {
    for (final entry in nutrients) {
      final nutrient = entry as Map<String, dynamic>;

      // Flat structure: branded foods search results
      final flatNumber =
          nutrient['nutrientNumber']?.toString() ??
          nutrient['number']?.toString();
      if (flatNumber == nutrientNumber) {
        return _parseDouble(nutrient['value']) ??
            _parseDouble(nutrient['amount']) ??
            0;
      }

      // Nested structure: Foundation / SR Legacy foods
      final nested = nutrient['nutrient'] as Map<String, dynamic>?;
      if (nested != null) {
        final nestedNumber = nested['number']?.toString();
        if (nestedNumber == nutrientNumber) {
          return _parseDouble(nutrient['amount']) ?? 0;
        }
      }
    }
    return 0;
  }

  String? _offServingSize(Map<String, dynamic> product) {
    final raw = (product['serving_size'] as String?)?.trim();
    if (raw != null && raw.isNotEmpty) return raw;

    final qty = _parseDouble(product['serving_quantity']);
    final unit = (product['serving_quantity_unit'] as String?)?.trim();
    if (qty != null && qty > 0 && unit != null && unit.isNotEmpty) {
      final qtyText = qty % 1 == 0 ? qty.toInt().toString() : qty.toString();
      return '$qtyText $unit';
    }

    return null;
  }

  double _readOffPer100g(
    Map<String, dynamic> nutriments,
    String prefix,
    String nutritionPer,
  ) {
    final by100g = _parseDouble(nutriments['${prefix}_100g']);
    if (by100g != null) return by100g;

    if (nutritionPer == '100g') {
      final value = _parseDouble(nutriments['${prefix}_value']);
      if (value != null) return value;
      return _parseDouble(nutriments[prefix]) ?? 0;
    }

    return _parseDouble(nutriments['${prefix}_value']) ??
        _parseDouble(nutriments[prefix]) ??
        0;
  }

  double? _readOffServing(
    Map<String, dynamic> nutriments,
    String prefix,
    String nutritionPer,
  ) {
    final serving = _parseDouble(nutriments['${prefix}_serving']);
    if (serving != null) return serving;

    if (nutritionPer == 'serving') {
      return _parseDouble(nutriments['${prefix}_value']) ??
          _parseDouble(nutriments[prefix]);
    }

    return null;
  }

  double _parseOffCalories(Map<String, dynamic> nutriments, String nutritionPer) {
    final kcal = _parseDouble(nutriments['energy-kcal_100g']) ??
        ((nutritionPer == '100g')
            ? _parseDouble(nutriments['energy-kcal_value'])
            : null) ??
        ((nutritionPer == '100g') ? _parseDouble(nutriments['energy-kcal']) : null);
    if (kcal != null) return kcal;

    final energy = _parseDouble(nutriments['energy_100g']) ??
        ((nutritionPer == '100g') ? _parseDouble(nutriments['energy_value']) : null) ??
        ((nutritionPer == '100g') ? _parseDouble(nutriments['energy']) : null);
    if (energy == null) return 0;

    final unit = (nutriments['energy-kcal_unit'] ?? nutriments['energy_unit'])
        ?.toString()
        .toLowerCase();
    if (unit == 'kcal') return energy;
    if (unit == 'kj') return energy / 4.184;

    // OFF usually stores energy_100g in kJ when kcal is absent.
    return energy / 4.184;
  }

  double _sanitizeOffCalories(
    double parsedCalories,
    Map<String, dynamic> nutriments,
    double protein,
    double carbs,
    double fat,
    String nutritionPer,
  ) {
    final alcohol = _parseDouble(nutriments['alcohol_100g']) ??
        ((nutritionPer == '100g')
            ? _parseDouble(nutriments['alcohol_value'])
            : null) ??
        ((nutritionPer == '100g') ? _parseDouble(nutriments['alcohol']) : null) ??
        0;
    final computedCalories = (protein * 4) + (carbs * 4) + (fat * 9) + (alcohol * 7);

    if (parsedCalories <= 0 && computedCalories > 0) {
      return computedCalories;
    }

    if (parsedCalories > 0 && computedCalories > 0) {
      final diff = (parsedCalories - computedCalories).abs();
      if (diff > 150) {
        return computedCalories;
      }
    }

    return parsedCalories;
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '.'));
    return null;
  }
}

/// Thrown when the USDA API returns HTTP 429 (rate limit exceeded).
class UsdaRateLimitException implements Exception {
  @override
  String toString() =>
      'USDA rate limit exceeded. Try again later or use a registered API key.';
}
