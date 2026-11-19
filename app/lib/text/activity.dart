import '../models/diary_entry.dart';
import 'day_groups.dart';

const activityWeeks = 26;

/// Primo giorno (lunedì, UTC a mezzanotte) della mappa che finisce con la settimana di [now].
DateTime activityStart(DateTime now) {
  final today = DateTime.utc(now.year, now.month, now.day);
  final monday = today.subtract(Duration(days: today.weekday - 1));
  return monday.subtract(const Duration(days: 7 * (activityWeeks - 1)));
}

/// Mappa dell'attività: 26 colonne (settimane) per 7 righe (lunedì primo).
/// Conta le creazioni e le modifiche (quando `updatedAt` è diverso da `createdAt`).
List<List<int>> activityGrid(List<DiaryEntry> entries, DateTime now) {
  final start = activityStart(now);
  final today = DateTime.utc(now.year, now.month, now.day);
  final grid = List.generate(activityWeeks, (_) => List.filled(7, 0));
  void add(String iso) {
    final t = localTime(iso);
    if (t == null) return;
    final day = DateTime.utc(t.year, t.month, t.day);
    if (day.isBefore(start) || day.isAfter(today)) return;
    final diff = day.difference(start).inDays;
    grid[diff ~/ 7][diff % 7]++;
  }

  for (final e in entries) {
    add(e.createdAt);
    if (e.updatedAt != e.createdAt) add(e.updatedAt);
  }
  return grid;
}

/// Livello 0–4 con soglie fisse: 0, 1, 2–3, 4–5, 6 o più.
int activityLevel(int count) => switch (count) {
  0 => 0,
  1 => 1,
  <= 3 => 2,
  <= 5 => 3,
  _ => 4,
};
