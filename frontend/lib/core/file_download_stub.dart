void downloadTextFile({
  required String filename,
  required String content,
  String mimeType = 'text/plain',
}) {
  throw UnsupportedError('File download is only supported on web.');
}
