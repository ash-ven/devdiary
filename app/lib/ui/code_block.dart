import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../text/highlight.dart';
import '../theme/devdiary_theme.dart';
import '../theme/tokens.g.dart';
import 'common.dart';

Color _colorFor(DevDiaryTokens t, HlKind kind) => switch (kind) {
  HlKind.keyword => t.codeKw,
  HlKind.string => t.codeStr,
  HlKind.number => t.codeNum,
  HlKind.comment => t.codeComment,
  HlKind.function => t.codeFn,
  HlKind.plain => t.codePlain,
};

/// Blocco di codice: linguaggio, pulsante Copia, numeri di riga, sintassi colorata.
class CodeBlock extends StatelessWidget {
  const CodeBlock({super.key, required this.code, this.language});
  final String code;
  final String? language;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final lines = '\n'.allMatches(code).length + 1;
    final style = devDiaryCodeStyle.copyWith(fontSize: 13.5, height: 1.65);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: t.codeBg,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: t.codePlain.withValues(alpha: .1)),
              ),
            ),
            child: Row(
              children: [
                Text(
                  language ?? 'testo',
                  style: devDiaryCodeStyle.copyWith(
                    fontSize: 12.5,
                    color: t.codeBar,
                  ),
                ),
                const Spacer(),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: t.codePlain,
                    minimumSize: const Size(44, 36),
                    side: BorderSide(color: t.codePlain.withValues(alpha: .3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: code));
                    if (context.mounted) showMessage(context, l.codeCopied);
                  },
                  child: Text(l.copy, style: const TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 14, 18, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Text(
                    List.generate(lines, (i) => '${i + 1}').join('\n'),
                    textAlign: TextAlign.right,
                    style: style.copyWith(color: t.codeLineNo),
                  ),
                ),
                const SizedBox(width: 16),
                SelectableText.rich(
                  TextSpan(
                    style: style.copyWith(color: t.codePlain),
                    children: [
                      for (final tok in highlight(code, language))
                        TextSpan(
                          text: tok.text,
                          style: TextStyle(
                            color: _colorFor(t, tok.kind),
                            fontStyle: tok.kind == HlKind.comment
                                ? FontStyle.italic
                                : null,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
