import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../services/request_log.dart';
import '../state/scope.dart';
import '../theme/devdiary_theme.dart';
import 'common.dart';

/// Pannello "Richieste all'API": le ultime richieste reali e lo schema
/// Flutter → n8n → MongoDB che si accende a ogni nuova richiesta.
class RequestPanel extends StatefulWidget {
  const RequestPanel({super.key, required this.initiallyOpen});
  final bool initiallyOpen;

  @override
  State<RequestPanel> createState() => _RequestPanelState();
}

class _RequestPanelState extends State<RequestPanel> {
  late bool _open = widget.initiallyOpen;
  bool _pulse = false;
  Timer? _timer;
  RequestLog? _log;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final log = DevDiaryScope.of(context).log;
    if (log != _log) {
      _log?.removeListener(_onLog);
      _log = log..addListener(_onLog);
    }
  }

  void _onLog() {
    if (!mounted) return;
    if (MediaQuery.of(context).disableAnimations) {
      setState(() {});
      return;
    }
    setState(() => _pulse = true);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _pulse = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _log?.removeListener(_onLog);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final records = _log?.records ?? const [];
    final mono = devDiaryCodeStyle.copyWith(fontSize: 12.5);

    Color methodColor(String m) => switch (m) {
      'GET' => t.markTxSnippet,
      'POST' => t.markTxLink,
      'PUT' => t.markTxIdea,
      'DELETE' => t.markTxErrore,
      _ => t.ink2,
    };

    Widget node(String name) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: t.paper,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.ruleStrong),
      ),
      child: Text(
        name,
        style: TextStyle(
          color: t.ink2,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    Widget wire() => Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: _pulse ? 3 : 2,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: _pulse ? t.accent : t.ruleStrong,
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: t.sheet,
        border: Border(top: BorderSide(color: t.ruleStrong)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            expanded: _open,
            child: Tappable(
              radius: 0,
              onTap: () => setState(() => _open = !_open),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Text(
                      l.panelTitle,
                      style: TextStyle(
                        color: t.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l.panelSubtitle,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: t.ink3, fontSize: 13),
                      ),
                    ),
                    Icon(
                      _open ? Icons.expand_more : Icons.expand_less,
                      color: t.ink3,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 132,
                      child: records.isEmpty
                          ? Text(
                              l.panelEmpty,
                              style: TextStyle(color: t.ink3, fontSize: 13),
                            )
                          : ListView(
                              children: [
                                for (final r in records)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 3,
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 62,
                                          child: Text(
                                            r.method,
                                            style: mono.copyWith(
                                              color: methodColor(r.method),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            r.pathAndQuery,
                                            overflow: TextOverflow.ellipsis,
                                            style: mono.copyWith(color: t.ink),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 40,
                                          child: Text(
                                            r.status == 0 ? '—' : '${r.status}',
                                            style: mono.copyWith(
                                              color:
                                                  r.status > 0 && r.status < 400
                                                  ? t.ok
                                                  : t.accentText,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 64,
                                          child: Text(
                                            '${r.durationMs} ms',
                                            textAlign: TextAlign.right,
                                            style: mono.copyWith(color: t.ink3),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  SizedBox(
                    width: 250,
                    child: ExcludeSemantics(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SizedBox(
                            width: 300,
                            child: Row(
                              children: [
                                node('Flutter'),
                                wire(),
                                node('n8n'),
                                wire(),
                                node('MongoDB'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
