import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import 'cart_repository.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        context.go('/');
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundBlack,
        appBar: AppBar(
          title: const Text("سلة المشتريات"),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.primaryGold),
            onPressed: () => context.go('/'),
          ),
          actions: [
            if (cartItems.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                onPressed: () => cartNotifier.clearCart(),
              ),
          ],
        ),
        body: cartItems.isEmpty
            ? _buildEmptyCart()
            : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: cartItems.length,
                      itemBuilder: (context, index) {
                        final item = cartItems[index];
                        return _CartItemCard(item: item, notifier: cartNotifier);
                      },
                    ),
                  ),
                  _buildSummarySection(context, cartNotifier.totalPrice, cartNotifier.discountAmount, ref),
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyCart() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 100, color: Colors.white24),
          SizedBox(height: 20),
          Text("سلة طلباتك فارغة حالياً", style: TextStyle(color: Colors.white70, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildSummarySection(BuildContext context, double total, double discount, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardGrey,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (discount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("خصم العرض (2 باكت بـ 600ج)", style: TextStyle(color: Colors.green, fontSize: 16)),
                  Text("-${discount.toStringAsFixed(0)} EGP", style: const TextStyle(color: Colors.green, fontSize: 16)),
                ],
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("الإجمالي النهائي", style: TextStyle(color: Colors.white, fontSize: 18)),
              Text("${total.toStringAsFixed(0)} EGP", 
                style: const TextStyle(color: AppTheme.primaryGold, fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGold,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            onPressed: () => _showCheckoutDialog(context, ref),
            icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 20),
            label: const Text("تأكيد الطلب عبر واتساب", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showCheckoutDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundBlack,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_user, color: AppTheme.primaryGold, size: 60),
            const SizedBox(height: 20),
            const Text("مراجعة الطلب النهائية", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            const Text(
              "سيتم فتح واتساب لإرسال تفاصيل مجموعاتك وتأكيد الشحن والدفع.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: () {
                Navigator.pop(context);
                ref.read(cartProvider.notifier).sendOrderToWhatsApp();
              },
              icon: const FaIcon(FontAwesomeIcons.whatsapp),
              label: const Text("إرسال للواتساب الآن", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final CartItem item;
  final CartNotifier notifier;
  const _CartItemCard({required this.item, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardGrey,
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        title: Text(item.collection.name, style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
        subtitle: Text("${item.collection.items.length} كارت | ${item.collection.style}", style: const TextStyle(color: Colors.white54)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.remove, color: Colors.white70), onPressed: () {
               if(item.quantity > 1) {
                 item.quantity--;
                 notifier.updateState();
               }
            }),
            Text("${item.quantity}", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.add, color: Colors.white70), onPressed: () {
               item.quantity++;
               notifier.updateState();
            }),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () => notifier.removeCollection(item.collection.id),
            ),
          ],
        ),
      ),
    );
  }
}
