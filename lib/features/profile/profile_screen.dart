import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../auth/auth_repository.dart';
import '../collections/collections_repository.dart';
import '../favorites/favorites_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isAdmin = ref.watch(isAdminProvider);
    
    final displayName = user?.userMetadata?['display_name'] ?? 'مبارز أسطوري';
    final email = user?.email ?? 'بدون بريد إلكتروني';

    final collectionsAsync = ref.watch(myCollectionsProvider);
    final favoritesAsync = ref.watch(myFavoritesProvider);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        context.go('/');
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundBlack,
        appBar: AppBar(
          title: const Text("الملف الشخصي"),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.primaryGold),
            onPressed: () => context.go('/'),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myCollectionsProvider);
            ref.invalidate(myFavoritesProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 30),
                _buildAvatarSection(displayName, email),
                const SizedBox(height: 30),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem("مجموعة", collectionsAsync.maybeWhen(
                        data: (d) => d.length.toString(),
                        orElse: () => "0",
                      )),
                      _buildStatItem("مفضلة", favoritesAsync.maybeWhen(
                        data: (d) => d.length.toString(),
                        orElse: () => "0",
                      )),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                if (isAdmin)
                  _buildMenuItem(
                    icon: Icons.admin_panel_settings,
                    title: "لوحة تحكم الأدمن",
                    onTap: () => context.push('/admin'), // تم تصحيح المسار هنا
                    color: AppTheme.primaryGold,
                    subtitle: "إدارة الكروت والمجموعات الجاهزة",
                  ),
                
                _buildMenuItem(
                  icon: Icons.style,
                  title: "مجموعاتي المحلية",
                  onTap: () => context.push('/collections'),
                ),

                _buildMenuItem(
                  icon: Icons.logout,
                  title: "تسجيل الخروج",
                  onTap: () async {
                    await ref.read(authRepositoryProvider).signOut();
                    if (context.mounted) context.go('/');
                  },
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection(String name, String email) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.primaryGold),
          child: const CircleAvatar(
            radius: 50,
            backgroundColor: AppTheme.cardGrey,
            child: Icon(Icons.person, size: 60, color: AppTheme.primaryGold),
          ),
        ),
        const SizedBox(height: 15),
        Text(name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        Text(email, style: const TextStyle(color: Colors.white54, fontSize: 14)),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: AppTheme.primaryGold, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon, 
    required String title, 
    VoidCallback? onTap, 
    Color color = Colors.white,
    String? subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardGrey,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: ListTile(
        onTap: onTap,
        enabled: onTap != null,
        leading: Icon(icon, color: color),
        title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(color: Colors.white24, fontSize: 10)) : null,
        trailing: const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
      ),
    );
  }
}
