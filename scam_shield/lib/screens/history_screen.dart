import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/check_result.dart';
import '../state/history_store.dart';
import 'result_screen.dart';

/// Tab 2 - real past checks, read from the shared store.
/// Dark Emerald & Warm Gold design (Mockup 4).
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E231C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF1F3D32)),
        ),
        title: const Text(
          'Clear all history?',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontWeight: FontWeight.w700,
            color: Color(0xFFF8FAFC),
          ),
        ),
        content: const Text(
          'This deletes every past check stored on this device. '
          'It cannot be undone.',
          style: TextStyle(
            fontSize: 16,
            height: 1.4,
            color: Color(0xFFCBD5E1),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (confirmed == true) {
      context.read<HistoryStore>().clearHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryStore>().history;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 12, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Past checks',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${history.length} messages checked',
                      style: const TextStyle(
                        fontSize: 17,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              if (history.isNotEmpty)
                TextButton(
                  onPressed: () => _confirmClear(context),
                  child: const Text(
                    'Clear History',
                    style: TextStyle(
                      fontSize: 18,
                      color: Color(0xFFCBD5E1),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: history.isEmpty
              ? const _EmptyHistory()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 16),
                  itemCount: history.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final result = history[index];
                    return _HistoryCard(result: result);
                  },
                ),
        ),
      ],
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0E231C),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF1F3D32)),
              ),
              child: const Icon(
                Icons.history_rounded,
                size: 48,
                color: Color(0xFFE5B842),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No checks yet',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFFF8FAFC),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Messages you check will be saved here,\n'
              'so you can read their advice again later.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                height: 1.4,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final CheckResult result;

  const _HistoryCard({required this.result});

  Color get _accent => switch (result.level) {
        VerdictLevel.scam => const Color(0xFFF87171),
        VerdictLevel.suspicious => const Color(0xFFFBBF24),
        VerdictLevel.clean => const Color(0xFF34D399),
      };

  IconData get _badgeIcon => switch (result.level) {
        VerdictLevel.scam => Icons.warning_amber_rounded,
        VerdictLevel.suspicious => Icons.error_outline_rounded,
        VerdictLevel.clean => Icons.verified_user_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    final scoreText = result.score == result.score.roundToDouble()
        ? result.score.toInt().toString()
        : '${result.score}';

    return Material(
      color: const Color(0xFF0D221B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFF1F3D32)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => ResultScreen(result: result),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(_badgeIcon, color: accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            result.level.label,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: accent,
                            ),
                          ),
                        ),
                        Text(
                          result.checkedAt,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        height: 1.35,
                        color: Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Risk score $scoreText · ${result.mode}',
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF64748B),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
