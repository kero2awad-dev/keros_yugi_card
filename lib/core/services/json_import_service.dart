import 'dart:convert';
import 'package:flutter/services.dart';
import '../../data/models/card_model.dart';

class JsonImportService {
  static const String assetPath = 'assets/data/cardinfo.json';

  Future<List<YugiCard>> loadCardsFromAssets() async {
    try {
      final String response = await rootBundle.loadString(assetPath);
      final data = json.decode(response);
      
      if (data is Map && data.containsKey('data')) {
        // Many YuGiOh JSONs (like YGOPRODeck) have a 'data' key
        return (data['data'] as List)
            .map((cardJson) => YugiCard.fromJson(cardJson))
            .toList();
      } else if (data is List) {
        return data.map((cardJson) => YugiCard.fromJson(cardJson)).toList();
      }
      return [];
    } catch (e) {
      print('Error loading cardinfo.json: $e');
      return [];
    }
  }
}
