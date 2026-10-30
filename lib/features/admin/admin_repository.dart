import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import '../../core/services/supabase_service.dart';
import '../../core/services/json_import_service.dart';
import '../../data/models/card_model.dart';
import 'package:uuid/uuid.dart';
import '../../core/utils/download_helper.dart';

class AdminRepository {
  final SupabaseClient _client;
  final JsonImportService _jsonService;

  AdminRepository(this._client, this._jsonService);

  // دالة حقن الـ DPI (300) - تم استخدام الأوفست 11-15 لضمان قراءة الفوتوشوب الصحيحة (6.49 * 9.29 سم)
  Uint8List _setJpgDpi(Uint8List bytes, int dpi) {
    final List<int> patched = List<int>.from(bytes);
    // البحث عن JFIF APP0 marker (FF E0)
    for (int i = 0; i < patched.length - 17; i++) {
      if (patched[i] == 0xFF && patched[i + 1] == 0xE0 &&
          patched[i + 4] == 0x4A && patched[i + 5] == 0x46 && 
          patched[i + 6] == 0x49 && patched[i + 7] == 0x46) {
        
        patched[i + 11] = 1; // Units: 1 = dots per inch (DPI)
        patched[i + 12] = (dpi >> 8) & 0xFF; // Xdensity High
        patched[i + 13] = dpi & 0xFF;        // Xdensity Low
        patched[i + 14] = (dpi >> 8) & 0xFF; // Ydensity High
        patched[i + 15] = dpi & 0xFF;        // Ydensity Low
        break; 
      }
    }
    return Uint8List.fromList(patched);
  }

  // ميزة جديدة للأدمن: تحميل جميع IDs الأوردر في ملف نصي واحد
  Future<void> downloadOrderIdsAsText(List<Map<String, dynamic>> orderItems, String orderName) async {
    StringBuffer sb = StringBuffer();
    
    for (var item in orderItems) {
      final int packQty = int.tryParse((item['quantity'] ?? 1).toString()) ?? 1;
      final details = item['card_details'] ?? item['cards'] ?? item['items'] ?? item['collection_items'];
      
      if (details != null && details is List) {
        for (int q = 0; q < packQty; q++) {
          for (var card in details) {
            if (card is Map) {
              final String id = (card['card_id'] ?? card['id'] ?? '').toString();
              final String style = (card['style'] ?? card['added_style'] ?? 'English').toString();
              final int cardQty = int.tryParse((card['quantity'] ?? 1).toString()) ?? 1;
              
              String finalId = _getFinalIdWithSuffix(id, style);
              for (int cIdx = 0; cIdx < cardQty; cIdx++) {
                sb.writeln(finalId);
              }
            }
          }
        }
      }
    }

    if (sb.isEmpty) return;
    
    final bytes = utf8.encode(sb.toString());
    final fileName = "Order_${orderName.replaceAll(' ', '_')}_IDs.txt";
    await downloadWebFile(Uint8List.fromList(bytes), fileName);
  }

  String _getFinalIdWithSuffix(String id, String style) {
    String cleanId = id.trim().split('_').first;
    String s = style.toLowerCase();
    if (s.contains('arabic')) return "${cleanId}_ar";
    if (s.contains('anime')) return "${cleanId}_anime";
    if (s.contains('frame less') || s.contains('fl')) return "${cleanId}_fl";
    return cleanId;
  }

  Future<void> deleteOrder(String orderId) async {
    await _client.from('orders').delete().eq('id', orderId);
  }

  Future<void> deleteAllOrders() async {
    // حذف جميع الطلبات (يجب الحذر عند استخدامها)
    await _client.from('orders').delete().neq('id', '00000000-0000-0000-0000-000000000000');
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    await _client.from('orders').update({'status': newStatus}).eq('id', orderId);
  }

