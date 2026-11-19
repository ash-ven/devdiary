import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../text/markdown.dart';
import '../theme/devdiary_theme.dart';
import 'code_block.dart';
import 'common.dart';

/// Mostra il contenuto Markdown di una nota.
class MarkdownView extends StatelessWidget {
  const MarkdownView(this.source, {super.key});
  final String source;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final body = TextStyle(color: t.ink2, fontSize: 15.5, height: 1.6);
    final children = <Widget>[];
    for (final b in parseMarkdown(source)) {
      switch (b.kind) {
        case MdBlockKind.heading:
          children.add(
            Padding(
              padding: const EdgeInsets.only(top: 22, bottom: 6),
              child: Semantics(
                header: true,
                child: Text.rich(
                  _spans(context, b.inlines),
                  style: TextStyle(
                    color: t.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: switch (b.level) {
                      1 => 22,
                      2 => 18,
                      _ => 16,
                    },
                  ),
                ),
              ),
            ),
          );
        case MdBlockKind.paragraph:
          children.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text.rich(_spans(context, b.inlines), style: body),
            ),
          );
        case MdBlockKind.bullet:
        case MdBlockKind.numbered:
          for (var i = 0; i < b.items.length; i++) {
            children.add(
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        b.kind == MdBlockKind.bullet ? '•' : '${i + 1}.',
                        style: body.copyWith(
                          color: t.accentText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text.rich(
                        _spans(context, b.items[i]),
                        style: body,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          children.add(const SizedBox(height: 6));
        case MdBlockKind.codeFence:
          children.add(CodeBlock(code: b.code, language: b.language));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  TextSpan _spans(BuildContext context, List<MdInline> inlines) {
    final t = context.tokens;
    return TextSpan(
      children: [
        for (final i in inlines)
          switch (i.kind) {
            MdInlineKind.text => TextSpan(text: i.text),
            MdInlineKind.bold => TextSpan(
              text: i.text,
              style: TextStyle(fontWeight: FontWeight.w700, color: t.ink),
            ),
            MdInlineKind.italic => TextSpan(
              text: i.text,
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
            MdInlineKind.code => TextSpan(
              text: i.text,
              style: devDiaryCodeStyle.copyWith(
                fontSize: 13.5,
                color: t.ink,
                backgroundColor: t.ink.withValues(alpha: .08),
              ),
            ),
            MdInlineKind.link => WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: Semantics(
                link: true,
                child: InkWell(
                  onTap: () =>
                      launchUrl(Uri.parse(i.url!), webOnlyWindowName: '_blank'),
                  child: Text(
                    i.text,
                    style: TextStyle(
                      color: t.primary,
                      fontSize: 15.5,
                      decoration: TextDecoration.underline,
                      decorationColor: t.primary,
                    ),
                  ),
                ),
              ),
            ),
          },
      ],
    );
  }
}
