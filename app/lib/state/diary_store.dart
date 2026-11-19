import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/diary_entry.dart';
import '../services/api_exception.dart';
import '../services/diary_api_service.dart';

enum DiaryView { diary, favorites, dashboard, trash, settings }

/// Stato condiviso del diario: vista, filtri, note caricate, selezione.
class DiaryStore extends ChangeNotifier {
  DiaryStore(this.api);

  final DiaryApiService api;

  DiaryView view = DiaryView.diary;
  String? type;
  String? tag;
  String search = '';
  List<DiaryEntry> entries = [];
  String? selectedId;
  bool loading = false;
  ApiException? error;

  /// null finché il primo controllo di /status non ha risposto.
  bool? apiOnline;

  int _seq = 0;
  Timer? _debounce;

  bool get hasFilters => type != null || tag != null || search.isNotEmpty;

  DiaryEntry? get selected {
    for (final e in entries) {
      if (e.id == selectedId) return e;
    }
    return null;
  }

  /// Tag più usati tra le note caricate, al massimo [limit].
  List<String> topTags([int limit = 8]) {
    final counts = <String, int>{};
    for (final e in entries) {
      for (final t in e.tags) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    final sorted = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return sorted.take(limit).toList();
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

  void setView(DiaryView v) {
    if (view == v) return;
    view = v;
    selectedId = null;
    notifyListeners();
    if (v == DiaryView.diary ||
        v == DiaryView.favorites ||
        v == DiaryView.trash) {
      load();
    }
  }

  void setType(String? value) {
    type = value;
    load();
  }

  void setTag(String? value) {
    tag = value;
    if (view != DiaryView.diary && view != DiaryView.favorites) {
      view = DiaryView.diary;
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
    notifyListeners();
  }

  static const _sampleReadOnly = ApiException(
    403,
    'SAMPLE_READ_ONLY',
    'Le note di esempio non si modificano',
  );

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

  Future<void> moveToTrash(DiaryEntry entry) async {
    if (entry.isSample) throw _sampleReadOnly;
    await api.deleteEntry(entry.id);
    entries = entries.where((e) => e.id != entry.id).toList();
    if (selectedId == entry.id) selectedId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
