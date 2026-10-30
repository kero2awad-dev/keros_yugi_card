import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:collection/collection.dart';
import '../../data/models/collection_model.dart';
import '../../data/models/card_model.dart';
import '../../data/repositories/card_repository.dart';
import '../orders/orders_repository.dart';
import '../auth/auth_repository.dart';
import '../../core/utils/download_helper.dart';

class CollectionsRepository {
  static const String _storageKey = 'yugi_local_collections';
  final Ref _ref;

  CollectionsRepository(this._ref);

  Future<List<YugiCollection>> getMyCollections() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); 
      final String? collectionsJson = prefs.getString(_storageKey);
      if (collectionsJson == null) return [];
      
      final List<dynamic> decoded = json.decode(collectionsJson);
      final collections = decoded.map((item) => YugiCollection.fromJson(item)).toList();
      
      collections.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return collections;
    } catch (e) {
      debugPrint("❌ Error loading collections: $e");
      return [];
    }
  }

  Future<void> _saveCollections(List<YugiCollection> collections) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String data = json.encode(collections.map((e) => e.toJson()).toList());
      await prefs.setString(_storageKey, data);
    } catch (e) {
      debugPrint("❌ Error saving collections: $e");
    }
  }

  String _getFinalId(String id, String style) {
    String cleanId = id.trim().split('_').first;
    String s = style.toLowerCase();
    if (s.contains('arabic')) return "${cleanId}_ar";
    if (s.contains('anime')) return "${cleanId}_anime";
    if (s.contains('frame less') || s.contains('fl')) return "${cleanId}_fl";
    return cleanId;
  }

  // ميزة تحميل IDs المجموعات كملف نصي
  Future<void> downloadCollectionAsText(YugiCollection collection) async {
    StringBuffer sb = StringBuffer();
    for (var item in collection.items) {
      // كتابة المعرف باللاحقة المناسبة حسب الستايل
      String finalId = _getFinalId(item.cardId, item.addedStyle);
      for (int i = 0; i < item.quantity; i++) {
        sb.writeln(finalId);
      }
    }
    
    final bytes = utf8.encode(sb.toString());
    final fileName = "${collection.name.replaceAll(' ', '_')}_IDs.txt";
    
    await downloadWebFile(Uint8List.fromList(bytes), fileName);
  }

  // 1. إنشاء مجموعة من نص (IDs)
  Future<YugiCollection> createCollectionFromText(String name, String style, String idsText) async {
    final List<String> ids = idsText.split(RegExp(r'[\n, ]'))
        .map((l) => l.trim())
        .where((l) => RegExp(r'^\d+$').hasMatch(l))
        .toList();

    final List<YugiCollection> collections = await getMyCollections();
    final items = ids.map((id) => CollectionItem(
      id: const Uuid().v4(),
      cardId: _getFinalId(id, style),
      quantity: 1,
      addedStyle: style,
    )).toList();

    final newColl = YugiCollection(
      id: const Uuid().v4(), 
      userId: 'local', 
      name: name, 
      style: style, 
      createdAt: DateTime.now(), 
      items: items
    );
    
    collections.insert(0, newColl);
    await _saveCollections(collections);
    return newColl;
  }

  // 2. إضافة كروت لمجموعة موجودة من نص ملصوق
  Future<void> addCardsToCollectionFromText(String collectionId, String style, String idsText) async {
    final List<String> ids = idsText.split(RegExp(r'[\n, ]'))
        .map((l) => l.trim())
        .where((l) => RegExp(r'^\d+$').hasMatch(l))
        .toList();

    final List<YugiCollection> collections = await getMyCollections();
    final idx = collections.indexWhere((c) => c.id == collectionId);
    if (idx != -1) {
      final updatedItems = List<CollectionItem>.from(collections[idx].items);
      for (var id in ids) {
        updatedItems.add(CollectionItem(
          id: const Uuid().v4(),
          cardId: _getFinalId(id, style),
          quantity: 1,
          addedStyle: style,
        ));
      }
      collections[idx] = collections[idx].copyWith(items: updatedItems);
      await _saveCollections(collections);
    }
  }

  // 3. استيراد ملف YDK
  Future<YugiCollection?> createCollectionFromYdkFile(String name, String style) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: kIsWeb ? FileType.custom : FileType.any,
        allowedExtensions: kIsWeb ? ['ydk'] : null,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        String content = "";
        
        if (file.bytes != null) {
          content = utf8.decode(file.bytes!);
        }

        final List<String> ids = [];
        for (var line in content.split('\n')) {
          final t = line.trim().replaceAll('\r', '');
          if (t.isNotEmpty && !t.startsWith('#') && !t.startsWith('!') && RegExp(r'^\d+$').hasMatch(t)) {
            ids.add(t);
          }
        }

        if (ids.isEmpty) return null;
        return await createCollectionFromText(name, style, ids.join('\n'));
      }
    } catch (e) {
      debugPrint("❌ Error importing YDK: $e");
    }
    return null;
  }

  Future<YugiCollection> createCollection(String name, String style) async {
    final List<YugiCollection> collections = await getMyCollections();
    final newColl = YugiCollection(id: const Uuid().v4(), userId: 'local', name: name, style: style, createdAt: DateTime.now(), items: []);
    collections.insert(0, newColl);
    await _saveCollections(collections);
    return newColl;
  }

  Future<void> deleteCollection(String id) async {
    final collections = await getMyCollections();
    collections.removeWhere((c) => c.id == id);
    await _saveCollections(collections);
  }

  Future<void> updateCardQuantity(String collectionId, String itemId, int newQuantity) async {
    final collections = await getMyCollections();
    final idx = collections.indexWhere((c) => c.id == collectionId);
    if (idx != -1) {
      final items = List<CollectionItem>.from(collections[idx].items);
      final itemIdx = items.indexWhere((i) => i.id == itemId);
      if (itemIdx != -1) {
        items[itemIdx] = CollectionItem(
          id: items[itemIdx].id, 
          cardId: items[itemIdx].cardId, 
          quantity: newQuantity, 
          addedStyle: items[itemIdx].addedStyle
        );
        collections[idx] = collections[idx].copyWith(items: items);
        await _saveCollections(collections);
      }
    }
  }

  Future<void> removeCardFromCollection(String collectionId, String itemId) async {
    final collections = await getMyCollections();
    final idx = collections.indexWhere((c) => c.id == collectionId);
    if (idx != -1) {
      final items = collections[idx].items.where((i) => i.id != itemId).toList();
      collections[idx] = collections[idx].copyWith(items: items);
      await _saveCollections(collections);
    }
  }

  Future<String?> addCardToCollection({required String collectionId, required String cardId, required String style, int quantity = 1}) async {
    final collections = await getMyCollections();
    final idx = collections.indexWhere((c) => c.id == collectionId);
    if (idx == -1) return "Error";
    final items = List<CollectionItem>.from(collections[idx].items);
    final finalCardId = _getFinalId(cardId, style);
    items.add(CollectionItem(id: const Uuid().v4(), cardId: finalCardId, quantity: quantity, addedStyle: style));
    collections[idx] = collections[idx].copyWith(items: items);
    await _saveCollections(collections);
    return null;
  }

  // --- دوال الترتيب ---
  Future<void> sortCollectionAlphabetically(String collectionId) async {
    final collections = await getMyCollections();
    final cIndex = collections.indexWhere((c) => c.id == collectionId);
    if (cIndex != -1) {
      final items = List<CollectionItem>.from(collections[cIndex].items);
      final cardRepo = _ref.read(cardRepositoryProvider);
      final cards = await cardRepo.getCardsByIds(items.map((e) => e.cardId).toList());
      
      items.sort((a, b) {
        final nameA = cards.firstWhereOrNull((c) => c.id == a.cardId)?.name ?? "";
        final nameB = cards.firstWhereOrNull((c) => c.id == b.cardId)?.name ?? "";
        return nameA.compareTo(nameB);
      });
      
      collections[cIndex] = collections[cIndex].copyWith(items: items);
      await _saveCollections(collections);
    }
  }

  Future<void> sortCollectionById(String collectionId) async {
    final collections = await getMyCollections();
    final cIndex = collections.indexWhere((c) => c.id == collectionId);
    if (cIndex != -1) {
      final items = List<CollectionItem>.from(collections[cIndex].items);
      items.sort((a, b) => a.cardId.compareTo(b.cardId));
      collections[cIndex] = collections[cIndex].copyWith(items: items);
      await _saveCollections(collections);
    }
  }

  Future<void> reverseCollection(String collectionId) async {
    final collections = await getMyCollections();
    final cIndex = collections.indexWhere((c) => c.id == collectionId);
    if (cIndex != -1) {
      final items = List<CollectionItem>.from(collections[cIndex].items).reversed.toList();
      collections[cIndex] = collections[cIndex].copyWith(items: items);
      await _saveCollections(collections);
    }
  }

  Future<YugiCollection> createCollectionFromReadyDeck(ReadyDeck deck, {required String targetStyle}) async {
    final collections = await getMyCollections();
    final items = deck.cardIds.map((id) => CollectionItem(
      id: const Uuid().v4(), 
      cardId: _getFinalId(id.split('_').first, targetStyle),
      quantity: 1, 
      addedStyle: targetStyle
    )).toList();

    final newColl = YugiCollection(id: const Uuid().v4(), userId: 'local', name: "${deck.name} ($targetStyle)", style: targetStyle, createdAt: DateTime.now(), items: items);
    collections.insert(0, newColl);
    await _saveCollections(collections);
    return newColl;
  }

  Future<void> shareToWhatsApp(YugiCollection collection) async {
    final repo = _ref.read(cardRepositoryProvider);
    final user = _ref.read(currentUserProvider);
    final cards = await repo.getCardsByIds(collection.items.map((e) => e.cardId).toList());
    
    // 1. تسجيل الأوردر في قاعدة البيانات
    String orderId = "Order";
    try {
      final List<Map<String, dynamic>> cardsData = [];
      for (var item in collection.items) {
        final card = cards.firstWhereOrNull((c) => c.id == item.cardId);
        cardsData.add({
          'id': item.cardId,
          'name': card?.name ?? "كارت",
          'style': item.addedStyle,
          'quantity': item.quantity,
        });
      }

      final itemsData = [{
        'name': collection.name,
        'quantity': 1,
        'price': 350.0, 
        'cards': cardsData,
      }];

      orderId = await _ref.read(ordersRepositoryProvider).createOrder(350.0, itemsData);
    } catch (e) {
      debugPrint("❌ DB Save Error for Local Collection: $e");
    }

    // 2. إرسال الرسالة للواتساب
    String msg = "🃏 طلب أوردر كروت يوغي 🃏\n";
    msg += "👤 العميل: ${user?.email ?? 'ضيف'}\n";
    msg += "🆔 رقم الطلب: #${orderId.substring(0, 8).toUpperCase()}\n";
    msg += "📦 المجموعة: ${collection.name}\n\n";
    for (var item in collection.items) {
      final name = cards.firstWhereOrNull((c) => c.id == item.cardId)?.name ?? "كارت";
      // التأكد من طباعة المعرف النهائي (الذي يحتوي على اللاحقة)
      msg += "• $name (${item.cardId}) x${item.quantity}\n";
    }
    
    final url = "https://wa.me/201270448835?text=${Uri.encodeComponent(msg)}";
    if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

final collectionsRepositoryProvider = Provider((ref) => CollectionsRepository(ref));
final myCollectionsProvider = FutureProvider<List<YugiCollection>>((ref) => ref.watch(collectionsRepositoryProvider).getMyCollections());
final collectionCardsProvider = FutureProvider.family<List<YugiCard>, String>((ref, id) async {
  final colls = await ref.watch(myCollectionsProvider.future);
  final coll = colls.firstWhere((c) => c.id == id);
  return ref.watch(cardRepositoryProvider).getCardsByIds(coll.items.map((e) => e.cardId).toList());
});
