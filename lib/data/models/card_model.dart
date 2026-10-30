import 'package:flutter_dotenv/flutter_dotenv.dart';

class YugiCard {
  final String id; 
  final String name;
  final String type;
  final String frameType;
  final String desc;
  final int? atk;
  final int? def;
  final int? level;
  final String? race;
  final String? attribute;
  final String? archetype;
  final String? dbImageUrl;
  final double price;

  YugiCard({
    required this.id,
    required this.name,
    required this.type,
    required this.frameType,
    required this.desc,
    this.atk,
    this.def,
    this.level,
    this.race,
    this.attribute,
    this.archetype,
    this.dbImageUrl,
    this.price = 5.0,
  });

  String get _baseUrl {
    String url = dotenv.env['R2_PUBLIC_BASE_URL']?.trim() ?? 'https://pub-67c14d1df1694d699615902188d77613.r2.dev';
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    return url;
  }

  String get _cleanId {
    String cid = id.trim();
    if (cid.endsWith('_anime')) cid = cid.substring(0, cid.length - 6);
    else if (cid.endsWith('_ar')) cid = cid.substring(0, cid.length - 3);
    else if (cid.endsWith('_fl')) cid = cid.substring(0, cid.length - 3);
    
    cid = cid.trim();
    if (RegExp(r'^\d+$').hasMatch(cid)) {
      cid = cid.replaceFirst(RegExp('^0+'), '');
      if (cid.isEmpty) cid = "0";
    }
    return cid;
  }

  String get imageUrl {
    // إذا كان الرابط المخزن ليس من ygoprodeck، نستخدمه
    if (dbImageUrl != null && dbImageUrl!.isNotEmpty && !dbImageUrl!.contains('ygoprodeck.com')) {
      if (dbImageUrl!.startsWith('http')) return dbImageUrl!;
    }
    // غير ذلك، نستخدم دائماً رابط الموقع الخاص R2
    return '$_baseUrl/$_cleanId.jpg';
  }

  String getStyledImageUrl(String style) {
    final baseId = _cleanId;

    if (style == 'English') {
      return "$_baseUrl/$baseId.jpg";
    }
    if (style == 'Anime') {
      return "$_baseUrl/${baseId}_anime.jpg";
    }
    if (style == 'Arabic') {
      return "$_baseUrl/${baseId}_ar.jpg";
    }
    if (style == 'Frame Less') {
      return "$_baseUrl/${baseId}_fl.jpg";
    }
    
    return imageUrl;
  }

  static String get backImageUrl {
    String url = dotenv.env['R2_PUBLIC_BASE_URL']?.trim() ?? 'https://pub-67c14d1df1694d699615902188d77613.r2.dev';
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    return '$url/BACK.jpg';
  }

  factory YugiCard.fromJson(Map<String, dynamic> json) {
    String? imgUrl = json['image_url'];
    if (imgUrl == null && json['card_images'] != null && (json['card_images'] as List).isNotEmpty) {
      imgUrl = json['card_images'][0]['image_url'];
    }

    return YugiCard(
      id: json['id']?.toString() ?? '0',
      name: json['name'] ?? 'Unknown Card',
      type: json['type'] ?? '',
      frameType: json['frame_type'] ?? json['frameType'] ?? 'English',
      desc: json['description'] ?? json['desc'] ?? '',
      atk: json['atk'] is int ? json['atk'] : int.tryParse(json['atk']?.toString() ?? ''),
      def: json['def'] is int ? json['def'] : int.tryParse(json['def']?.toString() ?? ''),
      level: json['level'] is int ? json['level'] : int.tryParse(json['level']?.toString() ?? ''),
      race: json['race'],
      attribute: json['attribute'],
      archetype: json['archetype'],
      dbImageUrl: imgUrl,
      price: (json['price'] as num?)?.toDouble() ?? 5.0,
    );
  }
}
