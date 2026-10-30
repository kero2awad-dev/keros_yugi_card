import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../app/theme.dart';
import '../../data/models/collection_model.dart';
import '../../data/models/card_model.dart';
import 'collections_repository.dart';
import '../../data/repositories/card_repository.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final viewModeProvider = StateProvider<bool>((ref) => true);

class CollectionDetailsScreen extends ConsumerWidget {
  final String collectionId;
  final String collectionName;

  const CollectionDetailsScreen({super.key, required this.collectionId, required this.collectionName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionsAsync = ref.watch(myCollectionsProvider);
    final isGridView = ref.watch(viewModeProvider);
    final r2BaseUrl = dotenv.env['R2_PUBLIC_BASE_URL'] ?? 'https://pub-67c14d1df1694d699615902188d77613.r2.dev';
    final cardBackUrl = '$r2BaseUrl/BACK.jpg';

    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      appBar: AppBar(
        title: Text(collectionName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryGold),
          onPressed: () => context.pop(), 
        ),
        actions: [
          collectionsAsync.when(
            data: (collections) {
              final collection = collections.firstWhere((c) => c.id == collectionId, orElse: () => YugiCollection(id: '', userId: '', name: '', style: '', createdAt: DateTime.now()));
              if (collection.id.isEmpty) return const SizedBox();
              
              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppTheme.primaryGold),
                onSelected: (val) {
                  if (val == 'import_text') _showImportTextDialog(context, ref);
                  else if (val == 'import_ydk') _showYdkImportDialog(context, ref);
                  else if (val == 'sort_alpha') _handleSort(ref, 'alpha');
                  else if (val == 'sort_id') _handleSort(ref, 'id');
                  else if (val == 'sort_reverse') _handleSort(ref, 'reverse');
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'import_text', child: Text("إضافة من نص (IDs)")),
                  const PopupMenuItem(value: 'import_ydk', child: Text("إضافة من ملف YDK")),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'sort_alpha', child: Text("ترتيب أبجدي")),
                  const PopupMenuItem(value: 'sort_id', child: Text("ترتيب حسب ID")),
                  const PopupMenuItem(value: 'sort_reverse', child: Text("عكس الترتيب")),
                ],
              );
            },
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
          IconButton(
            icon: Icon(isGridView ? Icons.view_list : Icons.grid_view, color: AppTheme.primaryGold),
            onPressed: () => ref.read(viewModeProvider.notifier).state = !isGridView,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: collectionsAsync.when(
        data: (collections) {
          final collection = collections.firstWhere((c) => c.id == collectionId, orElse: () => YugiCollection(id: '', userId: '', name: '', style: '', createdAt: DateTime.now()));
          if (collection.id.isEmpty) return const Center(child: Text("المجموعة غير موجودة"));
          
          final cardsAsync = ref.watch(collectionCardsProvider(collectionId));

          if (collection.items.isEmpty) return _buildEmptyState(context, ref, collection.style);

          return cardsAsync.when(
            data: (cards) {
              final Map<String, YugiCard> cardsMap = {for (var c in cards) c.id: c};
              return Column(
                children: [
                  _buildStatsHeader(collection),
                  Expanded(
                    child: AnimationLimiter(
                      child: isGridView
                          ? _buildGridView(context, ref, collection, cardsMap, cardBackUrl)
                          : _buildListView(context, ref, collection, cardsMap, cardBackUrl),
                    ),
                  ),
                  _buildBottomActionButtons(context, ref, collection),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold)),
            error: (err, _) => Center(child: Text("خطأ في تحميل البيانات: $err")),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold)),
        error: (err, _) => Center(child: Text("خطأ: $err")),
      ),
    );
  }

