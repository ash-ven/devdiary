import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../state/scope.dart';
import 'common.dart';

/// Schermata mostrata mentre l'API sul piano gratuito si sveglia. I tentativi
/// li fa [DiaryStore.start]; qui si mostrano il tempo trascorso e, se il server
/// non risponde entro il limite, il pulsante Riprova.
class WakeScreen extends StatefulWidget {
  const WakeScreen({super.key});

  @override
  State<WakeScreen> createState() => _WakeScreenState();
}

class _WakeScreenState extends State<WakeScreen> {
  int _elapsed = 0;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _startClock();
  }

  void _startClock() {
    _elapsed = 0;
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed++);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final diary = DevDiaryScope.of(context).diary;
    final gaveUp = diary.gaveUp;
    if (gaveUp) _tick?.cancel();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/devdiary_logo.png', width: 96),
              const SizedBox(height: 18),
              Semantics(
                header: true,
                child: Text(
                  l.wakeTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: t.ink,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l.wakeBody,
                textAlign: TextAlign.center,
                style: TextStyle(color: t.ink2, fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 18),
              if (!gaveUp) ...[
                if (!MediaQuery.of(context).disableAnimations)
                  SizedBox(
                    width: 200,
                    child: LinearProgressIndicator(
                      color: t.primary,
                      backgroundColor: t.ruleStrong.withValues(alpha: .3),
                    ),
                  ),
                const SizedBox(height: 10),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    l.wakeElapsed(_elapsed),
                    style: TextStyle(color: t.ink3, fontSize: 13),
                  ),
                ),
              ] else ...[
                Text(l.wakeGiveUp, style: TextStyle(color: t.ink2)),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    setState(_startClock);
                    diary.start();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: t.primary,
                    foregroundColor: t.onPrimary,
                    minimumSize: const Size(120, 44),
                  ),
                  child: Text(l.retry),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
