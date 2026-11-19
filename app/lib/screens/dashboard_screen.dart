import 'package:material_ui/material_ui.dart';
import '../theme/devdiary_fonts.dart';

import '../main.dart';
import '../models/diary_entry.dart';
import '../services/diary_api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DiaryApiService _apiService = DiaryApiService();

  List<DiaryEntry> _entries = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final entries = await _apiService.getEntries();

      if (!mounted) return;

      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Impossibile caricare la dashboard';
        _isLoading = false;
      });
    }
  }

  int get _totalEntries => _entries.length;

  int get _snippetCount =>
      _entries.where((entry) => entry.type == 'snippet').length;

  int get _favoriteCount =>
      _entries.where((entry) => entry.isFavorite).length;

  int get _errorCount =>
      _entries.where((entry) => entry.type == 'errore').length;

  List<MapEntry<String, int>> get _topTags {
    final counts = <String, int>{};

    for (final entry in _entries) {
      for (final tag in entry.tags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }

    final sorted = counts.entries.toList()
      ..sort(
        (a, b) => b.value.compareTo(a.value),
      );

    return sorted.take(5).toList();
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
          'Dashboard',
          style: TextStyle(fontFamily: DevDiaryFonts.ui, 
            color: DevDiaryColors.darkPurple,
            fontWeight: FontWeight.w800,
          ),
        ),
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
              size: 46,
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
              onPressed: _loadEntries,
              child: const Text('Riprova'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: DevDiaryColors.purple,
      onRefresh: _loadEntries,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          28,
          18,
          28,
          40,
        ),
        children: [
          Text(
            'Riepilogo',
            style: TextStyle(fontFamily: DevDiaryFonts.ui, 
              color: DevDiaryColors.darkPurple,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 20),

          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _StatCard(
                title: 'Totale note',
                value: _totalEntries,
                icon: Icons.notes_rounded,
                accentColor: DevDiaryColors.purple,
              ),
              _StatCard(
                title: 'Snippet',
                value: _snippetCount,
                icon: Icons.code_rounded,
                accentColor: DevDiaryColors.blue,
              ),
              _StatCard(
                title: 'Preferiti',
                value: _favoriteCount,
                icon: Icons.star_rounded,
                accentColor: DevDiaryColors.pink,
              ),
              _StatCard(
                title: 'Errori risolti',
                value: _errorCount,
                icon: Icons.bug_report_outlined,
                accentColor: DevDiaryColors.purple,
              ),
            ],
          ),

          const SizedBox(height: 34),

          Text(
            'Top tag',
            style: TextStyle(fontFamily: DevDiaryFonts.ui, 
              color: DevDiaryColors.darkPurple,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 14),

          if (_topTags.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: DevDiaryColors.border,
                ),
              ),
              child: Text(
                'Nessun tag disponibile',
                style: TextStyle(fontFamily: DevDiaryFonts.ui, 
                  color: DevDiaryColors.secondaryText,
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
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
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _topTags.map(
                  (tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: DevDiaryColors.lightBlue,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.tag_rounded,
                            size: 16,
                            color: DevDiaryColors.purple,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            tag.key,
                            style: TextStyle(fontFamily: DevDiaryFonts.ui, 
                              color: DevDiaryColors.purple,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: DevDiaryColors.lightPurple,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              tag.value.toString(),
                              style: TextStyle(fontFamily: DevDiaryFonts.ui, 
                                color: DevDiaryColors.darkPurple,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color accentColor;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(18),
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
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accentColor.withValues(
                alpha: 0.12,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: accentColor,
              size: 25,
            ),
          ),

          const SizedBox(height: 18),

          Text(
            value.toString(),
            style: TextStyle(fontFamily: DevDiaryFonts.ui, 
              color: DevDiaryColors.darkPurple,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            title,
            style: TextStyle(fontFamily: DevDiaryFonts.ui, 
              color: DevDiaryColors.secondaryText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}