  Widget _buildBottomActionButtons(BuildContext context, WidgetRef ref, YugiCollection collection) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent, 
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: () => ref.read(collectionsRepositoryProvider).downloadCollectionAsText(collection),
              icon: const Icon(Icons.file_download),
              label: const Text("تحميل IDs", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366), 
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: () => ref.read(collectionsRepositoryProvider).shareToWhatsApp(collection),
              icon: const FaIcon(FontAwesomeIcons.whatsapp),
              label: const Text("طلب (واتساب)", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _showImportTextDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardGrey,
        title: const Text("إضافة كروت من نص", style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "اكتب أرقام الكروت (Passcodes) مفصولة بمسافة أو سطر جديد:",
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              maxLines: 5,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "89631139\n46986414\n...", 
                hintStyle: TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline, color: AppTheme.primaryGold, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "يمكنك أيضاً إضافة أي كارت أعجبك من الصفحة الرئيسية بالضغط على زر (+) الموجود على الكارت.",
                    style: TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGold),
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await ref.read(collectionsRepositoryProvider).addCardsToCollectionFromText(collectionId, "English", controller.text);
                ref.invalidate(myCollectionsProvider);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text("إضافة الآن", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showYdkImportDialog(BuildContext context, WidgetRef ref) async {
    final colls = await ref.read(myCollectionsProvider.future);
    final c = colls.firstWhere((c) => c.id == collectionId);
    final newColl = await ref.read(collectionsRepositoryProvider).createCollectionFromYdkFile(c.name, c.style);
    if (newColl != null) {
      ref.invalidate(myCollectionsProvider);
    }
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref, String style) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.layers_clear_outlined, size: 80, color: Colors.white10),
          const SizedBox(height: 16),
          const Text("المجموعة فارغة", style: TextStyle(color: Colors.white38)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => _showImportTextDialog(context, ref),
                icon: const Icon(Icons.text_fields),
                label: const Text("لصق أرقام"),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGold, foregroundColor: Colors.black),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _showYdkImportDialog(context, ref),
                icon: const Icon(Icons.file_upload),
                label: const Text("ملف YDK"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGridView(BuildContext context, WidgetRef ref, YugiCollection collection, Map<String, YugiCard> cardsMap, String backUrl) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.6, crossAxisSpacing: 12, mainAxisSpacing: 12),
      itemCount: collection.items.length,
      itemBuilder: (context, index) {
        final item = collection.items[index];
        final card = cardsMap[item.cardId];
        return AnimationConfiguration.staggeredGrid(
          position: index,
          duration: const Duration(milliseconds: 375),
          columnCount: 3,
          child: ScaleAnimation(
            child: FadeInAnimation(
              child: GestureDetector(
                onTap: () => context.push('/card/${item.cardId}?style=${item.addedStyle}', extra: card),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(imageUrl: card?.getStyledImageUrl(item.addedStyle) ?? "", fit: BoxFit.cover, placeholder: (c, u) => Image.network(backUrl), errorWidget: (c, u, e) => Image.network(backUrl)),
                    ),
                    Positioned(top: -5, right: -5, child: _buildBadge(item.quantity)),
                    Positioned(
                      top: 0, left: 0,
                      child: GestureDetector(
                        onTap: () async {
                          await ref.read(collectionsRepositoryProvider).removeCardFromCollection(collectionId, item.id);
                          ref.invalidate(myCollectionsProvider);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: Colors.red.withOpacity(0.8), borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), bottomRight: Radius.circular(10))),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildListView(BuildContext context, WidgetRef ref, YugiCollection collection, Map<String, YugiCard> cardsMap, String backUrl) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: collection.items.length,
      itemBuilder: (context, index) {
        final item = collection.items[index];
        final card = cardsMap[item.cardId];
        return AnimationConfiguration.staggeredList(
          position: index,
          duration: const Duration(milliseconds: 375),
          child: SlideAnimation(
            verticalOffset: 50.0,
            child: FadeInAnimation(
              child: Card(
                color: AppTheme.cardGrey,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  onTap: () => context.push('/card/${item.cardId}?style=${item.addedStyle}', extra: card),
                  leading: ClipRRect(borderRadius: BorderRadius.circular(5), child: CachedNetworkImage(imageUrl: card?.getStyledImageUrl(item.addedStyle) ?? "", width: 40, fit: BoxFit.cover)),
                  title: Text(card?.name ?? "كارت #${item.cardId}", style: const TextStyle(color: Colors.white, fontSize: 13)),
                  subtitle: Text("الستايل: ${item.addedStyle}", style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("x${item.quantity}", style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () async {
                          await ref.read(collectionsRepositoryProvider).removeCardFromCollection(collectionId, item.id);
                          ref.invalidate(myCollectionsProvider);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBadge(int qty) => Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: Text("$qty", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)));

  Widget _buildStatsHeader(YugiCollection collection) {
    final total = collection.items.fold(0, (sum, i) => (sum as int) + (i.quantity as int));
    return Container(padding: const EdgeInsets.all(15), color: Colors.white.withOpacity(0.05), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text("إجمالي الكروت: $total", style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold))]));
  }

  Future<void> _handleSort(WidgetRef ref, String type) async {
    final repo = ref.read(collectionsRepositoryProvider);
    if (type == 'alpha') await repo.sortCollectionAlphabetically(collectionId);
    else if (type == 'id') await repo.sortCollectionById(collectionId);
    else if (type == 'reverse') await repo.reverseCollection(collectionId);
    ref.invalidate(myCollectionsProvider);
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(backgroundColor: AppTheme.cardGrey, title: const Text("حذف المجموعة؟"), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("إلغاء")), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("حذف", style: TextStyle(color: Colors.red)))]));
    if (confirmed == true) {
      await ref.read(collectionsRepositoryProvider).deleteCollection(collectionId);
      if (context.mounted) context.pop();
    }
  }
}
