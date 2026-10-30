import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/home/home_screen.dart';
import '../features/home/all_ready_decks_screen.dart';
import '../features/collections/collections_screen.dart';
import '../features/collections/collection_details_screen.dart';
import '../features/favorites/favorites_screen.dart';
import '../features/cart/cart_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/admin/admin_screen.dart';
import '../features/admin/orders_management_screen.dart';
import '../features/home/ready_deck_details_screen.dart';
import '../features/cards/card_details_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/auth/auth_repository.dart';
import '../features/splash/splash_screen.dart';
import '../data/models/card_model.dart';
import '../data/models/collection_model.dart';

class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(Stream<dynamic> stream) {
    stream.listen((event) {
      notifyListeners();
    });
  }
}

final routerRefreshProvider = Provider((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return RouterRefreshNotifier(authRepo.authStateChanges);
});

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(routerRefreshProvider);
  final authRepo = ref.read(authRepositoryProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final user = authRepo.currentUser;
      final bool isLoggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/signup';
      final bool isSplash = state.matchedLocation == '/splash';

      if (isSplash) return null;

      if (user == null) {
        return isLoggingIn ? null : '/login';
      }
      
      if (isLoggingIn) return '/home';
      
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/', redirect: (_, __) => '/home'),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (context, state) => const SignUpScreen()),
      GoRoute(
        path: '/all-ready-decks',
        builder: (context, state) => const AllReadyDecksScreen(),
      ),
      GoRoute(
        path: '/collections',
        builder: (context, state) => const CollectionsScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              final name = state.uri.queryParameters['name'] ?? 'Collection';
              return CollectionDetailsScreen(collectionId: id, collectionName: name);
            },
          ),
        ],
      ),
      GoRoute(path: '/favorites', builder: (context, state) => const FavoritesScreen()),
      GoRoute(path: '/cart', builder: (context, state) => const CartScreen()),
      GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
      GoRoute(path: '/admin', builder: (context, state) => const AdminScreen()),
      GoRoute(path: '/admin/orders', builder: (context, state) => const OrdersManagementScreen()),
      GoRoute(
        path: '/card/:id',
        builder: (context, state) {
          final card = state.extra as YugiCard;
          final style = state.uri.queryParameters['style'] ?? 'English';
          return CardDetailsScreen(card: card, initialStyle: style);
        },
      ),
      GoRoute(
        path: '/ready-deck/:id',
        builder: (context, state) {
          final deck = state.extra as ReadyDeck;
          return ReadyDeckDetailsScreen(deck: deck);
        },
      ),
    ],
  );
});
