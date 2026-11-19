/// Evidenziazione minima della sintassi per i linguaggi più usati nelle note.
library;

enum HlKind { plain, keyword, string, number, comment, function }

class HlToken {
  const HlToken(this.kind, this.text);
  final HlKind kind;
  final String text;
}

const _keywords = <String, Set<String>>{
  'dart': {
    'abstract', 'async', 'await', 'break', 'case', 'catch', 'class', 'const', //
    'continue', 'else', 'enum', 'extends', 'false', 'final', 'for', 'if',
    'import', 'in', 'is', 'late', 'new', 'null', 'required', 'return',
    'static', 'super', 'switch', 'this', 'throw', 'true', 'try', 'var',
    'void', 'while', 'with', 'yield', 'String', 'int', 'double', 'bool',
    'List', 'Map', 'Future', 'dynamic',
  },
  'javascript': {
    'async',
    'await',
    'break',
    'case',
    'catch',
    'class',
    'const',
    'continue',
    'default',
    'delete',
    'else',
    'export',
    'extends',
    'false',
    'finally',
    'for',
    'function',
    'if',
    'import',
    'in',
    'instanceof',
    'let',
    'new',
    'null',
    'of',
    'return',
    'super',
    'switch',
    'this',
    'throw',
    'true',
    'try',
    'typeof',
    'undefined',
    'var',
    'void',
    'while',
    'yield',
  },
  'typescript': {
    'async',
    'await',
    'break',
    'case',
    'catch',
    'class',
    'const',
    'continue',
    'default',
    'else',
    'enum',
    'export',
    'extends',
    'false',
    'finally',
    'for',
    'function',
    'if',
    'implements',
    'import',
    'in',
    'interface',
    'let',
    'new',
    'null',
    'of',
    'private',
    'public',
    'readonly',
    'return',
    'string',
    'number',
    'boolean',
    'type',
    'this',
    'throw',
    'true',
    'try',
    'undefined',
    'var',
    'void',
    'while',
  },
  'json': {'true', 'false', 'null'},
  'yaml': {'true', 'false', 'null', 'yes', 'no'},
  'sql': {
    'select',
    'from',
    'where',
    'and',
    'or',
    'not',
    'insert',
    'into',
    'values',
    'update',
    'set',
    'delete',
    'create',
    'table',
    'primary',
    'key',
    'join',
    'left',
    'right',
    'inner',
    'on',
    'group',
    'by',
    'order',
    'limit',
    'as',
    'null',
    'is',
    'in',
    'distinct',
    'count',
    'having',
    'references',
  },
};

const _aliases = {'js': 'javascript', 'ts': 'typescript', 'yml': 'yaml'};

final _ident = RegExp(r'[A-Za-z_$][\w$]*');
final _number = RegExp(r'\d[\d_]*(\.\d+)?');

List<HlToken> highlight(String code, String? language) {
  final lang = _aliases[language?.toLowerCase()] ?? language?.toLowerCase();
  final keywords = _keywords[lang];
  if (keywords == null) return [HlToken(HlKind.plain, code)];
  final caseless = lang == 'sql';
  final lineComment = switch (lang) {
    'yaml' => '#',
    'sql' => '--',
    'json' => null,
    _ => '//',
  };
  final blockComments = lang != 'yaml' && lang != 'json';

  final out = <HlToken>[];
  final plain = StringBuffer();
  void push(HlKind kind, String text) {
    if (kind == HlKind.plain) {
      plain.write(text);
      return;
    }
    if (plain.isNotEmpty) {
      out.add(HlToken(HlKind.plain, plain.toString()));
      plain.clear();
    }
    out.add(HlToken(kind, text));
  }

  var i = 0;
  while (i < code.length) {
    final c = code[i];
    if (lineComment != null && code.startsWith(lineComment, i)) {
      final end = code.indexOf('\n', i);
      final stop = end < 0 ? code.length : end;
      push(HlKind.comment, code.substring(i, stop));
      i = stop;
      continue;
    }
    if (blockComments && code.startsWith('/*', i)) {
      final end = code.indexOf('*/', i + 2);
      final stop = end < 0 ? code.length : end + 2;
      push(HlKind.comment, code.substring(i, stop));
      i = stop;
      continue;
    }
    if (c == '"' || c == "'" || (c == '`' && lang != 'sql')) {
      var j = i + 1;
      while (j < code.length && code[j] != c && code[j] != '\n') {
        if (code[j] == r'\') j++;
        j++;
      }
      final stop = j < code.length && code[j] == c
          ? j + 1
          : (j < code.length ? j : code.length);
      push(HlKind.string, code.substring(i, stop));
      i = stop;
      continue;
    }
    final num = _number.matchAsPrefix(code, i);
    if (num != null && (i == 0 || !RegExp(r'[\w$]').hasMatch(code[i - 1]))) {
      push(HlKind.number, num.group(0)!);
      i = num.end;
      continue;
    }
    final id = _ident.matchAsPrefix(code, i);
    if (id != null) {
      final word = id.group(0)!;
      final isKeyword = keywords.contains(caseless ? word.toLowerCase() : word);
      final rest = code.substring(id.end).trimLeft();
      if (isKeyword) {
        push(HlKind.keyword, word);
      } else if (rest.startsWith('(') ||
          (lang == 'yaml' && rest.startsWith(':'))) {
        push(HlKind.function, word);
      } else {
        push(HlKind.plain, word);
      }
      i = id.end;
      continue;
    }
    push(HlKind.plain, c);
    i++;
  }
  if (plain.isNotEmpty) out.add(HlToken(HlKind.plain, plain.toString()));
  return out;
}
