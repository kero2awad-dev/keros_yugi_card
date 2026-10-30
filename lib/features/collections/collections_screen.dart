import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../app/theme.dart';
import 'collections_repository.dart';

class CollectionsScreen extends ConsumerWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionsAsync = ref.watch(myCollectionsProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      appBar: AppBar(
        title: const Text("خزانة المجموعات"),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryGold),
          onPressed: () => context.go('/'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateCollectionDialog(context, ref),
        backgroundColor: AppTheme.primaryGold,
        icon: const Icon(Icons.add_box, color: Colors.black),
        label: const Text("مجموعة جديدة", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: collectionsAsync.when(
        data: (collections) {
          if (collections.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.style_outlined, size: 100, color: AppTheme.primaryGold.withOpacity(0.3)),
                  const SizedBox(height: 20),
                  const Text("خزانتك فارغة حالياً!", style: TextStyle(color: Colors.white70)),
                ],
              ),
            );
          }
  
          return AnimationLimiter(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: collections.length,
              itemBuilder: (context, index) {
                final collection = collections[index];
                return AnimationConfiguration.staggeredList(
                  position: index,
                  duration: const Duration(milliseconds: 375),
                  child: SlideAnimation(
                    verticalOffset: 50.0,
                    child: FadeInAnimation(
                      child: _CollectionDeckCard(collection: collection),
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold)),
        error: (err, stack) => Center(child: Text("خطأ: $err")),
      ),
    );
  }

  void _showCreateCollectionDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final idsController = TextEditingController();
    String selectedStyle = 'English';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppTheme.cardGrey,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("إنشاء مجموعة جديدة", style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "اسم المجموعة", 
                    labelStyle: TextStyle(color: AppTheme.primaryGold),
                  ),
                ),
                const SizedBox(height: 20),
                const Align(alignment: Alignment.centerRight, child: Text("الستايل الافتراضي:", style: TextStyle(color: Colors.white54, fontSize: 12))),
                DropdownButton<String>(
                  value: selectedStyle,
                  isExpanded: true,
                  dropdownColor: AppTheme.cardGrey,
                  style: const TextStyle(color: Colors.white),
                  items: ['English', 'Anime', 'Arabic', 'Frame Less'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setState(() => selectedStyle = v!),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: idsController,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: "انسخ أرقام الكروت هنا (اختياري)...\n89631139\n46986414",
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true, fillColor: Colors.black26,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 15),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryGold, 
                    side: const BorderSide(color: AppTheme.primaryGold), 
                    minimumSize: const Size(double.infinity, 45)
                  ),
                  onPressed: () async {
                    String name = nameController.text.isEmpty ? "مجموعة من ملف" : nameController.text;
                    final newColl = await ref.read(collectionsRepositoryProvider).createCollectionFromYdkFile(name, selectedStyle);
                    if (newColl != null) {
                      ref.invalidate(myCollectionsProvider);
                      if (context.mounted) {
                         Navigator.pop(context);
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ تم استيراد الملف")));
                      }
                    }
                  },
                  icon: const Icon(Icons.file_upload_outlined),
                  label: const Text("استيراد من ملف YDK"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGold),
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  if (idsController.text.isNotEmpty) {
                    await ref.read(collectionsRepositoryProvider).createCollectionFromText(
                      nameController.text, 
                      selectedStyle, 
                      idsController.text
                    );
                  } else {
                    await ref.read(collectionsRepositoryProvider).createCollection(nameController.text, selectedStyle);
                  }
                  ref.invalidate(myCollectionsProvider);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text("إنشاء", style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionDeckCard extends ConsumerWidget {
  final dynamic collection;
  const _CollectionDeckCard({required this.collection});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    int totalItems = collection.items.fold(0, (sum, item) => sum + item.quantity);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardGrey,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () => context.push('/collections/${collection.id}?name=${Uri.encodeComponent(collection.name)}'),
        leading: const Icon(Icons.style, color: AppTheme.primaryGold, size: 35),
        title: Text(
          collection.name, 
          style: const TextStyle(color: AppTheme.primaryGold, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          "$totalItems بطاقة | ${collection.style}",
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.file_download, color: Colors.blueAccent),
              tooltip: "تحميل أرقام الكروت",
              onPressed: () => ref.read(collectionsRepositoryProvider).downloadCollectionAsText(collection),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardGrey,
        title: const Text("حذف المجموعة؟", style: TextStyle(color: Colors.white)),
        content: Text("هل أنت متأكد من حذف المجموعة '${collection.name}'؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("إلغاء")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("حذف", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(collectionsRepositoryProvider).deleteCollection(collection.id);
      ref.invalidate(myCollectionsProvider);
    }
  }
}
