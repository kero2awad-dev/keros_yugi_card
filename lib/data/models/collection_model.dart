import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'card_model.dart';

class YugiCollection {
  final String id;
  final String userId;
  final String name;
  final String style; 
  final bool isPublic;
  final DateTime createdAt;
  final List<CollectionItem> items;
  final bool isReadyMade;

  YugiCollection({
    required this.id,
    required this.userId,
    required this.name,
    required this.style,
    this.isPublic = false,
    required this.createdAt,
    this.items = const [],
    this.isReadyMade = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'style': style,
      'is_public': isPublic,
      'created_at': createdAt.toIso8601String(),
      'is_ready_made': isReadyMade,
      'collection_items': items.map((e) => e.toJson()).toList(),
    };
  }

  factory YugiCollection.fromJson(Map<String, dynamic> json) {
    return YugiCollection(
      id: json['id']?.toString() ?? '',
      userId: json['user_id'] ?? 'local_user',
      name: json['name'] ?? '',
      style: json['style'] ?? 'English',
      isPublic: json['is_public'] ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      isReadyMade: json['is_ready_made'] ?? false,
      items: (json['collection_items'] as List?)
              ?.map((item) => CollectionItem.fromJson(item))
              .toList() ??
          [],
    );
  }

  YugiCollection copyWith({List<CollectionItem>? items, String? name, String? style}) {
    return YugiCollection(
      id: id,
      userId: userId,
      name: name ?? this.name,
      style: style ?? this.style,
      isPublic: isPublic,
      createdAt: createdAt,
      isReadyMade: isReadyMade,
      items: items ?? this.items,
    );
  }
}

class CollectionItem {
  final String id;
  final String cardId; 
  final int quantity;
  final String addedStyle; 
  final YugiCard? card;

  CollectionItem({
    required this.id,
    required this.cardId,
    required this.quantity,
    required this.addedStyle,
    this.card,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'card_id': cardId,
      'quantity': quantity,
      'added_style': addedStyle,
    };
  }

  factory CollectionItem.fromJson(Map<String, dynamic> json) {
    return CollectionItem(
      id: json['id'] ?? '',
      cardId: json['card_id']?.toString() ?? '',
      quantity: json['quantity'] ?? 1,
      addedStyle: json['added_style'] ?? 'English',
      card: json['cards'] != null ? YugiCard.fromJson(json['cards']) : null,
    );
  }
}

class ReadyDeck {
  final String id;
  final String name;
  final String description;
  final String imageUrl; 
  final double price;
  final List<String> cardIds;
  final String style;

  ReadyDeck({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.price,
    required this.cardIds,
    this.style = 'English',
  });

  String get displayImageUrl {
    String baseUrl = dotenv.env['R2_PUBLIC_BASE_URL']?.trim() ?? 'https://pub-67c14d1df1694d699615902188d77613.r2.dev';
    if (baseUrl.endsWith('/')) baseUrl = baseUrl.substring(0, baseUrl.length - 1);

    if (imageUrl.isEmpty) return '$baseUrl/BACK.jpg';

    // تحويل روابط ygoprodeck إلى R2
    if (imageUrl.contains('ygoprodeck.com')) {
      final uri = Uri.tryParse(imageUrl);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        String idFromUrl = uri.pathSegments.last.replaceAll('.jpg', '').replaceAll('.png', '');
        // إزالة الأصفار البادئة لضمان مطابقة الملفات في R2
        if (RegExp(r'^\d+$').hasMatch(idFromUrl)) {
          idFromUrl = idFromUrl.replaceFirst(RegExp('^0+'), '');
          if (idFromUrl.isEmpty) idFromUrl = "0";
        }
        return '$baseUrl/$idFromUrl.jpg';
      }
    }

    // إذا كان الرابط كاملاً ومباشراً
    if (imageUrl.startsWith('http')) return imageUrl;

    // إذا كان مجرد معرف أو اسم ملف، نتأكد من اللاحقة
    String fileName = imageUrl.trim();
    if (!fileName.toLowerCase().endsWith('.jpg') && !fileName.toLowerCase().endsWith('.png')) {
       fileName = '$fileName.jpg';
    }
    
    return '$baseUrl/$fileName';
  }

  factory ReadyDeck.fromJson(Map<String, dynamic> json) {
    return ReadyDeck(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['image_url'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 350.0,
      cardIds: (json['card_ids'] as List?)?.map((e) => e.toString()).toList() ?? [],
      style: json['style'] ?? 'English',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'price': price,
      'card_ids': cardIds,
      'style': style,
    };
  }
}
