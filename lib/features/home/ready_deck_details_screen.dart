import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../app/theme.dart';
import '../../data/models/collection_model.dart';
import '../../data/models/card_model.dart';
import '../../data/repositories/card_repository.dart';
import '../collections/collections_repository.dart';
import '../auth/auth_repository.dart';
import '../cart/cart_repository.dart';
import 'ready_decks_repository.dart';

class ReadyDeckDetailsScreen extends ConsumerStatefulWidget {
  final ReadyDeck deck;
  const ReadyDeckDetailsScreen({super.key, required this.deck});

  @override
  ConsumerState<ReadyDeckDetailsScreen> createState() => _ReadyDeckDetailsScreenState();
}

class _ReadyDeckDetailsScreenState extends ConsumerState<ReadyDeckDetailsScreen> {
  late ReadyDeck _currentDeck;

  @override
  void initState() {
    super.initState();
    _currentDeck = widget.deck;
  }

  Map<String, List<YugiCard>> _groupCards(List<YugiCard> cards) {
    final monsters = <YugiCard>[];
    final spells = <YugiCard>[];
    final traps = <YugiCard>[];
    final extra = <YugiCard>[];
    for (final card in cards) {
      final type = card.type.toLowerCase();
      if (type.contains('spell')) spells.add(card);
      else if (type.contains('trap')) traps.add(card);
      else if (type.contains('fusion') || type.contains('synchro') || type.contains('xyz') || type.contains('link') || type.contains('token')) extra.add(card);
      else monsters.add(card);
    }
    final groups = <String, List<YugiCard>>{};
    if (monsters.isNotEmpty) groups['الوحوش (Monsters)'] = monsters;
    if (spells.isNotEmpty) groups['أوراق السحر (Spells)'] = spells;
    if (traps.isNotEmpty) groups['أوراق الفخ (Traps)'] = traps;
    if (extra.isNotEmpty) groups['المجموعة الإضافية (Extra)'] = extra;
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(deckCardsProvider(_currentDeck.cardIds.join(',')));
    final isAdmin = ref.watch(isAdminProvider);
    final cardBackUrl = YugiCard.backImageUrl;

    final double screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount = screenWidth > 1200 ? 8 : (screenWidth > 800 ? 5 : 3);

    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 280, pinned: true,
            backgroundColor: AppTheme.backgroundBlack,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppTheme.primaryGold),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(_currentDeck.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              background: Stack(fit: StackFit.expand, children: [
                CachedNetworkImage(imageUrl: _currentDeck.displayImageUrl, fit: BoxFit.cover, errorWidget: (c, u, e) => Image.network(cardBackUrl, fit: BoxFit.cover)),
                Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, AppTheme.backgroundBlack]))),
              ]),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.file_download, color: AppTheme.primaryGold),
                onPressed: _downloadDeckIds,
                tooltip: "تحميل أرقام الكروت",
              ),
              if (isAdmin) ...[
                IconButton(icon: const Icon(Icons.payments_outlined, color: AppTheme.primaryGold), onPressed: _showEditPriceDialog, tooltip: "تعديل السعر"),
                IconButton(icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryGold), onPressed: _showAddCardDialog, tooltip: "إضافة كارت"),
                IconButton(icon: const Icon(Icons.drive_file_move_rtl_rounded, color: AppTheme.primaryGold), onPressed: _showChangeStyleDialog, tooltip: "نقل المجموعة لتاب أخرى"),
                IconButton(icon: const Icon(Icons.delete_forever, color: Colors.redAccent), onPressed: _deleteDeck, tooltip: "حذف المجموعة"),
              ],
              PopupMenuButton<String>(
                icon: const Icon(Icons.sort_rounded, color: AppTheme.primaryGold),
                onSelected: _handleSort,
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'alpha', child: Text("ترتيب أبجدي")),
                  const PopupMenuItem(value: 'id', child: Text("ترتيب حسب ID")),
                  const PopupMenuItem(value: 'reverse', child: Text("عكس الترتيب")),
                ],
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_currentDeck.description, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 15),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  _buildChip(Icons.style_rounded, "${_currentDeck.cardIds.length} كارت", AppTheme.primaryGold),
                  _buildChip(Icons.tab, _currentDeck.style, Colors.blueAccent),
                  _buildChip(Icons.sell, "${_currentDeck.price.toStringAsFixed(0)} EGP", Colors.green),
                ]),
              ]),
            ),
          ),
          cardsAsync.when(
            data: (deckCards) {
              final groups = _groupCards(deckCards);
              return SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final groupEntries = groups.entries.toList();
                  if (index >= groupEntries.length) return null;
                  final entry = groupEntries[index];
                  return AnimationLimiter(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _buildHeader(entry.key, entry.value.length),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: GridView.builder(
                          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            childAspectRatio: 0.6, 
                            crossAxisSpacing: 10, 
                            mainAxisSpacing: 10
                          ),
                          itemCount: entry.value.length,
                          itemBuilder: (context, i) => AnimationConfiguration.staggeredGrid(
                            position: i, duration: const Duration(milliseconds: 375), columnCount: crossAxisCount,
                            child: ScaleAnimation(child: FadeInAnimation(child: _buildGridItem(entry.value[i], isAdmin))),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ]),
                  );
                }, childCount: groups.length),
              );
            },
            loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppTheme.primaryGold))),
            error: (e, _) => SliverFillRemaining(child: Center(child: Text("خطأ: $e", style: const TextStyle(color: Colors.red)))),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 150)),
        ],
      ),
      bottomSheet: _buildBottomBar(),
    );
  }

  Widget _buildGridItem(YugiCard card, bool isAdmin) {
    return GestureDetector(
      onTap: () => context.push('/card/${card.id}?style=${Uri.encodeComponent(_currentDeck.style)}', extra: card),
      child: Stack(fit: StackFit.expand, children: [
        ClipRRect(borderRadius: BorderRadius.circular(10), child: CachedNetworkImage(imageUrl: card.getStyledImageUrl(_currentDeck.style), fit: BoxFit.cover, errorWidget: (c, u, e) => Image.network(YugiCard.backImageUrl, fit: BoxFit.cover))),
        if (isAdmin) Positioned(top: 2, right: 2, child: GestureDetector(onTap: () => _removeCard(card.id), child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.redAccent, size: 14)))),
        Positioned(bottom: 0, left: 0, right: 0, child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.8)])), child: Text(card.name, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis))),
      ]),
    );
  }

  Widget _buildBottomBar() {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15), color: AppTheme.backgroundBlack, child: Row(children: [
      Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGold, foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: _addDirectlyToCart, icon: const Icon(Icons.shopping_basket_rounded), label: const Text("إضافة للسلة", style: TextStyle(fontWeight: FontWeight.bold)))),
      const SizedBox(width: 10),
      Expanded(child: OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryGold, side: const BorderSide(color: AppTheme.primaryGold), minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: _showCloneDialog, icon: const Icon(Icons.edit_note_rounded), label: const Text("تعديل خاص", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)))),
    ]));
  }

  Widget _buildChip(IconData i, String l, Color c) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: c.withOpacity(0.3))), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(i, size: 14, color: c), const SizedBox(width: 6), Text(l, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.bold))]));
  Widget _buildHeader(String t, int c) => Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), margin: const EdgeInsets.only(top: 10, bottom: 15), decoration: BoxDecoration(color: AppTheme.primaryGold.withOpacity(0.05), border: const Border(left: BorderSide(color: AppTheme.primaryGold, width: 4))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(t, style: const TextStyle(color: AppTheme.primaryGold, fontSize: 15, fontWeight: FontWeight.bold)), Text("$c", style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold))]));

  Future<void> _handleSort(String type) async {
    final repo = ref.read(readyDecksRepositoryProvider);
    if (type == 'alpha') await repo.sortDeckAlphabetically(_currentDeck.id);
    else if (type == 'id') await repo.sortDeckById(_currentDeck.id);
    else if (type == 'reverse') await repo.reverseDeck(_currentDeck.id);
    _refresh();
  }

  Future<void> _deleteDeck() async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(backgroundColor: AppTheme.cardGrey, title: const Text("حذف المجموعة؟"), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("إلغاء")), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("حذف", style: TextStyle(color: Colors.red)))]));
    if (ok == true) {
      await ref.read(readyDecksRepositoryProvider).deleteDeck(_currentDeck.id);
      ref.invalidate(readyDecksProvider);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _showChangeStyleDialog() async {
    String? newStyle = await showDialog<String>(context: context, builder: (c) {
      String sel = _currentDeck.style;
      return StatefulBuilder(builder: (c, setSt) => AlertDialog(backgroundColor: AppTheme.cardGrey, title: const Text("نقل المجموعة"), content: Column(mainAxisSize: MainAxisSize.min, children: ['English', 'Arabic', 'Anime'].map((s) => RadioListTile<String>(title: Text(s, style: const TextStyle(color: Colors.white)), value: s, groupValue: sel, activeColor: AppTheme.primaryGold, onChanged: (v) => setSt(() => sel = v!))).toList()), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("إلغاء")), ElevatedButton(onPressed: () => Navigator.pop(c, sel), child: const Text("نقل"))]));
    });
    if (newStyle != null && newStyle != _currentDeck.style) {
      await ref.read(readyDecksRepositoryProvider).updateDeckStyle(_currentDeck.id, newStyle);
      _refresh();
    }
  }

  Future<void> _showEditPriceDialog() async {
    final ctrl = TextEditingController(text: _currentDeck.price.toStringAsFixed(0));
    await showDialog(context: context, builder: (c) => AlertDialog(backgroundColor: AppTheme.cardGrey, title: const Text("تعديل السعر"), content: TextField(controller: ctrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white)), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("إلغاء")), ElevatedButton(onPressed: () async {
      final p = double.tryParse(ctrl.text);
      if (p != null) {
        await ref.read(readyDecksRepositoryProvider).updateDeckPrice(_currentDeck.id, p);
        _refresh();
        Navigator.pop(c);
      }
    }, child: const Text("حفظ"))]));
  }

  Future<void> _showAddCardDialog() async {
    final ctrl = TextEditingController();
    await showDialog(context: context, builder: (c) => AlertDialog(backgroundColor: AppTheme.cardGrey, title: const Text("إضافة كارت"), content: TextField(controller: ctrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "الرقم أو الاسم")), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("إلغاء")), ElevatedButton(onPressed: () async {
      final res = await ref.read(cardRepositoryProvider).searchCards(query: ctrl.text.trim(), pageSize: 1);
      if (res.isNotEmpty) {
        await ref.read(readyDecksRepositoryProvider).addCardToReadyDeck(_currentDeck.id, res.first.id);
        _refresh();
        Navigator.pop(c);
      }
    }, child: const Text("إضافة"))]));
  }

  Future<void> _removeCard(String id) async {
    final ids = List<String>.from(_currentDeck.cardIds)..remove(id);
    await ref.read(readyDecksRepositoryProvider).updateDeckContent(_currentDeck.id, ids);
    _refresh();
  }

  void _refresh() async {
    ref.invalidate(readyDecksProvider);
    final decks = await ref.read(readyDecksProvider.future);
    setState(() => _currentDeck = decks.firstWhere((d) => d.id == _currentDeck.id));
  }

  Future<void> _addDirectlyToCart() async {
    final tempColl = await ref.read(collectionsRepositoryProvider).createCollectionFromReadyDeck(_currentDeck, targetStyle: _currentDeck.style);
    ref.read(cartProvider.notifier).addCollection(tempColl);
    context.push('/cart');
  }

  Future<void> _showCloneDialog() async {
    String? selStyle = await showDialog<String>(context: context, builder: (c) {
      String sel = _currentDeck.style;
      return StatefulBuilder(builder: (c, setSt) => AlertDialog(backgroundColor: AppTheme.cardGrey, title: const Text("تعديل على المجموعة"), content: Column(mainAxisSize: MainAxisSize.min, children: ['English', 'Arabic', 'Anime', 'Frame Less'].map((s) => RadioListTile<String>(title: Text(s, style: const TextStyle(color: Colors.white)), value: s, groupValue: sel, activeColor: AppTheme.primaryGold, onChanged: (v) => setSt(() => sel = v!))).toList()), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("إلغاء")), ElevatedButton(onPressed: () => Navigator.pop(c, sel), child: const Text("تعديل الآن"))]));
    });
    if (selStyle != null) {
      final newColl = await ref.read(collectionsRepositoryProvider).createCollectionFromReadyDeck(_currentDeck, targetStyle: selStyle);
      ref.invalidate(myCollectionsProvider);
      context.push('/collections/${newColl.id}?name=${Uri.encodeComponent(newColl.name)}');
    }
  }

  void _downloadDeckIds() {
    // إنشاء مجموعة مؤقتة لتحميل ملف الـ IDs الخاص بها
    final tempCollection = YugiCollection(
      id: 'temp', 
      userId: 'temp', 
      name: _currentDeck.name, 
      style: _currentDeck.style, 
      createdAt: DateTime.now(),
      items: _currentDeck.cardIds.map((id) => CollectionItem(
        id: id, 
        cardId: id, 
        quantity: 1, 
        addedStyle: _currentDeck.style
      )).toList()
    );
    ref.read(collectionsRepositoryProvider).downloadCollectionAsText(tempCollection);
  }
}
