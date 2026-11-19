import 'package:material_ui/material_ui.dart';
import '../theme/devdiary_fonts.dart';

import '../main.dart';
import '../models/diary_entry.dart';
import '../services/api_exception.dart';
import '../services/diary_api_service.dart';
import 'diary_form_screen.dart';

class DiaryDetailScreen extends StatefulWidget {
  final String entryId;

  const DiaryDetailScreen({
    super.key,
    required this.entryId,
  });

  @override
  State<DiaryDetailScreen> createState() => _DiaryDetailScreenState();
}

class _DiaryDetailScreenState extends State<DiaryDetailScreen> {
  final DiaryApiService _apiService = DiaryApiService();

  DiaryEntry? _entry;
  bool _isLoading = true;
  bool _isDeleting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadEntry();
  }

  Future<void> _loadEntry() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final entry = await _apiService.getEntryById(widget.entryId);

      if (!mounted) return;

      setState(() {
        _entry = entry;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e is ApiException ? e.message : 'Impossibile caricare la nota';
        _isLoading = false;
      });

      debugPrint('ERRORE DETTAGLIO: $e');
    }
  }

  Future<void> _editEntry() async {
    if (_entry == null) return;

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => DiaryFormScreen(
          entry: _entry!,
        ),
      ),
    );

    if (updated == true) {
      await _loadEntry();
    }
  }

  Future<void> _deleteEntry() async {
    if (_entry == null || _isDeleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Eliminare la nota?',
            style: TextStyle(fontFamily: DevDiaryFonts.ui, 
              color: DevDiaryColors.darkPurple,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Vuoi davvero eliminare "${_entry!.title}"? '
            'Questa operazione non può essere annullata.',
            style: TextStyle(fontFamily: DevDiaryFonts.ui, 
              color: DevDiaryColors.secondaryText,
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: Text(
                'Annulla',
                style: TextStyle(fontFamily: DevDiaryFonts.ui, 
                  color: DevDiaryColors.purple,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: DevDiaryColors.pink,
              ),
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Elimina'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      await _apiService.deleteEntry(_entry!.id);

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isDeleting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Errore durante l\'eliminazione: $e',
          ),
        ),
      );
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'snippet':
        return Icons.code_rounded;
      case 'idea':
        return Icons.lightbulb_outline_rounded;
      case 'errore':
        return Icons.warning_amber_rounded;
      case 'link':
        return Icons.link_rounded;
      default:
        return Icons.description_outlined;
    }
  }

  String _labelForType(String type) {
    switch (type) {
      case 'snippet':
        return 'Snippet';
      case 'idea':
        return 'Idea';
      case 'errore':
        return 'Errore';
      case 'link':
        return 'Link';
      default:
        return 'Nota';
    }
  }

  String _formatDate(String value) {
    try {
      final date = DateTime.parse(value).toLocal();

      const months = [
        'gen',
        'feb',
        'mar',
        'apr',
        'mag',
        'giu',
        'lug',
        'ago',
        'set',
        'ott',
        'nov',
        'dic',
      ];

      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');

      return '${date.day} ${months[date.month - 1]} ${date.year}, $hour:$minute';
    } catch (_) {
      return value;
    }
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
          'Dettaglio',
          style: TextStyle(fontFamily: DevDiaryFonts.ui, 
            color: DevDiaryColors.darkPurple,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (_entry != null) ...[
            IconButton(
              onPressed: _isDeleting ? null : _editEntry,
              icon: const Icon(
                Icons.edit_outlined,
                color: DevDiaryColors.purple,
              ),
              tooltip: 'Modifica nota',
            ),
            IconButton(
              onPressed: _isDeleting ? null : _deleteEntry,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: DevDiaryColors.pink,
              ),
              tooltip: 'Elimina nota',
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: DevDiaryColors.purple,
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 44,
              color: DevDiaryColors.blue,
            ),
            const SizedBox(height: 14),
            Text(
              _errorMessage!,
              style: TextStyle(fontFamily: DevDiaryFonts.ui, 
                color: DevDiaryColors.secondaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadEntry,
              child: const Text('Riprova'),
            ),
          ],
        ),
      );
    }

    if (_entry == null) {
      return Center(
        child: Text(
          'Nota non trovata',
          style: TextStyle(fontFamily: DevDiaryFonts.ui, 
            color: DevDiaryColors.secondaryText,
          ),
        ),
      );
    }

    final entry = _entry!;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        28,
        20,
        28,
        40,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: DevDiaryColors.purple,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _iconForType(entry.type),
                  color: Colors.white,
                  size: 29,
                ),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: TextStyle(fontFamily: DevDiaryFonts.ui, 
                        color: DevDiaryColors.darkPurple,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      _labelForType(entry.type),
                      style: TextStyle(fontFamily: DevDiaryFonts.ui, 
                        color: DevDiaryColors.purple,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              Icon(
                entry.isFavorite
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                color: entry.isFavorite
                    ? DevDiaryColors.pink
                    : DevDiaryColors.secondaryText,
                size: 34,
              ),
            ],
          ),

          if (entry.tags.isNotEmpty) ...[
            const SizedBox(height: 22),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: entry.tags.map(
                (tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: DevDiaryColors.lightPurple,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '#$tag',
                      style: TextStyle(fontFamily: DevDiaryFonts.ui, 
                        color: DevDiaryColors.purple,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                },
              ).toList(),
            ),
          ],

          const SizedBox(height: 28),

          _SectionCard(
            title: 'Contenuto',
            icon: Icons.notes_rounded,
            child: Text(
              entry.content,
              style: TextStyle(fontFamily: DevDiaryFonts.ui, 
                color: DevDiaryColors.text,
                fontSize: 16,
                height: 1.6,
              ),
            ),
          ),

          if (entry.language != null &&
              entry.language!.isNotEmpty) ...[
            const SizedBox(height: 18),

            _SectionCard(
              title: 'Linguaggio',
              icon: Icons.translate_rounded,
              child: Text(
                entry.language!,
                style: TextStyle(fontFamily: DevDiaryFonts.ui, 
                  color: DevDiaryColors.purple,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],

          if (entry.code != null &&
              entry.code!.isNotEmpty) ...[
            const SizedBox(height: 18),

            _SectionCard(
              title: 'Codice',
              icon: Icons.code_rounded,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF201A32),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SelectableText(
                  entry.code!,
                  style: const TextStyle(
                    color: Color(0xFFEDE7FF),
                    fontFamily: 'monospace',
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 22),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: DevDiaryColors.lightBlue,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: DevDiaryColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DateRow(
                  icon: Icons.calendar_month_outlined,
                  label: 'Creata',
                  value: _formatDate(entry.createdAt),
                ),
                const SizedBox(height: 12),
                _DateRow(
                  icon: Icons.update_rounded,
                  label: 'Ultima modifica',
                  value: _formatDate(entry.updatedAt),
                ),
              ],
            ),
          ),

          if (_isDeleting) ...[
            const SizedBox(height: 24),
            const Center(
              child: CircularProgressIndicator(
                color: DevDiaryColors.pink,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
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
        border: Border.all(
          color: DevDiaryColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: DevDiaryColors.purple.withValues(
              alpha: 0.05,
            ),
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
              Icon(
                icon,
                color: DevDiaryColors.purple,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(fontFamily: DevDiaryFonts.ui, 
                  color: DevDiaryColors.darkPurple,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DateRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: DevDiaryColors.purple,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: TextStyle(fontFamily: DevDiaryFonts.ui, 
            color: DevDiaryColors.darkPurple,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontFamily: DevDiaryFonts.ui, 
              color: DevDiaryColors.secondaryText,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}