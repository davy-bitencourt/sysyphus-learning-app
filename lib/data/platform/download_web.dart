// The legacy dart:html API is isolated to this browser-only implementation.
// flutter run -d chrome compiles this conditional import for JavaScript.
import 'dart:html' as html;
import 'dart:typed_data';

Future<bool> downloadFile(String fileName, List<int> bytes) async {
  final blob = html.Blob(<Object>[Uint8List.fromList(bytes)], 'application/zip');
  final url = html.Url.createObjectUrlFromBlob(blob);
  try {
    final link = html.AnchorElement(href: url)..download = fileName;
    html.document.body?.append(link);
    link.click();
    link.remove();
    return true;
  } finally {
    // Revocation after the download has been started avoids a leaked Blob URL.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    html.Url.revokeObjectUrl(url);
  }
}
