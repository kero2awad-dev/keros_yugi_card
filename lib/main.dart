import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'features/auth/auth_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _setupWebProtection();
    }
  }

  void _setupWebProtection() {
    // نمنع العمليات فقط إذا لم يكن المستخدم "أدمن"
    // نتحقق من الحالة في وقت الحدث (Runtime)
    
    html.window.onContextMenu.listen((event) {
      final isAdmin = ref.read(isAdminProvider);
      if (!isAdmin) event.preventDefault();
    });

    html.window.onKeyDown.listen((event) {
      final isAdmin = ref.read(isAdminProvider);
      if (isAdmin) return;

      if ((event.ctrlKey || event.metaKey) && 
          (event.keyCode == 83 || // S
           event.keyCode == 80 || // P
           event.keyCode == 67 || // C
           event.keyCode == 85)) { // U
        event.preventDefault();
      }
      
      // منع مفتاح PrintScreen (بقدر الإمكان في الويب)
      if (event.keyCode == 44) {
        event.preventDefault();
        html.window.alert("التقاط الشاشة غير مسموح به لحماية الحقوق");
      }
    });

    html.document.onDragStart.listen((event) {
      final isAdmin = ref.read(isAdminProvider);
      if (!isAdmin) event.preventDefault();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Kero Yugi Cards',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
