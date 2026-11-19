import 'package:material_ui/material_ui.dart';
import '../theme/devdiary_fonts.dart';

import '../main.dart';
import '../models/diary_entry.dart';
import '../screens/diary_detail_screen.dart';

class DiaryEntryCard extends StatelessWidget {
  final DiaryEntry entry;

  const DiaryEntryCard({
    super.key,
    required this.entry,
  });

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
      case 'note':
      default:
        return Icons.description_outlined;
    }
  }

  String _labelForType(String type) {
    switch (type) {
      case 'snippet':
        return 'snippet';
      case 'idea':
        return 'idea';
      case 'errore':
        return 'errore';
      case 'link':
        return 'link';
      default:
        return 'note';
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
    final metadata = entry.tags.isEmpty
        ? _labelForType(entry.type)
        : '${_labelForType(entry.type)} • ${entry.tags.join(', ')}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DiaryDetailScreen(
                entryId: entry.id,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: DevDiaryColors.border,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: DevDiaryColors.purple.withValues(
                  alpha: 0.06,
                ),
                blurRadius: 13,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: DevDiaryColors.purple,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _iconForType(entry.type),
                  color: Colors.white,
                  size: 29,
                ),
              ),

              const SizedBox(width: 18),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: DevDiaryFonts.ui, 
                        color: DevDiaryColors.darkPurple,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      metadata,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: DevDiaryFonts.ui, 
                        color: DevDiaryColors.purple,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 7),

                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_month_outlined,
                          color: DevDiaryColors.secondaryText,
                          size: 16,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _formatDate(entry.updatedAt),
                          style: TextStyle(fontFamily: DevDiaryFonts.ui, 
                            color: DevDiaryColors.secondaryText,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 14),

              Icon(
                entry.isFavorite
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                color: entry.isFavorite
                    ? DevDiaryColors.pink
                    : DevDiaryColors.secondaryText,
                size: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}