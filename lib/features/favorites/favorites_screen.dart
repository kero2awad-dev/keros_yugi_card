import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../app/theme.dart';
import 'favorites_repository.dart';
import '../../data/models/card_model.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(myFavoritesProvider);
    final r2BaseUrl = dotenv.env['R2_PUBLIC_BASE_URL'] ?? 'https://pub-67c14d1df1694d699615902188d77613.r2.dev';
    final cardBackUrl = '$r2BaseUrl/BACK.jpg';

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        context.go('/');
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundBlack,
        appBar: AppBar(
          title: const Text("المفضلة"),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.primaryGold),
            onPressed: () => context.go('/'),
          ),
        ),
        body: favoritesAsync.when(
          data: (cards) {
            if (cards.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.favorite_border, size: 80, color: Colors.white10),
                    SizedBox(height: 20),
                    Text("لم تضف أي بطاقات للمفضلة بعد", style: TextStyle(color: Colors.white54)),
                  ],
                ),
              );
            }
    
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.7,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
              ),
              itemCount: cards.length,
              itemBuilder: (context, index) {
                final card = cards[index];
                return _FavoriteCard(card: card, backUrl: cardBackUrl);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold)),
          error: (err, _) => Center(child: Text("Error: $err")),
        ),
      ),
    );
  }
}

class _FavoriteCard extends ConsumerWidget {
  final YugiCard card;
  final String backUrl;
  const _FavoriteCard({required this.card, required this.backUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // تحديد الستايل من المعرف إذا أمكن
    String style = 'English';
    if (card.id.endsWith('_ar')) style = 'Arabic';
    else if (card.id.endsWith('_fl')) style = 'Frame Less';
    else if (card.id.endsWith('_anime')) style = 'Anime';

    final displayImageUrl = card.getStyledImageUrl(style);
    final bool hideName = style == 'Arabic' || style == 'Frame Less';

    return GestureDetector(
      onTap: () => context.push('/card/${card.id}?style=$style', extra: card),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: CachedNetworkImage(
              imageUrl: displayImageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              placeholder: (context, url) => Image.network(backUrl, fit: BoxFit.cover),
              errorWidget: (context, url, error) => Image.network(backUrl, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            top: 5,
            right: 5,
            child: IconButton(
              icon: const Icon(Icons.favorite, color: Colors.red),
              onPressed: () {
                ref.read(favoritesRepositoryProvider).toggleFavorite(card.id);
                ref.invalidate(myFavoritesProvider);
                ref.invalidate(isFavoriteProvider(card.id));
              },
            ),
          ),
          if (!hideName)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, 
                    end: Alignment.bottomCenter, 
                    colors: [Colors.transparent, Colors.black.withOpacity(0.8)]
                  )
                ),
                child: Text(
                  card.name, 
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), 
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis
                ),
              ),
            ),
        ],
      ),
    );
  }
}
