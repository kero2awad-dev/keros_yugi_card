import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../app/theme.dart';
import '../../data/models/collection_model.dart';
import '../../data/models/card_model.dart';
import 'ready_decks_repository.dart';

class AllReadyDecksScreen extends ConsumerStatefulWidget {
  const AllReadyDecksScreen({super.key});

  @override
  ConsumerState<AllReadyDecksScreen> createState() => _AllReadyDecksScreenState();
}

class _AllReadyDecksScreenState extends ConsumerState<AllReadyDecksScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final List<String> deckStyles = ['English', 'Arabic', 'Anime'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: deckStyles.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final readyDecksAsync = ref.watch(readyDecksProvider);
    final double screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount = screenWidth > 1200 ? 5 : (screenWidth > 800 ? 4 : 2);

    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      appBar: AppBar(
        title: const Text("المجموعات الجاهزة"),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryGold),
          onPressed: () => context.pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "ابحث في المجموعات...",
                    hintStyle: const TextStyle(color: Colors.white24),
                    prefixIcon: const Icon(Icons.search, color: AppTheme.primaryGold),
                    filled: true, fillColor: AppTheme.cardGrey,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                ),
              ),
              readyDecksAsync.when(
                data: (decks) => TabBar(
                  controller: _tabController,
                  indicatorColor: AppTheme.primaryGold,
                  tabs: deckStyles.map((s) {
                    final count = decks.where((d) => d.style == s).length;
                    return Tab(child: Text("$s ($count)"));
                  }).toList(),
                ),
                loading: () => TabBar(controller: _tabController, tabs: deckStyles.map((s) => Tab(text: s)).toList()),
                error: (_, __) => TabBar(controller: _tabController, tabs: deckStyles.map((s) => Tab(text: s)).toList()),
              ),
            ],
          ),
        ),
      ),
      body: readyDecksAsync.when(
        data: (decks) => TabBarView(
          controller: _tabController,
          children: deckStyles.map((style) {
            final filtered = decks.where((d) => d.style == style && (d.name.toLowerCase().contains(_searchQuery))).toList();
            if (filtered.isEmpty) return const Center(child: Text("لا توجد مجموعات", style: TextStyle(color: Colors.white24)));

            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 0.75,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
              ),
              itemCount: filtered.length,
              itemBuilder: (context, index) => _buildDeckCard(context, filtered[index]),
            );
          }).toList(),
        ),
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold)),
        error: (err, _) => Center(child: Text("خطأ: $err")),
      ),
    );
  }

  Widget _buildDeckCard(BuildContext context, ReadyDeck deck) {
    return GestureDetector(
      onTap: () => context.push('/ready-deck/${deck.id}', extra: deck),
      child: Container(
        decoration: BoxDecoration(color: AppTheme.cardGrey, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), 
                child: CachedNetworkImage(
                  imageUrl: deck.displayImageUrl, // تم التحديث لاستخدام الرابط المحول
                  fit: BoxFit.cover, 
                  errorWidget: (c, u, e) => Image.network(YugiCard.backImageUrl, fit: BoxFit.cover)
                )
              )
            ),
            Padding(padding: const EdgeInsets.all(10), child: Text(deck.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}
