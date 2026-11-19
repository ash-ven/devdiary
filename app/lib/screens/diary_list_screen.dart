import 'dart:async';

import 'package:material_ui/material_ui.dart';
import '../theme/devdiary_fonts.dart';

import '../main.dart';
import '../models/diary_entry.dart';
import '../services/diary_api_service.dart';
import '../widgets/diary_entry_card.dart';
import 'diary_form_screen.dart';

class DiaryListScreen extends StatefulWidget {
  final bool initialOnlyFavorites;

  const DiaryListScreen({
    super.key,
    this.initialOnlyFavorites = false,
  });

  @override
  State<DiaryListScreen> createState() => _DiaryListScreenState();
}

class _DiaryListScreenState extends State<DiaryListScreen> {
  final DiaryApiService _apiService = DiaryApiService();
  final TextEditingController _searchController = TextEditingController();

  List<DiaryEntry> _entries = [];

  bool _isLoading = true;
  String? _errorMessage;

  String _selectedType = 'all';
  bool _onlyFavorites = false;

  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();

    _onlyFavorites = widget.initialOnlyFavorites;

    _loadEntries();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final entries = await _apiService.getEntries(
        type: _selectedType == 'all' ? null : _selectedType,
        favorite: _onlyFavorites ? true : null,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Impossibile caricare le note';
        _isLoading = false;
      });

      debugPrint('ERRORE LISTA: $e');
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();

    _searchDebounce = Timer(
      const Duration(milliseconds: 500),
      _loadEntries,
    );

    setState(() {});
  }

  Future<void> _openCreateForm() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const DiaryFormScreen(),
      ),
    );

    if (created == true) {
      await _loadEntries();
    }
  }

  void _selectType(String type) {
    setState(() {
      _selectedType = type;
    });

    _loadEntries();
  }

  void _toggleFavorites(bool value) {
    setState(() {
      _onlyFavorites = value;
    });

    _loadEntries();
  }

  void _resetFilters() {
    _searchDebounce?.cancel();
    _searchController.clear();

    setState(() {
      _selectedType = 'all';

      /*
       * Se siamo dentro la pagina Preferiti della bottom bar,
       * "Azzera filtri" mantiene comunque attivo il filtro preferiti.
       */
      _onlyFavorites = widget.initialOnlyFavorites;
    });

    _loadEntries();
  }

  IconData _filterIcon(String type) {
    switch (type) {
      case 'note':
        return Icons.description_outlined;
      case 'snippet':
        return Icons.code_rounded;
      case 'idea':
        return Icons.lightbulb_outline_rounded;
      case 'errore':
        return Icons.warning_amber_rounded;
      case 'link':
        return Icons.link_rounded;
      default:
        return Icons.check_rounded;
    }
  }

  Widget _buildFilterButton({
    required String label,
    required String value,
  }) {
    final selected = _selectedType == value;

    return Material(
      color: selected
          ? DevDiaryColors.purple
          : Colors.white,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () => _selectType(value),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected
                  ? DevDiaryColors.purple
                  : DevDiaryColors.purple.withValues(alpha: 0.45),
              width: 1.3,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _filterIcon(value),
                size: 18,
                color: selected
                    ? Colors.white
                    : DevDiaryColors.purple,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(fontFamily: DevDiaryFonts.ui, 
                  color: selected
                      ? Colors.white
                      : DevDiaryColors.purple,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DevDiaryColors.background,

      body: RefreshIndicator(
        color: DevDiaryColors.purple,
        onRefresh: _loadEntries,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            30,
            8,
            30,
            100,
          ),
          children: [
            Container(
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: DevDiaryColors.purple,
                  width: 1.3,
                ),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: TextStyle(fontFamily: DevDiaryFonts.ui, 
                  color: DevDiaryColors.text,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: widget.initialOnlyFavorites
                      ? 'Cerca nei preferiti...'
                      : 'Cerca...',
                  hintStyle: TextStyle(fontFamily: DevDiaryFonts.ui, 
                    color: DevDiaryColors.secondaryText,
                  ),
                  border: InputBorder.none,
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: DevDiaryColors.purple,
                    size: 27,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchDebounce?.cancel();
                            _searchController.clear();

                            setState(() {});

                            _loadEntries();
                          },
                          icon: const Icon(
                            Icons.close_rounded,
                            color: DevDiaryColors.purple,
                          ),
                        )
                      : const Icon(
                          Icons.tune_rounded,
                          color: DevDiaryColors.purple,
                        ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 18,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterButton(
                    label: 'Tutti',
                    value: 'all',
                  ),
                  const SizedBox(width: 10),
                  _buildFilterButton(
                    label: 'Note',
                    value: 'note',
                  ),
                  const SizedBox(width: 10),
                  _buildFilterButton(
                    label: 'Snippet',
                    value: 'snippet',
                  ),
                  const SizedBox(width: 10),
                  _buildFilterButton(
                    label: 'Idee',
                    value: 'idea',
                  ),
                  const SizedBox(width: 10),
                  _buildFilterButton(
                    label: 'Errori',
                    value: 'errore',
                  ),
                  const SizedBox(width: 10),
                  _buildFilterButton(
                    label: 'Link',
                    value: 'link',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            Row(
              children: [
                Text(
                  widget.initialOnlyFavorites
                      ? 'Preferiti'
                      : 'Solo preferiti',
                  style: TextStyle(fontFamily: DevDiaryFonts.ui, 
                    color: DevDiaryColors.darkPurple,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),

                /*
                 * Nella schermata Preferiti il filtro deve restare attivo,
                 * quindi lo switch viene mostrato ma non può essere spento.
                 */
                Switch(
                  value: _onlyFavorites,
                  onChanged: widget.initialOnlyFavorites
                      ? null
                      : _toggleFavorites,
                ),
              ],
            ),

            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _resetFilters,
                style: TextButton.styleFrom(
                  foregroundColor: DevDiaryColors.purple,
                  padding: EdgeInsets.zero,
                ),
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 23,
                ),
                label: Text(
                  'Azzera filtri',
                  style: TextStyle(fontFamily: DevDiaryFonts.ui, 
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 50),
                child: Center(
                  child: CircularProgressIndicator(
                    color: DevDiaryColors.purple,
                  ),
                ),
              )
            else if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 50,
                ),
                child: Column(
                  children: [
                    Text(
                      _errorMessage!,
                      style: TextStyle(fontFamily: DevDiaryFonts.ui, 
                        color: DevDiaryColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: _loadEntries,
                      child: const Text('Riprova'),
                    ),
                  ],
                ),
              )
            else if (_entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 50),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        widget.initialOnlyFavorites
                            ? Icons.favorite_border_rounded
                            : Icons.search_off_rounded,
                        color: DevDiaryColors.purple,
                        size: 42,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.initialOnlyFavorites
                            ? 'Nessuna nota preferita'
                            : 'Nessun risultato',
                        style: TextStyle(fontFamily: DevDiaryFonts.ui, 
                          color: DevDiaryColors.secondaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(
                    bottom: 14,
                  ),
                  child: DiaryEntryCard(
                    entry: entry,
                  ),
                ),
              ),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateForm,
        child: const Icon(
          Icons.add_rounded,
          size: 32,
        ),
      ),
    );
  }
}