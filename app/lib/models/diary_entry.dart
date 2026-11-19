class DiaryEntry {
  final String id;
  final String title;
  final String content;
  final String type;
  final String? language;
  final String? code;
  final List<String> tags;
  final bool isFavorite;
  final bool isSample;
  final String? deletedAt;
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
    this.isSample = false,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    List<String> parsedTags = [];

    final dynamic rawTags = json['tags'];

    if (rawTags is List) {
      parsedTags = rawTags.map((tag) => tag.toString()).toList();
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
      isSample: json['isSample'] == true,
      deletedAt: json['deletedAt']?.toString(),
      createdAt: json['createdAt']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString() ?? '',
    );
  }

  DiaryEntry copyWith({bool? isFavorite}) => DiaryEntry(
    id: id,
    title: title,
    content: content,
    type: type,
    language: language,
    code: code,
    tags: tags,
    isFavorite: isFavorite ?? this.isFavorite,
    isSample: isSample,
    deletedAt: deletedAt,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

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
