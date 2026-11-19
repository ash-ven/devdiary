import 'package:dev_diary/models/diary_entry.dart';
import 'package:dev_diary/text/activity.dart';
import 'package:dev_diary/text/day_groups.dart';
import 'package:dev_diary/ui/command_palette.dart';
import 'package:dev_diary/text/highlight.dart';
import 'package:dev_diary/text/markdown.dart';
import 'package:flutter_test/flutter_test.dart';

DiaryEntry _entry(String createdAt) => DiaryEntry(
  id: createdAt,
  title: 't',
  content: 'c',
  type: 'note',
  tags: const [],
  isFavorite: false,
  createdAt: createdAt,
  updatedAt: createdAt,
);

void main() {
  test('parses headings lists bold italic code links', () {
    final blocks = parseMarkdown(
      '## Causa\n\nTesto **forte** e *corsivo* con `x` e [doc](https://dart.dev).\n\n- uno\n- due\n\n1. primo\n\n```dart\nvoid main() {}\n```',
    );
    expect(blocks.map((b) => b.kind), [
      MdBlockKind.heading,
      MdBlockKind.paragraph,
      MdBlockKind.bullet,
      MdBlockKind.numbered,
      MdBlockKind.codeFence,
    ]);
    expect(blocks[0].level, 2);
    final kinds = blocks[1].inlines.map((i) => i.kind).toList();
    expect(kinds, contains(MdInlineKind.bold));
    expect(kinds, contains(MdInlineKind.italic));
    expect(kinds, contains(MdInlineKind.code));
    expect(blocks[1].inlines.last.kind, MdInlineKind.text);
    final link = blocks[1].inlines.firstWhere(
      (i) => i.kind == MdInlineKind.link,
    );
    expect(link.url, 'https://dart.dev');
    expect(blocks[2].items.length, 2);
    expect(blocks[4].language, 'dart');
    expect(blocks[4].code, 'void main() {}');
  });

  test(
    'markdown keeps broken syntax literal and only links http and https',
    () {
      final b = parseMarkdown(
        '**aperto e [x](javascript:alert(1)) e <b>html</b> e snake_case_name',
      );
      final text = b.single.inlines.map((i) => i.text).join();
      expect(text, contains('**aperto'));
      expect(text, contains('<b>html</b>'));
      expect(text, contains('snake_case_name'));
      expect(
        b.single.inlines.where((i) => i.kind == MdInlineKind.link),
        isEmpty,
      );
    },
  );

  test('highlights dart and leaves unknown languages plain', () {
    final t = highlight("final s = 'ciao'; // nota\nprint(42);", 'dart');
    HlKind kindOf(String text) => t.firstWhere((x) => x.text == text).kind;
    expect(kindOf('final'), HlKind.keyword);
    expect(kindOf("'ciao'"), HlKind.string);
    expect(kindOf('// nota'), HlKind.comment);
    expect(kindOf('print'), HlKind.function);
    expect(kindOf('42'), HlKind.number);
    expect(highlight('x = 1', 'cobol').single.kind, HlKind.plain);
  });

  test('groups today yesterday and older dates', () {
    final now = DateTime(2026, 11, 19, 12);
    String iso(DateTime d) => d.toUtc().toIso8601String();
    final groups = groupByDay([
      _entry(iso(DateTime(2026, 11, 19, 9))),
      _entry(iso(DateTime(2026, 11, 18, 22))),
      _entry(iso(DateTime(2026, 8, 14, 10))),
      _entry(iso(DateTime(2025, 8, 14, 10))),
    ], now);
    expect(groups.map((g) => g.label), [
      'Oggi',
      'Ieri',
      '14 agosto',
      '14 agosto 2025',
    ]);
  });

  test('activity grid counts the last 26 weeks with fixed levels', () {
    final now = DateTime(2026, 11, 19, 12); // giovedì
    String iso(DateTime d) => d.toUtc().toIso8601String();
    final created = iso(DateTime(2026, 11, 17, 9)); // martedì
    final grid = activityGrid([
      _entry(created),
      _entry(iso(DateTime(2025, 1, 1))), // troppo vecchia
    ], now);
    expect(grid.length, 26);
    expect(grid.last[1], 1);
    expect(grid.expand((w) => w).fold(0, (a, b) => a + b), 1);
    expect([0, 1, 2, 3, 4, 5, 6, 9].map(activityLevel), [
      0,
      1,
      2,
      2,
      3,
      3,
      4,
      4,
    ]);
  });

  test('palette searches code too', () {
    final withCode = DiaryEntry(
      id: 'x',
      title: 'Titolo',
      content: 'testo',
      type: 'snippet',
      code: 'Object.values(id.buffer)',
      tags: const [],
      isFavorite: false,
      createdAt: '',
      updatedAt: '',
    );
    expect(paletteMatches([withCode], 'BUFFER').single.id, 'x');
    expect(paletteMatches([withCode], 'assente'), isEmpty);
  });
}
