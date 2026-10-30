import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:async';

Future<void> downloadWebFile(Uint8List bytes, String fileName) async {
  try {
    // تحديد النوع بناءً على امتداد الملف لضمان عمل التحميل بشكل صحيح (ZIP أو TXT)
    String mimeType = 'application/octet-stream';
    if (fileName.endsWith('.zip')) mimeType = 'application/zip';
    else if (fileName.endsWith('.txt')) mimeType = 'text/plain';

    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", fileName)
      ..style.display = 'none';
    
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    
    // تأخير مسح الرابط لضمان بدء التحميل
    Timer(const Duration(minutes: 1), () {
      html.Url.revokeObjectUrl(url);
    });
    
    print("✅ Download triggered: $fileName");
  } catch (e) {
    print("❌ Error in downloadWebFile: $e");
  }
}
