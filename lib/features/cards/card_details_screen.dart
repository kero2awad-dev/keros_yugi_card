import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../data/models/card_model.dart';
import '../../app/theme.dart';
import '../collections/collections_repository.dart';
import '../favorites/favorites_repository.dart';
import '../auth/auth_repository.dart';
import '../home/ready_decks_repository.dart';

class CardDetailsScreen extends ConsumerStatefulWidget {
  final YugiCard card;
  final String initialStyle;

  const CardDetailsScreen({super.key, required this.card, this.initialStyle = 'English'});

  @override
  ConsumerState<CardDetailsScreen> createState() => _CardDetailsScreenState();
}

class _CardDetailsScreenState extends ConsumerState<CardDetailsScreen> {
  late String selectedStyle;
  String selectedOrder = 'end';

  @override
  void initState() {
    super.initState();
    selectedStyle = (widget.initialStyle == 'Overframes') ? 'Frame Less' : widget.initialStyle;
  }

  @override
  Widget build(BuildContext context) {
    final isFavoriteAsync = ref.watch(isFavoriteProvider(widget.card.id));
    final isAdmin = ref.watch(isAdminProvider);
    final imageUrl = widget.card.getStyledImageUrl(selectedStyle);
    final r2BaseUrl = dotenv.env['R2_PUBLIC_BASE_URL'] ?? 'https://pub-67c14d1df1694d699615902188d77613.r2.dev';
    final cardBackUrl = '$r2BaseUrl/BACK.jpg';

    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 450,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppTheme.primaryGold),
              onPressed: () => Navigator.of(context).maybePop(), // العودة للخلف فقط
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Image.network(cardBackUrl, fit: BoxFit.cover),
                errorWidget: (context, url, error) => Image.network(cardBackUrl, fit: BoxFit.cover),
              ),
            ),
            actions: [
              isFavoriteAsync.when(
                data: (isFav) => IconButton(
                  icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : Colors.white),
                  onPressed: () {
                    ref.read(favoritesRepositoryProvider).toggleFavorite(widget.card.id);
                    ref.invalidate(isFavoriteProvider(widget.card.id));
                    ref.invalidate(myFavoritesProvider);
                  },
                ),
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.card.name, style: const TextStyle(color: AppTheme.primaryGold, fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  const Text("اختر الستايل:", style: TextStyle(color: Colors.white54)),
                  const SizedBox(height: 10),
                  _buildStyleChips(),
                  const SizedBox(height: 20),
                  Text(widget.card.desc, style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5)),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(20),
        color: AppTheme.backgroundBlack,
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGold,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: () => _showAddToCollectionSheet(context, widget.card.name),
                child: const Text("إضافة إلى مجموعاتي", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
            if (isAdmin) ...[
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: () => _showAdminDeckList(context),
                  child: const Icon(Icons.admin_panel_settings, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStyleChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ['English', 'Anime', 'Arabic', 'Frame Less'].map((s) {
          final isSel = selectedStyle == s;
          return GestureDetector(
            onTap: () => setState(() => selectedStyle = s),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: isSel ? AppTheme.primaryGold : AppTheme.cardGrey, borderRadius: BorderRadius.circular(10)),
              child: Text(s, style: TextStyle(color: isSel ? Colors.black : Colors.white)),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showAddToCollectionSheet(BuildContext context, String displayName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardGrey,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final collectionsAsync = ref.watch(myCollectionsProvider);
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("أضف $displayName إلى محفظتك", style: const TextStyle(color: AppTheme.primaryGold, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                collectionsAsync.when(
                  data: (list) => list.isEmpty 
                    ? const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text("لا يوجد مجموعات حالياً. أنشئ واحدة أولاً.", style: TextStyle(color: Colors.white54)),
                      )
                    : Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: list.length,
                          itemBuilder: (context, index) => ListTile(
                            title: Text(list[index].name, style: const TextStyle(color: Colors.white)),
                            trailing: const Icon(Icons.add_circle_outline, color: AppTheme.primaryGold),
                            onTap: () async {
                              final error = await ref.read(collectionsRepositoryProvider).addCardToCollection(
                                collectionId: list[index].id, 
                                cardId: widget.card.id,
                                style: selectedStyle,
                              );
                              
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(error ?? "✅ تمت الإضافة لـ ${list[index].name}"),
                                  backgroundColor: error == null ? Colors.green : Colors.red,
                                ));
                              }
                              ref.invalidate(myCollectionsProvider);
                            },
                          ),
                        ),
                      ),
                  loading: () => const CircularProgressIndicator(color: AppTheme.primaryGold),
                  error: (e, _) => Text("Error: $e"),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAdminDeckList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardGrey,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Consumer(
          builder: (context, ref, child) {
            final readyDecksAsync = ref.watch(readyDecksProvider);
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("إضافة لمجموعة جاهزة (أدمن)", style: TextStyle(color: Colors.blueAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  const Text("اختر مكان الإضافة:", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildOrderOption(setDialogState, 'start', 'في البداية'),
                      const SizedBox(width: 10),
                      _buildOrderOption(setDialogState, 'end', 'في النهاية'),
                      const SizedBox(width: 10),
                      _buildOrderOption(setDialogState, 'sort', 'ترتيب تلقائي'),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 30),
                  readyDecksAsync.when(
                    data: (decks) => Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: decks.length,
                        itemBuilder: (context, index) => ListTile(
                          title: Text(decks[index].name, style: const TextStyle(color: Colors.white)),
                          trailing: const Icon(Icons.add_to_photos_rounded, color: Colors.blueAccent),
                          onTap: () async {
                            String finalId = widget.card.id;
                            String baseId = finalId.replaceAll('_ar', '').replaceAll('_fl', '').replaceAll('_anime', '');
                            if (selectedStyle == 'Arabic') finalId = "${baseId}_ar";
                            else if (selectedStyle == 'Frame Less') finalId = "${baseId}_fl";
                            else if (selectedStyle == 'Anime') finalId = "${baseId}_anime";
                            else finalId = baseId;

                            try {
                              await ref.read(readyDecksRepositoryProvider).addCardToReadyDeck(
                                decks[index].id, 
                                finalId,
                                order: selectedOrder,
                              );
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text("✅ أضيف الكارت لمجموعة ${decks[index].name}"),
                                  backgroundColor: Colors.green,
                                ));
                              }
                              ref.invalidate(readyDecksProvider);
                            } catch (e) {
                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ خطأ: $e")));
                            }
                          },
                        ),
                      ),
                    ),
                    loading: () => const CircularProgressIndicator(),
                    error: (e, _) => Text("Error: $e"),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildOrderOption(StateSetter setDialogState, String value, String label) {
    final isSelected = selectedOrder == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 11)),
      selected: isSelected,
      selectedColor: Colors.blueAccent,
      backgroundColor: Colors.white10,
      onSelected: (val) {
        if (val) setDialogState(() => selectedOrder = value);
      },
    );
  }
}
