class DiaryEntry {
  final String id;
  final String title;
  final String content;
  final String type;
  final String? language;
  final String? code;
  final List<String> tags;
  final bool isFavorite;
  final String createdAt;
  final String updatedAt;

  DiaryEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    this.language,
    this.code,
    required this.tags,
    required this.isFavorite,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    List<String> parsedTags = [];

    final dynamic rawTags = json['tags'];

    if (rawTags is List) {
      parsedTags = rawTags
          .map((tag) => tag.toString())
          .toList();
    } else if (rawTags is String) {
      parsedTags = rawTags
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();
    }

    return DiaryEntry(
      id: json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      type: json['type']?.toString() ?? 'note',
      language: json['language']?.toString(),
      code: json['code']?.toString(),
      tags: parsedTags,
      isFavorite: json['isFavorite'] == true,
      createdAt: json['createdAt']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'type': type,
      'language': language,
      'code': code,
      'tags': tags,
      'isFavorite': isFavorite,
    };
  }
}