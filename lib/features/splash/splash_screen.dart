import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import '../../app/theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _controller.forward();

    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        context.go('/home'); 
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseUrl = dotenv.env['R2_PUBLIC_BASE_URL']?.trim() ?? 'https://pub-67c14d1df1694d699615902188d77613.r2.dev';
    final cleanBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    // صورة إكسوديا من الموقع الخاص بك
    final splashImageUrl = '$cleanBaseUrl/33396948.jpg';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.primaryGold, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryGold.withOpacity(0.3),
                      blurRadius: 40,
                      spreadRadius: 10,
                    )
                  ],
                ),
                child: ClipOval(
                  child: Image.network(
                    splashImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Image.network('$cleanBaseUrl/BACK.jpg', fit: BoxFit.cover),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                "KERO YUGI CARDS",
                style: TextStyle(
                  color: AppTheme.primaryGold,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                  fontFamily: 'serif',
                ),
              ),
              const SizedBox(height: 20),
              const CircularProgressIndicator(
                color: AppTheme.primaryGold,
                strokeWidth: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
