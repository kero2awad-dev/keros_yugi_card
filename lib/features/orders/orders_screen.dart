import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../app/theme.dart';
import '../../data/models/order_model.dart';
import 'orders_repository.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(myOrdersProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      appBar: AppBar(
        title: const Text("تاريخ الطلبات"),
        centerTitle: true,
      ),
      body: ordersAsync.when(
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: Colors.grey),
                  SizedBox(height: 20),
                  Text(
                    "ليس لديك طلبات سابقة بعد",
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return _OrderCard(order: order);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold)),
        error: (err, stack) => Center(child: Text("خطأ: $err")),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final YugiOrder order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy/MM/dd HH:mm').format(order.createdAt);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: AppTheme.cardGrey,
      child: ExpansionTile(
        title: Text(
          "طلب رقم: ${order.id.substring(0, 8)}",
          style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateStr, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 4),
            _StatusChip(status: order.status),
          ],
        ),
        trailing: Text(
          "${order.totalAmount} EGP",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          const Divider(color: Colors.white12),
          ...order.items.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(item.collectionName ?? "مجموعة", style: const TextStyle(color: Colors.white70)),
                Text("${item.quantity} x ${item.price} EGP", style: const TextStyle(color: Colors.white54)),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final OrderStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    
    switch (status) {
      case OrderStatus.pending:
        color = Colors.orange;
        label = "قيد الانتظار";
        break;
      case OrderStatus.confirmed:
        color = Colors.blue;
        label = "تم التأكيد";
        break;
      case OrderStatus.preparing:
        color = Colors.purple;
        label = "جاري التجهيز";
        break;
      case OrderStatus.shipped:
        color = Colors.cyan;
        label = "تم الشحن";
        break;
      case OrderStatus.completed:
        color = Colors.green;
        label = "مكتمل";
        break;
      case OrderStatus.cancelled:
        color = Colors.red;
        label = "ملغي";
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
