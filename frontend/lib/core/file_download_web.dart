import 'dart:convert';
import 'dart:html' as html;

void downloadTextFile({
  required String filename,
  required String content,
  String mimeType = 'text/plain',
}) {
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
  anchor.remove();
}
