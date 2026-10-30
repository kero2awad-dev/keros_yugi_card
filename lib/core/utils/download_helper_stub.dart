import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> downloadWebFile(Uint8List bytes, String fileName) async {
  try {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes);
    
    // مشاركة الملف للأندرويد لكي يتمكن الأدمن من حفظه أو إرساله
    await Share.shareXFiles([XFile(file.path)], text: 'ملف صور الأوردر جاهز للطباعة');
  } catch (e) {
    print("❌ Error saving/sharing file on mobile: $e");
  }
}
