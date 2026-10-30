import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';

class VersionService {
  final SupabaseClient _client;

  VersionService(this._client);

  Future<Map<String, dynamic>?> checkVersion() async {
    try {
      // 1. جلب بيانات النسخة الحالية للتطبيق
      final packageInfo = await PackageInfo.fromPlatform();
      int currentBuildNumber = int.parse(packageInfo.buildNumber);

      // 2. جلب النسخة المطلوبة من السيرفر
      final response = await _client
          .from('app_config')
          .select()
          .single();

      int minRequiredVersion = response['min_version'] as int;
      bool isMaintenance = response['is_maintenance_mode'] ?? false;

      return {
        'isUpdateRequired': currentBuildNumber < minRequiredVersion,
        'isMaintenance': isMaintenance,
        'updateUrl': response['update_url'],
      };
    } catch (e) {
      debugPrint("❌ Error checking version: $e");
      return null;
    }
  }
}
