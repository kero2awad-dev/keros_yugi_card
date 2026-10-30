import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../core/services/supabase_service.dart';
import '../../data/models/order_model.dart';

class OrdersRepository {
  final SupabaseClient _client;

  OrdersRepository(this._client);

  Future<List<YugiOrder>> getMyOrders() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _client
          .from('orders')
          .select('*, order_items(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List).map((json) => YugiOrder.fromJson(json)).toList();
    } catch (e) {
      debugPrint("Error fetching orders: $e");
      return [];
    }
  }

  Future<String> createOrder(double totalAmount, List<Map<String, dynamic>> items) async {
    final String? userId = _client.auth.currentUser?.id;
    
    try {
      final Map<String, dynamic> orderData = {
        'total_amount': totalAmount,
        'status': 'pending',
      };
      
      if (userId != null) {
        orderData['user_id'] = userId;
      }

      final orderResponse = await _client.from('orders').insert(orderData).select().single();
      final orderId = orderResponse['id'] as String;

      final orderItems = items.map((item) => {
        'order_id': orderId,
        'collection_name': item['name'],
        'quantity': item['quantity'],
        'price': item['price'],
        'card_details': item['cards'] ?? [], // حفظ تفاصيل الكروت بالكامل
      }).toList();

      await _client.from('order_items').insert(orderItems);
      return orderId;
    } catch (e) {
      debugPrint("❌ createOrder DB Error: $e");
      return "ORDER_${DateTime.now().millisecondsSinceEpoch}";
    }
  }
}

final ordersRepositoryProvider = Provider((ref) => OrdersRepository(ref.watch(supabaseClientProvider)));

final myOrdersProvider = FutureProvider<List<YugiOrder>>((ref) async {
  return ref.watch(ordersRepositoryProvider).getMyOrders();
});
