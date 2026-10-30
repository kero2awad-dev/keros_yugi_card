import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import '../orders/orders_repository.dart';
import '../../data/models/collection_model.dart';
import '../auth/auth_repository.dart';
import '../../data/repositories/card_repository.dart';
import '../../data/models/card_model.dart';
import 'package:collection/collection.dart';

class CartItem {
  final YugiCollection collection;
  int quantity;

  CartItem({required this.collection, this.quantity = 1});
}

class CartNotifier extends StateNotifier<List<CartItem>> {
  final Ref _ref;
  CartNotifier(this._ref) : super([]);

  void addCollection(YugiCollection collection) {
    final index = state.indexWhere((item) => item.collection.id == collection.id);
    if (index >= 0) {
      state[index].quantity++;
      state = [...state];
    } else {
      state = [...state, CartItem(collection: collection)];
    }
  }

  void removeCollection(String id) {
    state = state.where((item) => item.collection.id != id).toList();
  }

  void updateState() {
    state = [...state];
  }

  void clearCart() {
    state = [];
  }

  int get totalPacks {
    return state.fold(0, (sum, item) => sum + item.quantity);
  }

  double get totalPrice {
    int count = totalPacks;
    if (count > 1) {
      return count * 300.0;
    } else if (count == 1) {
      return 350.0;
    }
    return 0.0;
  }

  double get discountAmount {
    int count = totalPacks;
    if (count > 1) {
      return count * 50.0;
    }
    return 0.0;
  }

  Future<void> sendOrderToWhatsApp() async {
    if (state.isEmpty) return;

    final user = _ref.read(currentUserProvider);
    final cardRepo = _ref.read(cardRepositoryProvider);
    String orderId = "NewOrder";
    
    final List<Map<String, dynamic>> itemsData = [];
    
    for (var item in state) {
      final List<Map<String, dynamic>> cardsInCollection = [];
      for (var colItem in item.collection.items) {
        cardsInCollection.add({
          'id': colItem.cardId,
          'style': colItem.addedStyle,
          'quantity': colItem.quantity,
          'name': colItem.card?.name ?? "كارت",
        });
      }

      itemsData.add({
        'name': item.collection.name,
        'quantity': item.quantity,
        'price': totalPacks > 1 ? 300.0 : 350.0,
        'cards': cardsInCollection,
      });
    }

    try {
      orderId = await _ref.read(ordersRepositoryProvider).createOrder(totalPrice, itemsData);
      _ref.invalidate(myOrdersProvider);
    } catch (e) {
      debugPrint("DB Save Error: $e");
    }

    final phone = dotenv.env['WHATSAPP_BUSINESS_NUMBER'] ?? '201270448835';
    StringBuffer message = StringBuffer();
    message.writeln("🃏 *طلب جديد من كيرو يوغي* 🃏");
    message.writeln("👤 *العميل:* ${user?.email ?? 'ضيف'}");
    message.writeln("🆔 *رقم الطلب:* #${orderId.substring(0, 8).toUpperCase()}");
    message.writeln("----------------------------------");
    
    for (var item in state) {
      message.writeln("📦 *المجموعة:* ${item.collection.name}");
      message.writeln("🔢 *الكمية:* ${item.quantity}");
      message.writeln("🔹 *الستايل:* ${item.collection.style}");
      message.writeln("🃏 *محتويات المجموعة:*");
      
      final List<String> cardIds = item.collection.items.map((i) => i.cardId).toList();
      final cards = await cardRepo.getCardsByIds(cardIds);

      for (var colItem in item.collection.items) {
        final card = cards.firstWhereOrNull((c) => c.id == colItem.cardId);
        final name = card?.name ?? "كارت";
        
        String cleanId = colItem.cardId.split('_').first;
        String suffix = "";
        
        // تحسين منطق اللاحقة ليكون مرناً مع المسميات المختلفة
        String s = colItem.addedStyle.toLowerCase();
        if (s.contains('arabic')) suffix = "_ar";
        else if (s.contains('anime')) suffix = "_anime";
        else if (s.contains('frame less') || s.contains('fl')) suffix = "_fl";
        
        String finalId = cleanId + suffix;
        message.writeln("  • $name ($finalId) (x${colItem.quantity}) - ${colItem.addedStyle}");
      }
      message.writeln("----------------------------------");
    }
    
    if (discountAmount > 0) {
      message.writeln("🎁 *عرض خاص:* تم احتساب الباكت بـ 300ج");
      message.writeln("💰 *إجمالي الخصم:* -${discountAmount} EGP");
    }
    message.writeln("💰 *إجمالي النهائي:* ${totalPrice} EGP");

    final url = "https://wa.me/$phone?text=${Uri.encodeComponent(message.toString())}";
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      clearCart();
    }
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) => CartNotifier(ref));
