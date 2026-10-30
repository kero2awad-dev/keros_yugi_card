import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/card_model.dart';
import '../../data/repositories/card_repository.dart';

class FavoritesRepository {
  static const String _storageKey = 'yugi_local_favorites';
  final Ref _ref;

  FavoritesRepository(this._ref);

  Future<List<String>> _getFavoriteIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_storageKey) ?? [];
  }

  Future<List<YugiCard>> getMyFavorites() async {
    try {
      final ids = await _getFavoriteIds();
      if (ids.isEmpty) return [];
      
      final repo = _ref.read(cardRepositoryProvider);
      return await repo.getCardsByIds(ids);
    } catch (e) {
      debugPrint("Error loading favorites: $e");
      return [];
    }
  }

  Future<void> toggleFavorite(String cardId) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> ids = prefs.getStringList(_storageKey) ?? [];
    
    if (ids.contains(cardId)) {
      ids.remove(cardId);
    } else {
      ids.add(cardId);
    }
    
    await prefs.setStringList(_storageKey, ids);
  }

  Future<bool> isFavorite(String cardId) async {
    final ids = await _getFavoriteIds();
    return ids.contains(cardId);
  }
}

final favoritesRepositoryProvider = Provider((ref) => FavoritesRepository(ref));

final myFavoritesProvider = FutureProvider<List<YugiCard>>((ref) async {
  return ref.watch(favoritesRepositoryProvider).getMyFavorites();
});

final isFavoriteProvider = FutureProvider.family<bool, String>((ref, cardId) async {
  return ref.watch(favoritesRepositoryProvider).isFavorite(cardId);
});
