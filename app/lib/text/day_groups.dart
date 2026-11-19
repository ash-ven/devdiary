import '../models/diary_entry.dart';

class DayGroup {
  const DayGroup(this.label, this.entries);
  final String label;
  final List<DiaryEntry> entries;
}

const _months = [
  'gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno', //
  'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre',
];

/// Data in italiano: «14 agosto», con l'anno se diverso da quello di [now].
String italianDate(DateTime d, DateTime now) {
  final base = '${d.day} ${_months[d.month - 1]}';
  return d.year == now.year ? base : '$base ${d.year}';
}

String hourMinute(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

DateTime? localTime(String iso) => DateTime.tryParse(iso)?.toLocal();

/// Raggruppa le note per giorno di creazione (ora locale): Oggi, Ieri, poi la data.
/// Le note arrivano già ordinate dalla più recente; l'ordine si mantiene.
List<DayGroup> groupByDay(List<DiaryEntry> entries, DateTime now) {
  final today = DateTime.utc(now.year, now.month, now.day);
  final groups = <String, List<DiaryEntry>>{};
  for (final e in entries) {
    final t = localTime(e.createdAt);
    final String label;
    if (t == null) {
      label = 'Senza data';
    } else {
      final day = DateTime.utc(t.year, t.month, t.day);
      final diff = today.difference(day).inDays;
      label = diff == 0
          ? 'Oggi'
          : diff == 1
          ? 'Ieri'
          : italianDate(t, now);
    }
    groups.putIfAbsent(label, () => []).add(e);
  }
  return [for (final g in groups.entries) DayGroup(g.key, g.value)];
}
