import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../app/theme.dart';
import 'admin_repository.dart';

class OrdersManagementScreen extends ConsumerStatefulWidget {
  const OrdersManagementScreen({super.key});

  @override
  ConsumerState<OrdersManagementScreen> createState() => _OrdersManagementScreenState();
}

class _OrdersManagementScreenState extends ConsumerState<OrdersManagementScreen> {
  String _filterStatus = 'all';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(allOrdersProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      appBar: AppBar(
        title: const Text("إدارة الطلبات"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
            tooltip: "حذف جميع الطلبات",
            onPressed: () => _confirmDeleteAll(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(allOrdersProvider),
          )
        ],
      ),
      body: Column(
        children: [
          _buildStats(ordersAsync),
          _buildFilters(),
          Expanded(
            child: ordersAsync.when(
              data: (orders) {
                var filtered = orders;
                if (_filterStatus != 'all') {
                  filtered = filtered.where((o) => o['status'] == _filterStatus).toList();
                }
                if (_searchQuery.isNotEmpty) {
                  filtered = filtered.where((o) => 
                    (o['user_email'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    o['id'].toString().contains(_searchQuery)
                  ).toList();
                }

                if (filtered.isEmpty) {
                  return const Center(child: Text("لا توجد طلبات تطابق الفلتر", style: TextStyle(color: Colors.white24)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _OrderCard(order: filtered[index]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold)),
              error: (e, _) => Center(child: Text("خطأ: $e", style: const TextStyle(color: Colors.red))),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAll(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppTheme.cardGrey,
        title: const Text("حذف كل الطلبات؟", style: TextStyle(color: Colors.redAccent)),
        content: const Text("هذا الإجراء سيقوم بمسح كافة الطلبات من قاعدة البيانات نهائياً. هل أنت متأكد؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("إلغاء")),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("حذف الكل الآن"),
          )
        ],
      ),
    );

    if (ok == true) {
      await ref.read(adminRepositoryProvider).deleteAllOrders();
      ref.invalidate(allOrdersProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ تم مسح جميع الطلبات")));
    }
  }

  Widget _buildStats(AsyncValue<List<Map<String, dynamic>>> ordersAsync) {
    return ordersAsync.maybeWhen(
      data: (orders) {
        final pending = orders.where((o) => o['status'] == 'pending' || o['status'] == 'preparing').length;
        final completed = orders.where((o) => o['status'] == 'completed').length;
        return Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _statItem("قيد التنفيذ", pending.toString(), Colors.orange),
              const SizedBox(width: 10),
              _statItem("مكتمل", completed.toString(), Colors.green),
              const SizedBox(width: 10),
              _statItem("الإجمالي", orders.length.toString(), AppTheme.primaryGold),
            ],
          ),
        );
      },
      orElse: () => const SizedBox(),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip("الكل", 'all'),
            _filterChip("قيد الانتظار", 'pending'),
            _filterChip("قيد التحضير", 'preparing'),
            _filterChip("تم الشحن", 'shipped'),
            _filterChip("مكتمل", 'completed'),
            _filterChip("ملغي", 'cancelled'),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String status) {
    final isSelected = _filterStatus == status;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 11)),
        selected: isSelected,
        selectedColor: AppTheme.primaryGold,
        backgroundColor: AppTheme.cardGrey,
        onSelected: (val) { if (val) setState(() => _filterStatus = status); },
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  final Map<String, dynamic> order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = order['order_items'] as List? ?? [];
    final orderId = order['id'].toString().substring(0, 8).toUpperCase();
    final status = order['status'] ?? 'pending';
    final date = order['created_at'] != null ? DateFormat('yyyy/MM/dd HH:mm').format(DateTime.parse(order['created_at'])) : '';

    return Card(
      color: AppTheme.cardGrey,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        title: Row(
          children: [
            Text("#$orderId", style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
            const SizedBox(width: 10),
            _statusBadge(status),
          ],
        ),
        subtitle: Text("${order['user_email'] ?? 'ضيف'}\n$date", style: const TextStyle(color: Colors.white54, fontSize: 11)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.text_snippet_outlined, color: Colors.blueAccent),
              onPressed: () => ref.read(adminRepositoryProvider).downloadOrderIdsAsText(List<Map<String, dynamic>>.from(items), orderId),
            ),
            IconButton(
              icon: const Icon(Icons.download_for_offline, color: Colors.green),
              onPressed: () => _downloadImages(context, ref, items, orderId),
            ),
          ],
        ),
        children: [
          const Divider(color: Colors.white10),
          ...items.map((it) => ListTile(
            title: Text(it['collection_name'] ?? "مجموعة", style: const TextStyle(color: Colors.white, fontSize: 13)),
            subtitle: Text("${it['quantity']} باكت | ${(it['card_details'] as List?)?.length ?? 0} كارت", style: const TextStyle(color: Colors.white24, fontSize: 11)),
          )),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _actionBtn(context, "تحديث الحالة", Icons.edit, Colors.blue, () => _updateStatus(context, ref)),
                _actionBtn(context, "حذف الطلب", Icons.delete, Colors.redAccent, () => _deleteOrder(context, ref)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _actionBtn(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: color, size: 18),
      label: Text(label, style: TextStyle(color: color, fontSize: 12)),
    );
  }

  Future<void> _downloadImages(BuildContext context, WidgetRef ref, List items, String id) async {
    final List<Map<String, dynamic>> allCards = [];
    for (var item in items) {
      final details = item['card_details'] as List? ?? [];
      allCards.addAll(List<Map<String, dynamic>>.from(details));
    }
    await ref.read(adminRepositoryProvider).prepareOrderImagesZip(allCards);
  }

  Future<void> _updateStatus(BuildContext context, WidgetRef ref) async {
    final List<String> statuses = ['pending', 'preparing', 'shipped', 'completed', 'cancelled'];
    final newStatus = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        backgroundColor: AppTheme.cardGrey,
        title: const Text("تحديث الحالة"),
        children: statuses.map((s) => SimpleDialogOption(
          onPressed: () => Navigator.pop(c, s),
          child: Text(s.toUpperCase()),
        )).toList(),
      ),
    );
    if (newStatus != null) {
      await ref.read(adminRepositoryProvider).updateOrderStatus(order['id'], newStatus);
      ref.invalidate(allOrdersProvider);
    }
  }

  Future<void> _deleteOrder(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(backgroundColor: AppTheme.cardGrey, title: const Text("حذف؟"), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("إلغاء")), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("حذف"))]));
    if (ok == true) {
      await ref.read(adminRepositoryProvider).deleteOrder(order['id']);
      ref.invalidate(allOrdersProvider);
    }
  }

  Widget _statusBadge(String status) {
    Color color = Colors.grey;
    if (status == 'pending') color = Colors.orange;
    else if (status == 'preparing') color = Colors.blue;
    else if (status == 'shipped') color = Colors.purple;
    else if (status == 'completed') color = Colors.green;
    else if (status == 'cancelled') color = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.5))),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }
}
