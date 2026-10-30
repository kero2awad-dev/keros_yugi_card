import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/json_import_service.dart';
import '../models/card_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:translator/translator.dart';
import 'package:collection/collection.dart';

class CardSearchParams {
  final String query;
  final String? type;
  final String? attribute;
  final String? style;
  final String? archetype;

  const CardSearchParams({
    required this.query,
    this.type,
    this.attribute,
    this.style,
    this.archetype,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CardSearchParams &&
          runtimeType == other.runtimeType &&
          query == other.query &&
          type == other.type &&
          attribute == other.attribute &&
          style == other.style &&
          archetype == other.archetype;

  @override
  int get hashCode => Object.hash(query, type, attribute, style, archetype);
}

class CardRepository {
  final SupabaseClient _client;
  final JsonImportService _jsonService;
  List<YugiCard>? _localCache;
  bool _isCacheLoading = false;
  Completer<void>? _initCompleter;
  final _translator = GoogleTranslator();

  List<YugiCard> _discoveredArabicCards = [];
  List<YugiCard> _discoveredFLCards = [];
  bool _hasLoadedMetadata = false;

  CardRepository(this._client, this._jsonService);

  Future<void> initCache() async {
    if (_localCache != null && _hasLoadedMetadata) return;
    if (_isCacheLoading) return _initCompleter?.future;

    _isCacheLoading = true;
    _initCompleter = Completer<void>();

    try {
      _localCache = await _jsonService.loadCardsFromAssets();
      await _loadMetadata();
      _initCompleter?.complete();
    } catch (e) {
      _initCompleter?.completeError(e);
      _initCompleter = null;
    } finally {
      _isCacheLoading = false;
    }
  }

  Future<void> _loadMetadata() async {
    if (_hasLoadedMetadata) return;
    try {
      final String response = await rootBundle.loadString('assets/data/organized_cards_metadata.json');
      final data = json.decode(response);
      
      if (data is Map) {
        if (data.containsKey('arabic_cards')) {
          _discoveredArabicCards = (data['arabic_cards'] as List).map((item) {
            String id = item['card_id']?.toString().trim() ?? '';
            if (id.isNotEmpty && !id.endsWith('_ar')) id = "${id}_ar";
            return _createPlaceholderFromMeta(id, item['card_name_en'] ?? 'Arabic Card', item['type'] ?? 'Monster', 'Arabic');
          }).toList();
        }
        
        if (data.containsKey('over_frame_cards')) {
          _discoveredFLCards = (data['over_frame_cards'] as List).map((item) {
            String filename = item['filename']?.toString().trim() ?? '';
            String id = filename.replaceAll('.jpg', '');
            return _createPlaceholderFromMeta(id, item['identified_card'] ?? 'Frame Less Card', 'Monster', 'Frame Less');
          }).toList();
        }
      }
      _hasLoadedMetadata = true;
    } catch (e) {
      debugPrint("❌ Error loading organized_cards_metadata.json: $e");
    }
  }

  YugiCard _createPlaceholderFromMeta(String id, String name, String type, String style) {
    String baseId = _normalizeId(id.replaceAll('_ar', '').replaceAll('_fl', '').replaceAll('_anime', ''));
    YugiCard? localCard = _findInLocalCache(baseId);

    return YugiCard(
      id: id,
      name: localCard?.name ?? name,
      type: localCard?.type ?? type,
      frameType: style,
      desc: localCard?.desc ?? "بطاقة متوفرة بجودة عالية",
      price: localCard?.price ?? 5.0,
      atk: localCard?.atk,
      def: localCard?.def,
      level: localCard?.level,
      race: localCard?.race,
      attribute: localCard?.attribute,
      archetype: localCard?.archetype,
    );
  }

  String _normalizeId(String id) {
    String clean = id.trim();
    if (RegExp(r'^\d+$').hasMatch(clean)) {
        String normalized = clean.replaceFirst(RegExp('^0+'), '');
        return normalized.isEmpty ? "0" : normalized;
    }
    return clean;
  }

  YugiCard? _findInLocalCache(String id) {
    if (_localCache == null) return null;
    final normalizedSearchId = _normalizeId(id);
    
    return _localCache!.firstWhereOrNull((c) {
      return _normalizeId(c.id) == normalizedSearchId;
    });
  }

  bool _isArabic(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  Future<List<YugiCard>> searchCards({
    required String query,
    String? type,
    String? attribute,
    String? style,
    String? archetype,
    int page = 0,
    int pageSize = 20,
  }) async {
    await initCache();

    String searchTerms = query.trim();

    if (searchTerms.isNotEmpty && _isArabic(searchTerms)) {
      try {
        var translation = await _translator.translate(searchTerms, from: 'ar', to: 'en');
        searchTerms = translation.text;
      } catch (e) {}
    }

    if (style == 'Arabic' || style == 'Frame Less') {
      final String nonNullStyle = style!;
      List<YugiCard> source = (nonNullStyle == 'Arabic') ? _discoveredArabicCards : _discoveredFLCards;
      
      var filtered = source.where((card) {
        final q = searchTerms.toLowerCase();
        final bool matchQuery = searchTerms.isEmpty || 
               card.name.toLowerCase().contains(q) || 
               card.id.toLowerCase().contains(q);
        
        final bool matchArchetype = archetype == null || archetype.isEmpty || 
                                   (card.archetype != null && card.archetype!.toLowerCase() == archetype.toLowerCase());
        
        return matchQuery && matchArchetype;
      }).toList();

      final from = page * pageSize;
      if (from >= filtered.length) return [];
      return filtered.skip(from).take(pageSize).toList();
    }

    return _searchLocal(searchTerms, type, attribute, style, archetype, page: page, pageSize: pageSize);
  }

  List<YugiCard> _searchLocal(String query, String? type, String? attribute, String? style, String? archetype, {int page = 0, int pageSize = 20}) {
    if (_localCache == null) return [];
    
    final String q = query.toLowerCase();

    var filtered = _localCache!.where((card) {
      final bool matchQuery = q.isEmpty || 
                         card.name.toLowerCase().contains(q) || 
                         card.id.trim().contains(q);
      
      final bool matchType = type == null || type.isEmpty || card.type.toLowerCase().contains(type.toLowerCase());
      final bool matchAttr = attribute == null || attribute.isEmpty || card.attribute == attribute;
      final bool matchArchetype = archetype == null || archetype.isEmpty || 
                                   (card.archetype != null && card.archetype!.toLowerCase() == archetype.toLowerCase());
      
      bool matchStyle = true;
      if (style == 'English') {
        matchStyle = !card.id.endsWith('_ar') && !card.id.endsWith('_fl');
      }
      return matchQuery && matchType && matchAttr && matchStyle && matchArchetype;
    }).toList();

    final from = page * pageSize;
    if (from >= filtered.length) return [];
    return filtered.skip(from).take(pageSize).toList();
  }

  Future<YugiCard?> _getSingleCardInternal(String rawId) async {
    final id = rawId.trim();
    if (id.isEmpty) return null;

    YugiCard? found;
    String baseId = id.replaceAll('_ar', '').replaceAll('_fl', '').replaceAll('_anime', '').trim();
    String normalizedBaseId = _normalizeId(baseId);
    
    // 1. Local Cache
    found = _findInLocalCache(normalizedBaseId);
    
    // 2. Metadata
    if (found == null) {
      final allDiscovered = [..._discoveredArabicCards, ..._discoveredFLCards];
      found = allDiscovered.firstWhereOrNull((c) {
          final cid = c.id.trim();
          if (cid == id) return true;
          String cBase = _normalizeId(cid.replaceAll('_ar', '').replaceAll('_fl', '').replaceAll('_anime', ''));
          return cBase == normalizedBaseId && cid.contains(id.contains('_') ? id.split('_').last : '');
      });
    }

    if (found != null) {
      return YugiCard(
        id: id,
        name: found.name,
        type: found.type,
        frameType: found.frameType,
        desc: found.desc,
        atk: found.atk, def: found.def, level: found.level,
        race: found.race, attribute: found.attribute, archetype: found.archetype,
        dbImageUrl: found.dbImageUrl, price: found.price,
      );
    }

    // 3. Supabase
    String numericIdStr = id.replaceAll(RegExp(r'[^0-9]'), '');
    if (numericIdStr.isNotEmpty) {
      try {
        final resp = await _client.from('cards').select().eq('id', numericIdStr).maybeSingle();
        if (resp != null) return YugiCard.fromJson(resp);
      } catch (_) {}
    }
    
    return null;
  }

  Future<List<YugiCard>> getCardsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    await initCache();
    
    // جلب البيانات بشكل فريد أولاً لتحسين الأداء
    final uniqueIds = ids.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet().toList();
    final Map<String, YugiCard> cardsMap = {};
    
    for (var id in uniqueIds) {
      final card = await _getSingleCardInternal(id);
      if (card != null) cardsMap[id] = card;
    }
    
    // بناء القائمة النهائية بنفس طول وترتيب الـ ids الأصلية (بما في ذلك التكرار)
    List<YugiCard> results = [];
    for (var rawId in ids) {
      final id = rawId.trim();
      YugiCard? found = cardsMap[id];
      
      if (found != null) {
        results.add(found);
      } else {
        // Placeholder لضمان ثبات عدد القائمة
        results.add(YugiCard(
          id: id,
          name: "كارت #$id",
          type: "Unknown",
          frameType: "English",
          desc: "بيانات هذا الكارت جاري تحديثها...",
          price: 5.0,
        ));
      }
    }
    return results;
  }

  Map<String, int> getStyleCounts() {
    if (_localCache == null) return {};
    return {
      'English': _localCache!.where((c) => !c.id.endsWith('_ar') && !c.id.endsWith('_fl')).length,
      'Anime': _localCache!.length,
      'Arabic': _discoveredArabicCards.length,
      'Frame Less': _discoveredFLCards.length,
    };
  }

  int get defaultPageSize => 20;
}

final cardRepositoryProvider = Provider((ref) {
  final repo = CardRepository(ref.watch(supabaseClientProvider), JsonImportService());
  repo.initCache(); 
  return repo;
});

final cardCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final repo = ref.watch(cardRepositoryProvider);
  await repo.initCache();
  return repo.getStyleCounts();
});

