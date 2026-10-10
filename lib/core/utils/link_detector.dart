/// Определяет, является ли сообщение одной ссылкой.
class LinkDetector {
  const LinkDetector();

  bool isLink(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.contains(RegExp(r'\s'))) return false;
    final uri = Uri.tryParse(trimmed);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }
}
