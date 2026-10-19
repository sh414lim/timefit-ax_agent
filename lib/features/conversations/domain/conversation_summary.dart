class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.title,
    required this.preview,
    required this.updatedAt,
  });

  static const int maximumPreviewCharacters = 160;

  final String id;
  final String title;
  final String preview;
  final DateTime updatedAt;

  String get displayPreview {
    final List<int> characters = preview.runes.toList(growable: false);
    if (characters.length <= maximumPreviewCharacters) {
      return preview;
    }
    return String.fromCharCodes(characters.take(maximumPreviewCharacters));
  }
}