class CardSearchNotifier extends StateNotifier<AsyncValue<List<YugiCard>>> {
  final CardRepository _repo;
  final CardSearchParams _params;
  int _currentPage = 0;
  bool _hasMore = true;
  bool _isLoading = false;

  CardSearchNotifier(this._repo, this._params) : super(const AsyncValue.loading()) {
    fetchNextPage();
  }

  Future<void> fetchNextPage() async {
    if (!_hasMore || _isLoading) return;
    _isLoading = true;
    try {
      final newCards = await _repo.searchCards(
        query: _params.query,
        type: _params.type,
        attribute: _params.attribute,
        style: _params.style,
        archetype: _params.archetype,
        page: _currentPage,
      );
      if (newCards.length < _repo.defaultPageSize) _hasMore = false;
      final currentCards = state.value ?? [];
      state = AsyncValue.data([...currentCards, ...newCards]);
      _currentPage++;
    } catch (e, st) {
      if (_currentPage == 0) state = AsyncValue.error(e, st);
    } finally {
      _isLoading = false;
    }
  }
}

final paginatedCardSearchProvider = StateNotifierProvider.family<CardSearchNotifier, AsyncValue<List<YugiCard>>, CardSearchParams>((ref, params) {
  return CardSearchNotifier(ref.watch(cardRepositoryProvider), params);
});

final singleCardProvider = FutureProvider.family<YugiCard?, String>((ref, id) async {
  try {
    final repo = ref.watch(cardRepositoryProvider);
    final results = await repo.getCardsByIds([id]);
    return results.isNotEmpty ? results.first : null;
  } catch (e) { return null; }
});

final deckCardsProvider = FutureProvider.family<List<YugiCard>, String>((ref, idsString) async {
  if (idsString.isEmpty) return [];
  final ids = idsString.split(',').map((e) => e.trim()).where((id) => id.isNotEmpty).toList();
  return ref.watch(cardRepositoryProvider).getCardsByIds(ids);
});
