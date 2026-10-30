import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/supabase_service.dart';
import '../../data/models/collection_model.dart';
import '../../data/repositories/card_repository.dart';

class ReadyDecksRepository {
  final SupabaseClient _client;
  final Ref _ref;

  ReadyDecksRepository(this._client, this._ref);

  Future<List<ReadyDeck>> getReadyDecks() async {
    try {
      final response = await _client.from('ready_decks').select();
      return (response as List).map((json) => ReadyDeck.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> updateDeckStyle(String id, String newStyle) async {
    await _client.from('ready_decks').update({'style': newStyle}).eq('id', id);
  }

  Future<void> updateDeckContent(String id, List<String> cardIds) async {
    await _client.from('ready_decks').update({'card_ids': cardIds}).eq('id', id);
  }

  Future<void> updateDeckPrice(String id, double newPrice) async {
    await _client.from('ready_decks').update({'price': newPrice}).eq('id', id);
  }

  // الدالة التي كانت تسبب الخطأ - تمت إضافة البارامتر order بشكل صريح
  Future<void> addCardToReadyDeck(String deckId, String cardId, {String order = 'end'}) async {
    final response = await _client.from('ready_decks').select('card_ids').eq('id', deckId).single();
    final List<String> currentIds = List<String>.from(response['card_ids'] ?? []);
    
    if (order == 'start') {
      currentIds.insert(0, cardId);
    } else if (order == 'sort') {
      currentIds.add(cardId);
      currentIds.sort();
    } else {
      currentIds.add(cardId);
    }

    await updateDeckContent(deckId, currentIds);
  }

  Future<void> sortDeckAlphabetically(String deckId) async {
    final response = await _client.from('ready_decks').select('card_ids').eq('id', deckId).single();
    final List<String> ids = List<String>.from(response['card_ids'] ?? []);
    final cardRepo = _ref.read(cardRepositoryProvider);
    final cards = await cardRepo.getCardsByIds(ids);
    Map<String, String> idToName = {for (var c in cards) c.id: c.name};
    ids.sort((a, b) => (idToName[a] ?? a).compareTo(idToName[b] ?? b));
    await updateDeckContent(deckId, ids);
  }

  Future<void> sortDeckById(String deckId) async {
    final response = await _client.from('ready_decks').select('card_ids').eq('id', deckId).single();
    final List<String> ids = List<String>.from(response['card_ids'] ?? []);
    ids.sort();
    await updateDeckContent(deckId, ids);
  }

  Future<void> reverseDeck(String deckId) async {
    final response = await _client.from('ready_decks').select('card_ids').eq('id', deckId).single();
    final List<String> ids = List<String>.from(response['card_ids'] ?? []).reversed.toList();
    await updateDeckContent(deckId, ids);
  }

  Future<void> deleteDeck(String deckId) async {
    await _client.from('ready_decks').delete().eq('id', deckId);
  }
}

final readyDecksRepositoryProvider = Provider((ref) => ReadyDecksRepository(
  ref.watch(supabaseClientProvider),
  ref,
));

final readyDecksProvider = FutureProvider<List<ReadyDeck>>((ref) async {
  return ref.watch(readyDecksRepositoryProvider).getReadyDecks();
});
