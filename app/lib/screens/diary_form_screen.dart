import 'package:material_ui/material_ui.dart';
import '../theme/devdiary_fonts.dart';

import '../main.dart';
import '../models/diary_entry.dart';
import '../services/diary_api_service.dart';

class DiaryFormScreen extends StatefulWidget {
  final DiaryEntry? entry;

  const DiaryFormScreen({super.key, this.entry});

  @override
  State<DiaryFormScreen> createState() => _DiaryFormScreenState();
}

class _DiaryFormScreenState extends State<DiaryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final DiaryApiService _apiService = DiaryApiService();

  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _tagsController;
  late final TextEditingController _languageController;
  late final TextEditingController _codeController;

  late String _selectedType;
  late bool _isFavorite;

  bool _isSaving = false;

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();

    final entry = widget.entry;

    _titleController = TextEditingController(text: entry?.title ?? '');

    _contentController = TextEditingController(text: entry?.content ?? '');

    _tagsController = TextEditingController(text: entry?.tags.join(', ') ?? '');

    _languageController = TextEditingController(text: entry?.language ?? '');

    _codeController = TextEditingController(text: entry?.code ?? '');

    _selectedType = entry?.type ?? 'note';
    _isFavorite = entry?.isFavorite ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    _languageController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _saveEntry() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final tags = _tagsController.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();

    final entry = DiaryEntry(
      id: widget.entry?.id ?? '',
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      type: _selectedType,
      language: _languageController.text.trim().isEmpty
          ? null
          : _languageController.text.trim(),
      code: _codeController.text.trim().isEmpty
          ? null
          : _codeController.text.trim(),
      tags: tags,
      isFavorite: _isFavorite,
      createdAt: widget.entry?.createdAt ?? '',
      updatedAt: widget.entry?.updatedAt ?? '',
    );

    try {
      if (_isEditing) {
        await _apiService.updateEntry(entry);
      } else {
        await _apiService.createEntry(entry);
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Errore durante la modifica: $e'
                : 'Errore durante il salvataggio: $e',
          ),
        ),
      );
    }
  }

  InputDecoration _fieldDecoration({
    required String label,
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: true,
      prefixIcon: icon != null
          ? Icon(icon, color: DevDiaryColors.purple)
          : null,
      filled: true,
      fillColor: Colors.white,
      labelStyle: TextStyle(
        fontFamily: DevDiaryFonts.ui,
        color: DevDiaryColors.purple,
        fontWeight: FontWeight.w700,
      ),
      hintStyle: TextStyle(
        fontFamily: DevDiaryFonts.ui,
        color: DevDiaryColors.secondaryText,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: DevDiaryColors.border, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: DevDiaryColors.purple, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: DevDiaryColors.pink),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: DevDiaryColors.pink, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DevDiaryColors.background,

      appBar: AppBar(
        backgroundColor: DevDiaryColors.background,
        foregroundColor: DevDiaryColors.purple,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          _isEditing ? 'Modifica nota' : 'Nuova nota',
          style: TextStyle(
            fontFamily: DevDiaryFonts.ui,
            color: DevDiaryColors.darkPurple,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 18, 28, 40),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FormSection(
                title: 'Informazioni principali',
                icon: Icons.edit_note_rounded,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      style: TextStyle(
                        fontFamily: DevDiaryFonts.ui,
                        color: DevDiaryColors.text,
                      ),
                      decoration: _fieldDecoration(
                        label: 'Titolo',
                        icon: Icons.title_rounded,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Inserisci un titolo';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _contentController,
                      maxLines: 5,
                      style: TextStyle(
                        fontFamily: DevDiaryFonts.ui,
                        color: DevDiaryColors.text,
                        height: 1.5,
                      ),
                      decoration: _fieldDecoration(
                        label: 'Contenuto',
                        icon: Icons.notes_rounded,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Inserisci il contenuto';
                        }

                        return null;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              _FormSection(
                title: 'Classificazione',
                icon: Icons.category_outlined,
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _selectedType,
                      decoration: _fieldDecoration(
                        label: 'Tipo',
                        icon: Icons.category_rounded,
                      ),
                      style: TextStyle(
                        fontFamily: DevDiaryFonts.ui,
                        color: DevDiaryColors.text,
                        fontWeight: FontWeight.w600,
                      ),
                      dropdownColor: Colors.white,
                      items: const [
                        DropdownMenuItem(value: 'note', child: Text('Nota')),
                        DropdownMenuItem(
                          value: 'errore',
                          child: Text('Errore'),
                        ),
                        DropdownMenuItem(
                          value: 'snippet',
                          child: Text('Snippet'),
                        ),
                        DropdownMenuItem(value: 'idea', child: Text('Idea')),
                        DropdownMenuItem(value: 'link', child: Text('Link')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedType = value;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _tagsController,
                      style: TextStyle(
                        fontFamily: DevDiaryFonts.ui,
                        color: DevDiaryColors.text,
                      ),
                      decoration: _fieldDecoration(
                        label: 'Tag',
                        hint: 'flutter, api, n8n',
                        icon: Icons.tag_rounded,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              _FormSection(
                title: 'Codice e linguaggio',
                icon: Icons.code_rounded,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _languageController,
                      style: TextStyle(
                        fontFamily: DevDiaryFonts.ui,
                        color: DevDiaryColors.text,
                      ),
                      decoration: _fieldDecoration(
                        label: 'Linguaggio',
                        hint: 'Es. Dart, JavaScript, Python',
                        icon: Icons.translate_rounded,
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _codeController,
                      minLines: 4,
                      maxLines: 10,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: DevDiaryColors.text,
                        height: 1.45,
                      ),
                      decoration: _fieldDecoration(
                        label: 'Codice',
                        icon: Icons.code_rounded,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: DevDiaryColors.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isFavorite
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: _isFavorite
                          ? DevDiaryColors.pink
                          : DevDiaryColors.purple,
                      size: 26,
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Text(
                        'Preferita',
                        style: TextStyle(
                          fontFamily: DevDiaryFonts.ui,
                          color: DevDiaryColors.darkPurple,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),

                    Switch(
                      value: _isFavorite,
                      onChanged: (value) {
                        setState(() {
                          _isFavorite = value;
                        });
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 26),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: DevDiaryColors.pink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isSaving ? null : _saveEntry,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(
                    _isSaving
                        ? 'Salvataggio...'
                        : _isEditing
                        ? 'Salva modifiche'
                        : 'Salva nota',
                    style: TextStyle(
                      fontFamily: DevDiaryFonts.ui,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _FormSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DevDiaryColors.border),
        boxShadow: [
          BoxShadow(
            color: DevDiaryColors.purple.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: DevDiaryColors.lightPurple,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: DevDiaryColors.purple, size: 20),
              ),

              const SizedBox(width: 10),

              Text(
                title,
                style: TextStyle(
                  fontFamily: DevDiaryFonts.ui,
                  color: DevDiaryColors.darkPurple,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          child,
        ],
      ),
    );
  }
}
