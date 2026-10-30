import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CardImageViewer extends StatelessWidget {
  final String imageUrl;
  final String cardName;

  const CardImageViewer({super.key, required this.imageUrl, required this.cardName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(cardName, style: const TextStyle(color: Colors.white, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Hero(
            tag: imageUrl, // استخدام الرابط كـ tag للانتقال
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              placeholder: (context, url) => const CircularProgressIndicator(),
            ),
          ),
        ),
      ),
    );
  }
}
