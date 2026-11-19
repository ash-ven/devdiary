import 'package:material_ui/material_ui.dart';

import '../models/diary_entry.dart';
import '../services/api_exception.dart';
import '../state/scope.dart';
import '../theme/devdiary_theme.dart';
import 'common.dart';
import 'type_mark.dart';

/// Limiti uguali a quelli dell'API.
const maxTitle = 120;
const maxText = 10000;
const maxTags = 10;
const maxTag = 30;
const errorTemplate = '## Problema\n\n## Causa\n\n## Soluzione\n';

List<String> parseTags(String raw) =>
    raw.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

/// Nuova nota o modifica, nello spazio del foglio.
class NoteForm extends StatefulWidget {
  const NoteForm({super.key, this.entry, this.narrow = false});
  final DiaryEntry? entry;
  final bool narrow;

  @override
  State<NoteForm> createState() => _NoteFormState();
}

class _NoteFormState extends State<NoteForm> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.entry?.title);
  late final _tags = TextEditingController(text: widget.entry?.tags.join(', '));
  late final _content = TextEditingController(text: widget.entry?.content);
  late final _language = TextEditingController(text: widget.entry?.language);
  late final _code = TextEditingController(text: widget.entry?.code);
  late String _type = widget.entry?.type ?? 'note';
  bool _saving = false;
  String? _apiError;

  @override
  void dispose() {
    for (final c in [_title, _tags, _content, _language, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  void _setType(String type) {
    setState(() => _type = type);
    if (type == 'errore' && _content.text.trim().isEmpty) {
      _content.text = errorTemplate;
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final diary = DevDiaryScope.of(context).diary;
    final l = context.l10n;
    String? orNull(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    final draft = DiaryEntry(
      id: widget.entry?.id ?? '',
      title: _title.text.trim(),
      content: _content.text.trim(),
      type: _type,
      language: orNull(_language),
      code: _code.text.trim().isEmpty ? null : _code.text,
      tags: parseTags(_tags.text),
      isFavorite: widget.entry?.isFavorite ?? false,
      createdAt: '',
      updatedAt: '',
    );
    setState(() {
      _saving = true;
      _apiError = null;
    });
    try {
      await diary.save(draft);
      if (mounted) showMessage(context, l.saved);
    } on ApiException catch (e) {
      if (mounted) setState(() => _apiError = errorText(context, e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final diary = DevDiaryScope.of(context).diary;

    String? required(String? v, int max) {
      if (v == null || v.trim().isEmpty) return l.fieldRequired;
      if (v.trim().length > max) return l.tooLong(max);
      return null;
    }

    InputDecoration deco(String label, {String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: true,
      labelStyle: TextStyle(color: t.ink2),
      filled: true,
      fillColor: t.paper.withValues(alpha: .5),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: t.ruleStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: t.focus, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: t.accentText),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: t.accentText, width: 2),
      ),
      errorStyle: TextStyle(color: t.accentText, fontSize: 12.5),
    );
    const gap = SizedBox(height: 14);

    return Container(
      decoration: BoxDecoration(
        color: t.sheet,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        boxShadow: sheetShadow(t),
      ),
      child: Form(
        key: _form,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            widget.narrow ? 18 : 40,
            28,
            widget.narrow ? 18 : 40,
            40,
          ),
          children: [
            Semantics(
              header: true,
              child: Text(
                widget.entry == null ? l.newNote : l.editNote,
                style: TextStyle(
                  color: t.ink,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _title,
              decoration: deco(l.formTitle),
              maxLength: maxTitle,
              validator: (v) => required(v, maxTitle),
              textInputAction: TextInputAction.next,
            ),
            gap,
            Text(l.formType, style: TextStyle(color: t.ink2, fontSize: 13)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final type in noteTypes)
                  Builder(
                    builder: (context) {
                      final (bg, tx) = typeColors(t, type);
                      final on = _type == type;
                      return Tappable(
                        selected: on,
                        onTap: () => _setType(type),
                        radius: 8,
                        color: on ? bg : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: on ? Colors.transparent : t.ruleStrong,
                            ),
                          ),
                          child: Text(
                            typeLabel(l, type),
                            style: TextStyle(
                              color: on ? tx : t.ink2,
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _tags,
              decoration: deco(l.formTags, hint: 'flutter, http'),
              validator: (v) {
                final tags = parseTags(v ?? '');
                if (tags.length > maxTags) return l.tooManyTags;
                if (tags.any((x) => x.length > maxTag)) return l.tagTooLong;
                return null;
              },
            ),
            gap,
            TextFormField(
              controller: _content,
              decoration: deco(l.formContent),
              minLines: 6,
              maxLines: 16,
              validator: (v) => required(v, maxText),
            ),
            gap,
            TextFormField(
              controller: _language,
              decoration: deco(l.formLanguage, hint: 'dart, javascript, sql…'),
            ),
            gap,
            TextFormField(
              controller: _code,
              decoration: deco(l.formCode),
              style: devDiaryCodeStyle.copyWith(fontSize: 13.5, color: t.ink),
              minLines: 4,
              maxLines: 20,
              validator: (v) =>
                  (v ?? '').length > maxText ? l.tooLong(maxText) : null,
            ),
            if (_apiError != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _apiError!,
                    style: TextStyle(color: t.accentText, fontSize: 14),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              children: [
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: t.primary,
                    foregroundColor: t.onPrimary,
                    minimumSize: const Size(96, 44),
                  ),
                  child: Text(l.save),
                ),
                OutlinedButton(
                  onPressed: _saving ? null : diary.closeForm,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: t.ink2,
                    minimumSize: const Size(96, 44),
                    side: BorderSide(color: t.ruleStrong),
                  ),
                  child: Text(l.cancel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