  Future<void> createManualOrder({
    required String customerName,
    required List<String> cardIds,
    required String style,
    double totalPrice = 350.0,
  }) async {
    final orderResponse = await _client.from('orders').insert({
      'total_amount': totalPrice,
      'status': 'manual',
      'user_id': _client.auth.currentUser?.id,
    }).select().single();

    final orderId = orderResponse['id'] as String;
    final List<YugiCard> allCards = await _jsonService.loadCardsFromAssets();
    final Map<String, String> cardNames = {for (var c in allCards) c.id.toString(): c.name};

    final Map<String, int> counts = {};
    for (var id in cardIds) { counts[id] = (counts[id] ?? 0) + 1; }

    final List<Map<String, dynamic>> cardDetails = counts.entries.map((e) => {
      'id': e.key,
      'name': cardNames[e.key] ?? 'Unknown',
      'style': style,
      'quantity': e.value,
    }).toList();

    await _client.from('order_items').insert({
      'order_id': orderId,
      'collection_name': customerName,
      'quantity': 1,
      'price': totalPrice,
      'card_details': cardDetails,
    });
  }

  Future<List<Map<String, dynamic>>> getAllOrders() async {
    try {
      final response = await _client.from('orders').select('*, order_items(*)').order('created_at', ascending: false);
      final List<Map<String, dynamic>> orders = List<Map<String, dynamic>>.from(response);
      final List<String> userIds = orders.map((o) => o['user_id']?.toString()).where((id) => id != null).cast<String>().toSet().toList();
      
      if (userIds.isNotEmpty) {
        try {
          final profilesRes = await _client.from('profiles').select('id, email, display_name').filter('id', 'in', userIds);
          final Map<String, dynamic> profileMap = { for (var p in profilesRes as List) p['id']: p };
          for (var order in orders) {
            final uid = order['user_id'];
            if (uid != null) {
              order['profiles'] = profileMap[uid];
              order['user_email'] = profileMap[uid]?['email'];
            } else {
              final items = order['order_items'] as List?;
              if (order['status'] == 'manual' && items != null && items.isNotEmpty) {
                order['user_email'] = items[0]['collection_name'];
              } else {
                order['user_email'] = 'طلب ضيف (Guest)';
              }
            }
          }
        } catch (_) {}
      }
      return orders;
    } catch (e) { throw Exception("فشل جلب الطلبات: $e"); }
  }

  Future<Uint8List?> prepareOrderImagesZip(List<Map<String, dynamic>> orderItems, {Function(int, int)? onProgress}) async {
    final archive = Archive();
    const int targetDpi = 300;
    const int animeWidth = 767;
    const int animeHeight = 1097;
    
    // 1. تجميع الكروت مع احترام تكرار الباكتات (Pack Qty) وتكرار الكروت (Card Qty)
    final List<Map<String, dynamic>> finalDownloadList = [];
    for (var item in orderItems) {
      final int packQty = int.tryParse((item['quantity'] ?? 1).toString()) ?? 1;
      final details = item['card_details'] ?? item['cards'] ?? item['items'] ?? item['collection_items'];
      
      if (details != null && details is List) {
        for (int q = 0; q < packQty; q++) {
          for (var card in details) {
            if (card is Map) {
              final int cardQty = int.tryParse((card['quantity'] ?? 1).toString()) ?? 1;
              for (int cIdx = 0; cIdx < cardQty; cIdx++) {
                finalDownloadList.add(Map<String, dynamic>.from(card));
              }
            }
          }
        }
      } else if (item.containsKey('id') || item.containsKey('card_id')) {
        for (int q = 0; q < packQty; q++) {
          finalDownloadList.add(Map<String, dynamic>.from(item));
        }
      }
    }

    if (finalDownloadList.isEmpty) return null;

    final client = http.Client();
    int fileCounter = 1; 
    try {
      for (int idx = 0; idx < finalDownloadList.length; idx++) {
        final card = finalDownloadList[idx];
        if (onProgress != null) onProgress(idx + 1, finalDownloadList.length);
        
        final String id = (card['card_id'] ?? card['id'] ?? '').toString();
        final String style = (card['style'] ?? card['added_style'] ?? 'English').toString();
        final String name = (card['name'] ?? id).toString().replaceAll(RegExp(r'[<>:"/\\|?*]'), ''); 
        
        if (id.isEmpty) continue;

        try {
          final imageUrl = YugiCard(id: id, name: name, type: '', frameType: 'English', desc: '').getStyledImageUrl(style);
          final response = await client.get(Uri.parse(imageUrl)).timeout(const Duration(seconds: 45));
          if (response.statusCode == 200) {
            Uint8List processedBytes;

            if (style.toLowerCase().contains('anime')) {
              final decodedImage = img.decodeImage(response.bodyBytes);
              if (decodedImage != null) {
                final resized = img.copyResize(decodedImage, width: animeWidth, height: animeHeight, interpolation: img.Interpolation.cubic);
                processedBytes = _setJpgDpi(Uint8List.fromList(img.encodeJpg(resized, quality: 98)), targetDpi);
              } else { continue; }
            } else {
              // العربي والإنجليزي والفريم ليس: حقن الـ DPI لضمان مقاس الفوتوشوب
              processedBytes = _setJpgDpi(response.bodyBytes, targetDpi);
            }

            final fileName = '${fileCounter.toString().padLeft(3, '0')}_${name}_${id}.jpg';
            archive.addFile(ArchiveFile('$style/$fileName', processedBytes.length, processedBytes));
            fileCounter++;
          }
        } catch (e) {
          debugPrint("❌ Error processing card $id: $e");
        }
      }
    } finally {
      client.close();
    }
    
    if (archive.isEmpty) return null;
    final encodedZip = ZipEncoder().encode(archive, level: Deflate.BEST_SPEED);
    return encodedZip != null ? Uint8List.fromList(encodedZip) : null;
  }

