// Genera app/lib/theme/tokens.g.dart da tools/contrast/tokens.json (unica fonte dei colori).
// Uso: node tools/contrast/to-dart.js           → scrive il file
//      node tools/contrast/to-dart.js --check   → codice 1 se il file non corrisponde
const fs = require('node:fs');
const path = require('node:path');

const tokensFile = path.join(__dirname, 'tokens.json');
const outFile = path.join(__dirname, '..', '..', 'app', 'lib', 'theme', 'tokens.g.dart');

// markBg_note → markBgNote, code_lineNo → codeLineNo
function camel(key) {
  return key.replace(/_([a-zA-Z])/g, (_, c) => c.toUpperCase());
}

function dartColor(value) {
  const hex = /^#([0-9a-f]{6})$/i.exec(value);
  if (hex) return `Color(0xFF${hex[1].toUpperCase()})`;
  const rgba = /^rgba\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([\d.]+)\s*\)$/.exec(value);
  if (rgba) {
    const alpha = Number(rgba[4]).toString();
    return `Color.fromRGBO(${rgba[1]}, ${rgba[2]}, ${rgba[3]}, ${alpha.startsWith('0.') ? alpha : '0' + alpha})`;
  }
  throw new Error(`Colore non riconosciuto: ${value}`);
}

function generate(palette) {
  const keys = Object.keys(palette.light).map((k) => ({ key: k, name: camel(k) }));
  const out = [];
  out.push('// GENERATED FILE: non modificare a mano.');
  out.push('// Fonte: tools/contrast/tokens.json. Rigenera con: node tools/contrast/to-dart.js');
  out.push('');
  out.push("import 'package:material_ui/material_ui.dart';");
  out.push('');
  out.push(`/// Token di colore della palette "${palette.name}" (tema chiaro e scuro).`);
  out.push('class DevDiaryTokens extends ThemeExtension<DevDiaryTokens> {');
  out.push('  const DevDiaryTokens({');
  for (const { name } of keys) out.push(`    required this.${name},`);
  out.push('  });');
  out.push('');
  for (const theme of ['light', 'dark']) {
    out.push(`  static const ${theme} = DevDiaryTokens(`);
    for (const { key, name } of keys) out.push(`    ${name}: ${dartColor(palette[theme][key])},`);
    out.push('  );');
    out.push('');
  }
  for (const { name } of keys) out.push(`  final Color ${name};`);
  out.push('');
  out.push('  @override');
  out.push('  DevDiaryTokens copyWith({');
  for (const { name } of keys) out.push(`    Color? ${name},`);
  out.push('  }) {');
  out.push('    return DevDiaryTokens(');
  for (const { name } of keys) out.push(`      ${name}: ${name} ?? this.${name},`);
  out.push('    );');
  out.push('  }');
  out.push('');
  out.push('  @override');
  out.push('  DevDiaryTokens lerp(ThemeExtension<DevDiaryTokens>? other, double t) {');
  out.push('    if (other is! DevDiaryTokens) return this;');
  out.push('    return DevDiaryTokens(');
  for (const { name } of keys) out.push(`      ${name}: Color.lerp(${name}, other.${name}, t)!,`);
  out.push('    );');
  out.push('  }');
  out.push('}');
  out.push('');
  return out.join('\n');
}

const palette = JSON.parse(fs.readFileSync(tokensFile, 'utf8'));
const expected = generate(palette);

if (process.argv.includes('--check')) {
  const actual = fs.existsSync(outFile) ? fs.readFileSync(outFile, 'utf8') : null;
  if (actual !== expected) {
    console.error('tokens.g.dart non corrisponde a tokens.json: esegui node tools/contrast/to-dart.js');
    process.exit(1);
  }
  console.log('tokens.g.dart aggiornato');
} else {
  fs.writeFileSync(outFile, expected);
  console.log(`Scritto ${path.relative(process.cwd(), outFile)}`);
}
