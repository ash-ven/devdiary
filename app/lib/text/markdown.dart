/// Sottoinsieme di Markdown per il contenuto delle note: titoli (1–3), paragrafi,
/// elenchi puntati e numerati, blocchi di codice; in linea grassetto, corsivo,
/// codice e link. Niente HTML: ciò che non si riconosce resta testo letterale.
library;

enum MdBlockKind { heading, paragraph, bullet, numbered, codeFence }

enum MdInlineKind { text, bold, italic, code, link }

class MdInline {
  const MdInline(this.kind, this.text, [this.url]);
  final MdInlineKind kind;
  final String text;
  final String? url;
}

class MdBlock {
  const MdBlock(
    this.kind, {
    this.level = 0,
    this.inlines = const [],
    this.items = const [],
    this.language,
    this.code = '',
  });
  final MdBlockKind kind;
  final int level;
  final List<MdInline> inlines;
  final List<List<MdInline>> items;
  final String? language;
  final String code;
}

final _heading = RegExp(r'^(#{1,3})\s+(.*)$');
final _bullet = RegExp(r'^\s*[-*]\s+(.*)$');
final _numbered = RegExp(r'^\s*\d+[.)]\s+(.*)$');
final _fence = RegExp(r'^\s*```\s*([\w+-]*)\s*$');

List<MdBlock> parseMarkdown(String source) {
  final lines = source.replaceAll('\r\n', '\n').split('\n');
  final blocks = <MdBlock>[];
  final paragraph = <String>[];
  List<List<MdInline>>? listItems;
  var listKind = MdBlockKind.bullet;

  void flushParagraph() {
    if (paragraph.isEmpty) return;
    blocks.add(
      MdBlock(MdBlockKind.paragraph, inlines: parseInline(paragraph.join(' '))),
    );
    paragraph.clear();
  }

  void flushList() {
    if (listItems == null) return;
    blocks.add(MdBlock(listKind, items: listItems!));
    listItems = null;
  }

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final fence = _fence.firstMatch(line);
    if (fence != null) {
      flushParagraph();
      flushList();
      final code = <String>[];
      i++;
      while (i < lines.length && _fence.firstMatch(lines[i]) == null) {
        code.add(lines[i]);
        i++;
      }
      final lang = fence.group(1)!;
      blocks.add(
        MdBlock(
          MdBlockKind.codeFence,
          language: lang.isEmpty ? null : lang,
          code: code.join('\n'),
        ),
      );
      continue;
    }
    if (line.trim().isEmpty) {
      flushParagraph();
      flushList();
      continue;
    }
    final heading = _heading.firstMatch(line);
    if (heading != null) {
      flushParagraph();
      flushList();
      blocks.add(
        MdBlock(
          MdBlockKind.heading,
          level: heading.group(1)!.length,
          inlines: parseInline(heading.group(2)!.trim()),
        ),
      );
      continue;
    }
    final bullet = _bullet.firstMatch(line);
    final numbered = bullet == null ? _numbered.firstMatch(line) : null;
    if (bullet != null || numbered != null) {
      flushParagraph();
      final kind = bullet != null ? MdBlockKind.bullet : MdBlockKind.numbered;
      if (listItems != null && listKind != kind) flushList();
      listKind = kind;
      (listItems ??= []).add(parseInline((bullet ?? numbered)!.group(1)!));
      continue;
    }
    flushList();
    paragraph.add(line.trim());
  }
  flushParagraph();
  flushList();
  return blocks;
}

bool isSafeUrl(String url) {
  final uri = Uri.tryParse(url);
  return uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty;
}

bool _isWordChar(String c) => RegExp(r'[A-Za-z0-9]').hasMatch(c);

List<MdInline> parseInline(String s) {
  final out = <MdInline>[];
  final buf = StringBuffer();
  void flush() {
    if (buf.isEmpty) return;
    out.add(MdInline(MdInlineKind.text, buf.toString()));
    buf.clear();
  }

  var i = 0;
  while (i < s.length) {
    final c = s[i];
    if (c == '`') {
      final end = s.indexOf('`', i + 1);
      if (end > i + 1) {
        flush();
        out.add(MdInline(MdInlineKind.code, s.substring(i + 1, end)));
        i = end + 1;
        continue;
      }
    } else if (s.startsWith('**', i)) {
      final end = s.indexOf('**', i + 2);
      if (end > i + 2) {
        flush();
        out.add(MdInline(MdInlineKind.bold, s.substring(i + 2, end)));
        i = end + 2;
        continue;
      }
    } else if ((c == '*' || c == '_') &&
        (i == 0 || !_isWordChar(s[i - 1])) &&
        i + 1 < s.length &&
        s[i + 1] != ' ') {
      final end = s.indexOf(c, i + 1);
      if (end > i + 1 && (end + 1 >= s.length || !_isWordChar(s[end + 1]))) {
        flush();
        out.add(MdInline(MdInlineKind.italic, s.substring(i + 1, end)));
        i = end + 1;
        continue;
      }
    } else if (c == '[') {
      final close = s.indexOf('](', i + 1);
      final end = close > i ? s.indexOf(')', close + 2) : -1;
      if (close > i && end > close + 2) {
        final label = s.substring(i + 1, close);
        final url = s.substring(close + 2, end).trim();
        flush();
        out.add(
          isSafeUrl(url)
              ? MdInline(MdInlineKind.link, label, url)
              : MdInline(MdInlineKind.text, label),
        );
        i = end + 1;
        continue;
      }
    }
    buf.write(c);
    i++;
  }
  flush();
  return out;
}
