import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../state/scope.dart';
import 'common.dart';

/// Attese tra un tentativo e l'altro, in secondi; l'ultima si ripete.
const wakeDelays = [3, 5, 8, 13, 20, 30];
const wakeLimit = 120;

/// Schermata mostrata quando l'API non risponde all'avvio (piano gratuito che dorme).
class WakeScreen extends StatefulWidget {
  const WakeScreen({super.key});

  @override
  State<WakeScreen> createState() => _WakeScreenState();
}

class _WakeScreenState extends State<WakeScreen> {
  int _elapsed = 0;
  int _attempt = 0;
  bool _gaveUp = false;
  Timer? _tick;
  Timer? _next;

  @override
  void initState() {
    super.initState();
    _begin();
  }

  void _begin() {
    _elapsed = 0;
    _attempt = 0;
    _gaveUp = false;
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed++);
    });
    _schedule();
  }

  void _schedule() {
    final delay = wakeDelays[_attempt.clamp(0, wakeDelays.length - 1)];
    if (_elapsed + delay > wakeLimit) {
      _tick?.cancel();
      setState(() => _gaveUp = true);
      return;
    }
    _next = Timer(Duration(seconds: delay), _try);
  }

  Future<void> _try() async {
    _attempt++;
    final diary = DevDiaryScope.of(context).diary;
    await diary.checkStatus();
    if (!mounted) return;
    if (diary.apiOnline == true) {
      diary.load();
      return;
    }
    _schedule();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _next?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
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
              if (!_gaveUp) ...[
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
                  onPressed: () => setState(() {
                    _begin();
                    _try();
                  }),
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
