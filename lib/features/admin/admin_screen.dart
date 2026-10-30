import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../app/theme.dart';
import 'admin_repository.dart';
import '../home/ready_decks_repository.dart';
import '../../core/services/supabase_service.dart';
import 'package:flutter/services.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  bool _isUploading = false;
  double _progress = 0;
  String _status = "لوحة التحكم جاهزة";

  // متحكمات المجموعات الجاهزة
  final _deckNameController = TextEditingController();
  final _deckDescController = TextEditingController();
  final _deckImageUrlController = TextEditingController();
  final _deckPriceController = TextEditingController(text: "350");
  final _deckCardIdsController = TextEditingController();
  final _ydkInputController = TextEditingController();
  String _selectedDeckStyle = 'English'; 

  // متحكمات الكارت المفرد
  final _customIdController = TextEditingController();
  final _customNameController = TextEditingController();
  final _customDescController = TextEditingController();
  String _customStyle = 'Arabic'; 

  // متحكمات المساعد
  final _helperIdController = TextEditingController();
  String _helperStyle = 'English';

  // متحكمات الأوردر اليدوي
  final _manualCustomerController = TextEditingController();
  final _manualIdsController = TextEditingController();
  String _manualStyle = 'English';

  @override
  void dispose() {
    _deckNameController.dispose();
    _deckDescController.dispose();
    _deckImageUrlController.dispose();
    _deckPriceController.dispose();
    _deckCardIdsController.dispose();
    _ydkInputController.dispose();
    _customIdController.dispose();
    _customNameController.dispose();
    _customDescController.dispose();
    _helperIdController.dispose();
    _manualCustomerController.dispose();
    _manualIdsController.dispose();
    super.dispose();
  }

  Future<void> _createReadyDeck() async {
    if (_deckNameController.text.isEmpty || _deckCardIdsController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("برجاء إدخال الاسم والمعرفات")));
      return;
    }

    setState(() { _isUploading = true; _status = "جارٍ إنشاء المجموعة..."; });
    try {
      final ids = _deckCardIdsController.text.split(RegExp(r'[,\n ]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      
      await ref.read(supabaseClientProvider).from('ready_decks').insert({
        'id': const Uuid().v4(),
        'name': _deckNameController.text.trim(),
        'description': _deckDescController.text.trim(),
        'image_url': _deckImageUrlController.text.trim(),
        'price': double.tryParse(_deckPriceController.text) ?? 350.0,
        'card_ids': ids,
        'style': _selectedDeckStyle
      });

      setState(() { _isUploading = false; _status = "✅ تم إنشاء المجموعة بنجاح!"; });
      _deckNameController.clear();
      _deckDescController.clear();
      _deckImageUrlController.clear();
      _deckCardIdsController.clear();
      _ydkInputController.clear();
      
      ref.invalidate(readyDecksProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ تم الحفظ بنجاح")));
    } catch (e) {
      setState(() { _isUploading = false; _status = "❌ خطأ في الحفظ: $e"; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ خطأ: $e")));
    }
  }

  Future<void> _createManualOrder() async {
    if (_manualCustomerController.text.isEmpty || _manualIdsController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("برجاء ملء البيانات")));
      return;
    }

    setState(() { _isUploading = true; _status = "جارٍ إنشاء الطلب اليدوي..."; });
    try {
      final ids = _manualIdsController.text.split(RegExp(r'[\n, ]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      await ref.read(adminRepositoryProvider).createManualOrder(
        customerName: _manualCustomerController.text.trim(),
        cardIds: ids,
        style: _manualStyle,
      );
      setState(() { _isUploading = false; _status = "✅ تم إنشاء الطلب اليدوي!"; });
      _manualIdsController.clear();
      _manualCustomerController.clear();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ تم إنشاء الطلب بنجاح")));
    } catch (e) {
      setState(() { _isUploading = false; _status = "❌ خطأ: $e"; });
    }
  }

  Future<void> _startImport() async {
    setState(() { _isUploading = true; _progress = 0; _status = "بدأ تحديث الكروت من JSON..."; });
    try {
      await ref.read(adminRepositoryProvider).uploadAllCardsToSupabase((c, t) {
        setState(() { _progress = c / t; _status = "تم رفع $c من $t كارت..."; });
      });
      setState(() { _isUploading = false; _status = "✅ تم تحديث الكروت بنجاح!"; });
    } catch (e) { setState(() { _isUploading = false; _status = "❌ فشل: $e"; }); }
  }

  Future<void> _importYdkDecks() async {
    setState(() { _isUploading = true; _status = "جارٍ استيراد ملفات YDK من Assets..."; });
    try {
      final count = await ref.read(adminRepositoryProvider).importYdkDecksFromAssets();
      setState(() { _isUploading = false; _status = "✅ تم استيراد $count مجموعة!"; });
      ref.invalidate(readyDecksProvider);
    } catch (e) { setState(() { _isUploading = false; _status = "❌ فشل: $e"; }); }
  }

  Future<void> _deleteAllDecks() async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(backgroundColor: AppTheme.cardGrey, title: const Text("حذف كل المجموعات؟"), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("إلغاء")), ElevatedButton(onPressed: () => Navigator.pop(c, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("حذف الكل"))]));
    if (ok == true) {
      setState(() { _isUploading = true; _status = "جارٍ الحذف..."; });
      await ref.read(adminRepositoryProvider).deleteAllReadyDecks();
      setState(() { _isUploading = false; _status = "✅ تم الحذف بنجاح"; });
      ref.invalidate(readyDecksProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      appBar: AppBar(title: const Text("لوحة تحكم الأدمن"), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // زر إدارة الطلبات
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: () => context.push('/admin/orders'),
              icon: const Icon(Icons.shopping_cart_checkout_rounded),
              label: const Text("📦 إدارة الطلبات", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 30),

            if (_isUploading)
              Container(
                width: double.infinity, padding: const EdgeInsets.all(16), margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: AppTheme.primaryGold.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3))),
                child: Column(children: [
                  Row(children: [
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGold)),
                    const SizedBox(width: 15),
                    Expanded(child: Text(_status, style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 13))),
                    Text("${(_progress * 100).toInt()}%", style: const TextStyle(color: AppTheme.primaryGold, fontSize: 12)),
                  ]),
                ]),
              ),

            _buildSectionTitle("إضافة أوردر يدوي (قديم / واتساب)"),
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppTheme.cardGrey, borderRadius: BorderRadius.circular(15)), child: Column(children: [
              _buildAdminTextField(_manualCustomerController, "اسم العميل"),
              _buildAdminTextField(_manualIdsController, "لستة المعرفات (IDs) مفصولة بفاصلة أو سطر", maxLines: 3),
              Row(children: ['English', 'Arabic', 'Anime'].map((s) => _buildStyleOption(s, s, _manualStyle, (v) => setState(() => _manualStyle = v!))).toList()),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGold, minimumSize: const Size(double.infinity, 45)), 
                onPressed: _isUploading ? null : _createManualOrder, 
                child: const Text("حفظ كأوردر جديد", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))
              ),
            ])),

            const SizedBox(height: 30),
            _buildSectionTitle("مساعد المعرفات (ID Helper)"),
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppTheme.cardGrey, borderRadius: BorderRadius.circular(15)), child: Column(children: [
              TextField(controller: _helperIdController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "رقم الكارت...")),
              Row(children: [_buildStyleOption("عربي", 'Arabic', _helperStyle, (v) => setState(() => _helperStyle = v!)), _buildStyleOption("أنمي", 'Anime', _helperStyle, (v) => setState(() => _helperStyle = v!)), _buildStyleOption("فريم ليس", 'Frame Less', _helperStyle, (v) => setState(() => _helperStyle = v!))]),
              ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGold, minimumSize: const Size(double.infinity, 45)), onPressed: () {
                String res = _helperIdController.text.trim();
                if (_helperStyle == 'Arabic') res += '_ar'; else if (_helperStyle == 'Anime') res += '_anime'; else if (_helperStyle == 'Frame Less') res += '_fl';
                Clipboard.setData(ClipboardData(text: res));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("تم نسخ: $res")));
              }, child: const Text("نسخ المعرف", style: TextStyle(color: Colors.black))),
            ])),

            const SizedBox(height: 30),
            _buildSectionTitle("إنشاء مجموعة جاهزة"),
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppTheme.cardGrey, borderRadius: BorderRadius.circular(15)), child: Column(children: [
              _buildAdminTextField(_deckNameController, "اسم المجموعة"), 
              _buildAdminTextField(_deckDescController, "الوصف"), 
              _buildAdminTextField(_deckPriceController, "السعر", isNumber: true), 
              _buildAdminTextField(_deckImageUrlController, "رابط الغلاف (ID أو رابط)"),
              
              const SizedBox(height: 10),
              TextField(
                controller: _ydkInputController, 
                maxLines: 3, 
                style: const TextStyle(color: Colors.white, fontSize: 12), 
                decoration: const InputDecoration(
                  hintText: "الصق نص ملف YDK هنا لاستخراج الأرقام...", 
                  filled: true, 
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(),
                )
              ),
              TextButton.icon(
                onPressed: () {
                  final ids = _ydkInputController.text.split('\n').map((l) => l.trim()).where((l) => RegExp(r'^\d+$').hasMatch(l)).toList();
                  if (ids.isNotEmpty) {
                    _deckCardIdsController.text = ids.join(', ');
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ تم استخراج ${ids.length} كارت")));
                  }
                }, 
                icon: const Icon(Icons.auto_fix_high),
                label: const Text("استخراج المعرفات من YDK"),
              ),
              
              _buildAdminTextField(_deckCardIdsController, "لستة المعرفات (مفصولة بفاصلة)", maxLines: 2),
              
              Row(children: ['English', 'Arabic', 'Anime'].map((s) => _buildStyleOption(s, s, _selectedDeckStyle, (v) => setState(() => _selectedDeckStyle = v!))).toList()),
              const SizedBox(height: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGold, minimumSize: const Size(double.infinity, 50)), 
                onPressed: _isUploading ? null : _createReadyDeck, 
                child: const Text("إنشاء المجموعة الآن", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))
              ),
            ])),

            const SizedBox(height: 30),
            _buildSectionTitle("إضافة كارت مفرد"),
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppTheme.cardGrey, borderRadius: BorderRadius.circular(15)), child: Column(children: [
              Row(children: [_buildStyleOption("عربي", 'Arabic', _customStyle, (v) => setState(() => _customStyle = v!)), _buildStyleOption("فريم ليس", 'Frame Less', _customStyle, (v) => setState(() => _customStyle = v!))]),
              _buildAdminTextField(_customIdController, "المعرف"), _buildAdminTextField(_customNameController, "الاسم"), _buildAdminTextField(_customDescController, "الوصف", maxLines: 2),
              ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGold, minimumSize: const Size(double.infinity, 45)), onPressed: () async {
                String id = _customIdController.text.trim();
                if (_customStyle == 'Arabic' && !id.endsWith('_ar')) id += '_ar'; else if (_customStyle == 'Frame Less' && !id.endsWith('_fl')) id += '_fl';
                await ref.read(supabaseClientProvider).from('cards').upsert({'id': id, 'name': _customNameController.text.trim(), 'description': _customDescController.text.trim(), 'type': "Custom", 'frame_type': _customStyle, 'price': 5.0});
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ تم الحفظ")));
              }, child: const Text("حفظ الكارت", style: TextStyle(color: Colors.black))),
            ])),

            const SizedBox(height: 30),
            _buildSectionTitle("عمليات النظام"),
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(0.1), borderRadius: BorderRadius.circular(15)), child: Column(children: [
              Row(children: [
                Expanded(child: ElevatedButton(onPressed: _isUploading ? null : _importYdkDecks, child: const Text("استيراد YDK من Assets", style: TextStyle(fontSize: 10)))),
                const SizedBox(width: 5),
                Expanded(child: ElevatedButton(onPressed: _isUploading ? null : _startImport, child: const Text("تحديث JSON", style: TextStyle(fontSize: 10)))),
                const SizedBox(width: 5),
                Expanded(child: ElevatedButton(onPressed: _isUploading ? null : _deleteAllDecks, style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900), child: const Text("حذف كل المجموعات", style: TextStyle(fontSize: 10)))),
              ])
            ])),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String t) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Align(alignment: Alignment.centerRight, child: Text(t, style: const TextStyle(color: AppTheme.primaryGold, fontSize: 16, fontWeight: FontWeight.bold))));
  Widget _buildStyleOption(String l, String v, String g, Function(String?) o) => Expanded(child: RadioListTile<String>(title: Text(l, style: const TextStyle(color: Colors.white, fontSize: 10)), value: v, groupValue: g, onChanged: o, activeColor: AppTheme.primaryGold, contentPadding: EdgeInsets.zero, dense: true));
  Widget _buildAdminTextField(TextEditingController c, String l, {bool isNumber = false, int maxLines = 1}) => Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: c, maxLines: maxLines, keyboardType: isNumber ? TextInputType.number : TextInputType.text, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: l, labelStyle: const TextStyle(color: Colors.white60, fontSize: 12), filled: true, fillColor: AppTheme.cardGrey, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))));
}