  Future<void> uploadAllCardsToSupabase(Function(int progress, int total) onProgress) async {
    try {
      final cards = await _jsonService.loadCardsFromAssets();
      for (var i = 0; i < cards.length; i += 50) {
        final end = (i + 50 < cards.length) ? i + 50 : cards.length;
        final batch = cards.sublist(i, end).map((c) => { 'id': c.id, 'name': c.name, 'type': c.type, 'frame_type': c.frameType, 'description': c.desc, 'image_url': c.dbImageUrl, 'price': c.price }).toList();
        await _client.from('cards').upsert(batch);
        onProgress(end, cards.length);
      }
    } catch (_) {}
  }

  Future<int> importYdkDecksFromAssets() async {
    int count = 0;
    try {
      final List<YugiCard> allCards = await _jsonService.loadCardsFromAssets();
      final Map<String, YugiCard> cardLookup = {for (var card in allCards) card.id.toString(): card};
      final List<String> ydkFiles = ["yugi muto-ready", "marik", "kaiba-ready", "joey", "jaden_yuki", "d-d-d", "DARK MAGIC-ready", "small egy god-ready", "EXODIA-ready", "blue_eyes_saga"];
      for (final fileName in ydkFiles) {
        try {
          final content = await rootBundle.loadString('assets/data/$fileName.ydk');
          final List<String> validatedIds = [];
          for (var line in content.split('\n')) {
            final t = line.trim();
            if (t.isNotEmpty && !t.startsWith('#') && !t.startsWith('!') && cardLookup.containsKey(t)) validatedIds.add(t);
          }
          if (validatedIds.isNotEmpty) {
            await _client.from('ready_decks').insert({ 'id': const Uuid().v4(), 'name': fileName, 'card_ids': validatedIds, 'price': 350.0, 'style': 'English' });
            count++;
          }
        } catch (_) {}
      }
      return count;
    } catch (_) { return 0; }
  }

  Future<void> deleteAllReadyDecks() async { await _client.from('ready_decks').delete().neq('id', '00000000-0000-0000-0000-000000000000'); }
}

final adminRepositoryProvider = Provider((ref) => AdminRepository(ref.watch(supabaseClientProvider), JsonImportService()));
final allOrdersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async => ref.watch(adminRepositoryProvider).getAllOrders());
