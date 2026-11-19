import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/diary_entry.dart';
import '../services/api_exception.dart';
import '../services/diary_api_service.dart';

enum DiaryView { diary, favorites, dashboard, trash, settings }

/// Stato condiviso del diario: vista, filtri, note caricate, selezione, form.
class DiaryStore extends ChangeNotifier {
  DiaryStore(this.api);

  final DiaryApiService api;

  DiaryView view = DiaryView.diary;
  String? type;
  String? tag;
  String search = '';
  List<DiaryEntry> entries = [];

  /// Tutte le note (senza filtri), per la dashboard.
  List<DiaryEntry> all = [];
  String? selectedId;
  bool loading = false;
  ApiException? error;

  /// Form aperto: nuova nota se [editing] è null, altrimenti modifica.
  bool composing = false;
  DiaryEntry? editing;

  /// null finché il primo controllo di /status non ha risposto.
  bool? apiOnline;

  int _seq = 0;
  Timer? _debounce;

  bool get hasFilters => type != null || tag != null || search.isNotEmpty;

  bool get isListView =>
      view == DiaryView.diary ||
      view == DiaryView.favorites ||
      view == DiaryView.trash;

  DiaryEntry? get selected {
    for (final e in entries) {
      if (e.id == selectedId) return e;
    }
    return null;
  }

  /// Tag più usati tra [source] (di solito le note caricate), al massimo [limit].
  List<String> topTags([int limit = 8, List<DiaryEntry>? source]) {
    final counts = <String, int>{};
    for (final e in source ?? entries) {
      for (final t in e.tags) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    final sorted = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return sorted.take(limit).toList();
  }

  /// Avvio: prima lo stato dell'API (3 s), poi il diario.
  Future<void> start() async {
    loading = true;
    notifyListeners();
    await checkStatus();
    if (apiOnline == true) {
      await load();
    } else {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> checkStatus() async {
    try {
      await api.getStatus();
      apiOnline = true;
    } on ApiException {
      apiOnline = false;
    }
    notifyListeners();
  }

  Future<void> load() async {
    final seq = ++_seq;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await api.getEntries(
        type: type,
        tag: tag,
        search: search,
        favorite: view == DiaryView.favorites ? true : null,
        trash: view == DiaryView.trash,
      );
      if (seq != _seq) return;
      entries = result;
      apiOnline = true;
    } on ApiException catch (e) {
      if (seq != _seq) return;
      error = e;
    } finally {
      if (seq == _seq) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadAll() async {
    try {
      all = await api.getEntries();
      error = null;
    } on ApiException catch (e) {
      error = e;
    }
    notifyListeners();
  }

  void setView(DiaryView v) {
    composing = false;
    editing = null;
    if (view == v) {
      notifyListeners();
      return;
    }
    view = v;
    selectedId = null;
    notifyListeners();
    if (isListView) load();
    if (v == DiaryView.dashboard) loadAll();
  }

  void setType(String? value) {
    type = value;
    load();
  }

  void setTag(String? value) {
    tag = value;
    if (view != DiaryView.diary && view != DiaryView.favorites) {
      view = DiaryView.diary;
      selectedId = null;
    }
    load();
  }

  /// Aspetta 300 ms dall'ultima battuta prima di chiedere all'API.
  void setSearch(String value) {
    search = value.trim();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), load);
  }

  void clearFilters() {
    type = null;
    tag = null;
    search = '';
    load();
  }

  void select(String? id) {
    selectedId = id;
    composing = false;
    editing = null;
    notifyListeners();
  }

  /// Apre una nota da un'altra vista (ricerca rapida, dashboard).
  void open(String id) {
    if (!isListView) setView(DiaryView.diary);
    select(id);
  }

  static const _sampleReadOnly = ApiException(
    403,
    'SAMPLE_READ_ONLY',
    'Le note di esempio non si modificano',
  );

  void startNew() {
    if (view == DiaryView.trash || !isListView) setView(DiaryView.diary);
    composing = true;
    editing = null;
    notifyListeners();
  }

  void startEdit(DiaryEntry entry) {
    if (entry.isSample) throw _sampleReadOnly;
    composing = true;
    editing = entry;
    notifyListeners();
  }

  void closeForm() {
    composing = false;
    editing = null;
    notifyListeners();
  }

  /// Salva il form (crea o aggiorna) e seleziona la nota salvata.
  Future<void> save(DiaryEntry draft) async {
    final String id;
    if (editing != null) {
      await api.updateEntry(draft);
      id = draft.id;
    } else {
      id = await api.createEntry(draft);
    }
    composing = false;
    editing = null;
    await load();
    selectedId = id;
    notifyListeners();
  }

  Future<void> toggleFavorite(DiaryEntry entry) async {
    if (entry.isSample) throw _sampleReadOnly;
    final updated = entry.copyWith(isFavorite: !entry.isFavorite);
    await api.updateEntry(updated);
    entries = [
      for (final e in entries)
        if (e.id == entry.id) updated else e,
    ];
    if (view == DiaryView.favorites && !updated.isFavorite) {
      entries.removeWhere((e) => e.id == entry.id);
    }
    notifyListeners();
  }

  void _drop(DiaryEntry entry) {
    entries = entries.where((e) => e.id != entry.id).toList();
    if (selectedId == entry.id) selectedId = null;
    notifyListeners();
  }

  Future<void> moveToTrash(DiaryEntry entry) async {
    if (entry.isSample) throw _sampleReadOnly;
    await api.deleteEntry(entry.id);
    _drop(entry);
  }

  Future<void> restore(DiaryEntry entry) async {
    await api.restoreEntry(entry.id);
    _drop(entry);
  }

  Future<void> deletePermanently(DiaryEntry entry) async {
    await api.deleteEntry(entry.id, permanent: true);
    _drop(entry);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
