import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:shimmer/shimmer.dart';
import '../../data/repositories/card_repository.dart';
import '../../data/models/card_model.dart';
import '../../data/models/collection_model.dart';
import '../collections/collections_repository.dart';
import '../favorites/favorites_repository.dart';
import '../auth/auth_repository.dart';
import 'ready_decks_repository.dart';
import '../../app/theme.dart';
import 'dart:async';

final homeTabIndexProvider = StateProvider<int>((ref) => 0);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;
  
  String _searchQuery = '';
  String? _selectedArchetype;
  Timer? _debounce;
  final List<String> styles = ['English', 'Anime', 'Arabic', 'Frame Less'];

  List<Map<String, String>> get _featuredArchetypes {
    final baseUrl = dotenv.env['R2_PUBLIC_BASE_URL']?.trim() ?? 'https://pub-67c14d1df1694d699615902188d77613.r2.dev';
    final cleanBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    
    return [
      {'name': 'Dark Magician', 'image': '$cleanBaseUrl/46986414.jpg', 'label': 'يامي يوغي'},
      {'name': 'Blue-Eyes', 'image': '$cleanBaseUrl/89631139.jpg', 'label': 'سيتو كايبا'},
      {'name': 'Red-Eyes', 'image': '$cleanBaseUrl/74677422.jpg', 'label': 'جوي ويلر'},
      {'name': 'Exodia', 'image': '$cleanBaseUrl/33396948.jpg', 'label': 'إكسوديا'},
    ];
  }

  @override
  void initState() {
    super.initState();
    final initialIndex = ref.read(homeTabIndexProvider);
    _tabController = TabController(length: styles.length, vsync: this, initialIndex: initialIndex);
    
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(homeTabIndexProvider.notifier).state = _tabController.index;
        setState(() {}); 
      }
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(paginatedCardSearchProvider(_getCurrentSearchParams()).notifier).fetchNextPage();
    }
  }

  CardSearchParams _getCurrentSearchParams() {
    return CardSearchParams(
      query: _searchQuery, 
      style: styles[_tabController.index],
      archetype: _selectedArchetype,
    );
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = query;
        _selectedArchetype = null;
      });
    });
  }

  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _selectedArchetype = null;
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(homeTabIndexProvider, (previous, next) {
      if (next != _tabController.index) {
        _tabController.animateTo(next);
      }
    });

    final searchParams = _getCurrentSearchParams();
    final cardsAsync = ref.watch(paginatedCardSearchProvider(searchParams));
    final readyDecksAsync = ref.watch(readyDecksProvider);
    final cardCountsAsync = ref.watch(cardCountsProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final r2BaseUrl = dotenv.env['R2_PUBLIC_BASE_URL']?.trim() ?? 'https://pub-67c14d1df1694d699615902188d77613.r2.dev';
    final cleanR2BaseUrl = r2BaseUrl.endsWith('/') ? r2BaseUrl.substring(0, r2BaseUrl.length - 1) : r2BaseUrl;
    final cardBackUrl = '$cleanR2BaseUrl/BACK.jpg';

    final double screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount = screenWidth > 1200 ? 6 : (screenWidth > 900 ? 4 : (screenWidth > 600 ? 3 : 2));

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_searchQuery.isNotEmpty || _selectedArchetype != null) {
          _clearSearch();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("استخدم القائمة للتنقل داخل التطبيق"), duration: Duration(seconds: 1)),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundBlack,
        body: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              expandedHeight: 180.0,
              pinned: true,
              backgroundColor: AppTheme.backgroundBlack,
              leading: (_searchQuery.isNotEmpty || _selectedArchetype != null) 
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppTheme.primaryGold),
                      onPressed: _clearSearch,
                    )
                  : null,
              actions: [
                if (isAdmin)
                  IconButton(
                    icon: const Icon(Icons.admin_panel_settings, color: AppTheme.primaryGold),
                    onPressed: () => context.push('/admin'),
                  ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  _selectedArchetype != null ? "مجموعة $_selectedArchetype" : "KERO YUGI CARDS", 
                  style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 16)
                ),
                centerTitle: true,
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Opacity(
                      opacity: 0.3,
                      child: CachedNetworkImage(
                        imageUrl: '$cleanR2BaseUrl/46986414.jpg', 
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Image.network(cardBackUrl, fit: BoxFit.cover),
                      ),
                    ),
                    Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, AppTheme.backgroundBlack]))),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن وحشك المفضل...',
                    hintStyle: const TextStyle(color: Colors.white24),
                    prefixIcon: const Icon(Icons.search, color: AppTheme.primaryGold),
                    suffixIcon: (_searchQuery.isNotEmpty || _selectedArchetype != null)
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white24),
                            onPressed: _clearSearch,
                          )
                        : null,
                    filled: true,
                    fillColor: AppTheme.cardGrey,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
            ),

            if (_searchQuery.isEmpty && _selectedArchetype == null) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("مجموعات أسطورية جاهزة", style: TextStyle(color: AppTheme.primaryGold, fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () => context.push('/all-ready-decks'),
                        child: const Text("See All", style: TextStyle(color: AppTheme.primaryGold)),
                      ),
                    ],
                  ),
                ),
              ),
              readyDecksAsync.when(
                data: (decks) => SliverToBoxAdapter(
                  child: AnimationLimiter(
                    child: SizedBox(
                      height: 220,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: decks.length > 5 ? 5 : decks.length,
                        itemBuilder: (context, index) => AnimationConfiguration.staggeredList(
                          position: index,
                          duration: const Duration(milliseconds: 600),
                          child: SlideAnimation(
                            horizontalOffset: 100.0,
                            child: FadeInAnimation(
                              child: _buildPremiumDeckCard(context, decks[index], cardBackUrl),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                loading: () => SliverToBoxAdapter(child: _buildHorizontalShimmer()),
                error: (err, _) => const SliverToBoxAdapter(child: SizedBox()),
              ),
              
              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(16, 25, 16, 15), child: Text("أشهر الشخصيات", style: TextStyle(color: AppTheme.primaryGold, fontSize: 18, fontWeight: FontWeight.bold)))),
              SliverToBoxAdapter(
                child: AnimationLimiter(
                  child: SizedBox(
                    height: 120, 
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal, 
                      itemCount: _featuredArchetypes.length, 
                      itemBuilder: (context, index) => AnimationConfiguration.staggeredList(
                        position: index,
                        duration: const Duration(milliseconds: 600),
                        child: SlideAnimation(
                          horizontalOffset: 100.0,
                          child: FadeInAnimation(
                            child: _buildCharacterAvatar(_featuredArchetypes[index]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],

            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicatorColor: AppTheme.primaryGold,
                  labelColor: AppTheme.primaryGold,
                  unselectedLabelColor: Colors.white60,
                  tabs: styles.map((s) {
                    return Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(s),
                          const SizedBox(width: 6),
                          cardCountsAsync.when(
                            data: (counts) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGold.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                "${counts[s] ?? 0}",
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                            loading: () => const SizedBox(),
                            error: (_, __) => const SizedBox(),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            cardsAsync.when(
              data: (cards) {
                if (cards.isEmpty) {
                  return const SliverFillRemaining(child: Center(child: Text("لا توجد بطاقات متاحة بهذا الستايل حالياً", style: TextStyle(color: Colors.white54))));
                }
                return SliverPadding(
                  padding: const EdgeInsets.all(12),
                  sliver: AnimationLimiter(
                    child: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: 0.65,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => AnimationConfiguration.staggeredGrid(
                          position: index,
                          duration: const Duration(milliseconds: 500),
                          columnCount: crossAxisCount,
                          child: ScaleAnimation(
                            scale: 0.8,
                            child: FadeInAnimation(
                              child: _QuickAddCard(
                                card: cards[index], 
                                backUrl: cardBackUrl,
                                currentStyle: styles[_tabController.index],
                              ),
                            ),
                          ),
                        ),
                        childCount: cards.length,
                      ),
                    ),
                  ),
                );
              },
              loading: () => SliverPadding(
                padding: const EdgeInsets.all(12),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 0.65,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildCardShimmer(),
                    childCount: 6,
                  ),
                ),
              ),
              error: (e, _) => SliverFillRemaining(child: Center(child: Text("خطأ: $e", style: const TextStyle(color: Colors.red)))),
            ),
            
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),

        bottomNavigationBar: Container(
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white10, width: 0.5))),
          child: BottomNavigationBar(
            backgroundColor: AppTheme.backgroundBlack,
            selectedItemColor: AppTheme.primaryGold,
            unselectedItemColor: Colors.white38,
            currentIndex: 0,
            type: BottomNavigationBarType.fixed,
            onTap: (index) {
              if (index == 1) context.push('/collections');
              if (index == 2) context.push('/favorites');
              if (index == 3) context.push('/cart');
              if (index == 4) context.push('/profile');
            },
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),
              BottomNavigationBarItem(icon: Icon(Icons.style), label: 'مجموعاتي'),
              BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'المفضلة'),
              BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'السلة'),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: 'حسابي'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumDeckCard(BuildContext context, ReadyDeck deck, String backUrl) {
    return GestureDetector(
      onTap: () => context.push('/ready-deck/${deck.id}', extra: deck),
      child: Container(
        width: 150,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.cardGrey, 
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)), 
                child: CachedNetworkImage(
                  imageUrl: deck.displayImageUrl, // استخدام الرابط الجديد
                  fit: BoxFit.cover, 
                  width: double.infinity, 
                  placeholder: (context, url) => _buildShimmerBox(),
                  errorWidget: (context, url, error) => Image.network(backUrl, fit: BoxFit.cover)
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0), 
              child: Text(
                deck.name, 
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold), 
                maxLines: 1, 
                overflow: TextOverflow.ellipsis
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacterAvatar(Map<String, String> arch) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedArchetype = arch['name'];
          _searchQuery = '';
          _searchController.clear();
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primaryGold.withOpacity(0.5), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryGold.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 35, 
                backgroundImage: CachedNetworkImageProvider(arch['image']!),
              ),
            ),
            const SizedBox(height: 8), 
            Text(arch['label']!, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalShimmer() {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Shimmer.fromColors(
            baseColor: Colors.white10,
            highlightColor: Colors.white24,
            child: Container(
              width: 150,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.white10,
      highlightColor: Colors.white24,
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  Widget _buildShimmerBox() {
    return Shimmer.fromColors(
      baseColor: Colors.white10,
      highlightColor: Colors.white24,
      child: Container(color: Colors.white),
    );
  }
}

class _QuickAddCard extends ConsumerWidget {
  final YugiCard card;
  final String backUrl;
  final String currentStyle;

  const _QuickAddCard({required this.card, required this.backUrl, required this.currentStyle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayImageUrl = card.getStyledImageUrl(currentStyle);
    final bool hideName = currentStyle == 'Arabic' || currentStyle == 'Frame Less';

    return GestureDetector(
      onTap: () => context.push('/card/${card.id}?style=$currentStyle', extra: card),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Hero(
            tag: 'card-${card.id}-$currentStyle',
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: CachedNetworkImage(
                  imageUrl: displayImageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Shimmer.fromColors(
                    baseColor: Colors.white10,
                    highlightColor: Colors.white24,
                    child: Container(color: Colors.white),
                  ),
                  errorWidget: (context, url, error) => Image.network(backUrl, fit: BoxFit.cover),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8, right: 8,
            child: GestureDetector(
              onTap: () => _showQuickAddSheet(context, ref),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: AppTheme.primaryGold, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 4)]),
                child: const Icon(Icons.add, color: Colors.black, size: 20),
              ),
            ),
          ),
          Positioned(
            top: 8, left: 8,
            child: Consumer(builder: (context, ref, _) {
              final isFav = ref.watch(isFavoriteProvider(card.id)).value ?? false;
              return GestureDetector(
                onTap: () {
                  ref.read(favoritesRepositoryProvider).toggleFavorite(card.id);
                  ref.invalidate(isFavoriteProvider(card.id));
                  ref.invalidate(myFavoritesProvider);
                },
                child: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : Colors.white, size: 22),
              );
            }),
          ),
          if (!hideName)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.8)])),
                child: Text(card.name, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
        ],
      ),
    );
  }

  void _showQuickAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardGrey,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Consumer(builder: (context, ref, _) {
        final collections = ref.watch(myCollectionsProvider).value ?? [];
        final isAdmin = ref.watch(isAdminProvider);
        final readyDecks = isAdmin ? (ref.watch(readyDecksProvider).value ?? []) : <ReadyDeck>[];
        
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("أضف ${card.name} إلى:", style: const TextStyle(color: AppTheme.primaryGold, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (isAdmin && readyDecks.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text("المجموعات الجاهزة (Admin)", style: TextStyle(color: AppTheme.primaryGold, fontSize: 14, fontWeight: FontWeight.bold)),
                      ),
                      ...readyDecks.map((deck) => ListTile(
                        leading: const Icon(Icons.auto_awesome, color: AppTheme.primaryGold, size: 20),
                        title: Text(deck.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
                        subtitle: Text("تاب: ${deck.style}", style: const TextStyle(color: Colors.white38, fontSize: 11)),
                        trailing: const Icon(Icons.add_circle_outline, color: AppTheme.primaryGold),
                        onTap: () async {
                          await ref.read(readyDecksRepositoryProvider).addCardToReadyDeck(deck.id, card.id);
                          ref.invalidate(readyDecksProvider);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text("✅ تمت إضافة الكارت لمجموعة ${deck.name}"),
                              backgroundColor: Colors.green,
                            ));
                          }
                        },
                      )),
                      const Divider(color: Colors.white10, height: 30),
                    ],
                    
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text("مجموعاتي الخاصة", style: TextStyle(color: Colors.white70, fontSize: 14)),
                    ),
                    if (collections.isEmpty) 
                      const Padding(padding: EdgeInsets.all(20), child: Text("لا يوجد مجموعات حالياً. أنشئ واحدة أولاً.", style: TextStyle(color: Colors.white54))),
                    
                    ...collections.map((coll) => ListTile(
                      title: Text(coll.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
                      trailing: const Icon(Icons.add_circle_outline, color: AppTheme.primaryGold),
                      onTap: () async {
                        final error = await ref.read(collectionsRepositoryProvider).addCardToCollection(
                          collectionId: coll.id, 
                          cardId: card.id,
                          style: currentStyle,
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(error ?? "✅ تمت الإضافة لـ ${coll.name}"),
                            backgroundColor: error == null ? Colors.green : Colors.red,
                          ));
                        }
                        ref.invalidate(myCollectionsProvider);
                      },
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      }),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);
  final TabBar _tabBar;
  @override double get minExtent => _tabBar.preferredSize.height;
  @override double get maxExtent => _tabBar.preferredSize.height;
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(color: AppTheme.backgroundBlack, child: _tabBar);
  @override bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
