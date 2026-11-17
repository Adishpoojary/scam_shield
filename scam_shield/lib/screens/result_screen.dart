import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/check_result.dart';

/// Pushed on top of the tab shell (Navigator.push).
/// Dark Emerald & Warm Gold design with Circular Risk Score Gauge.
class ResultScreen extends StatelessWidget {
  final CheckResult result;

  const ResultScreen({super.key, required this.result});

  Future<void> _copySummaryForFamily(BuildContext context) async {
    final reasonsText = result.reasons.isEmpty
        ? '• No known warning signs matched.'
        : result.reasons.map((r) => '• $r').join('\n');
    final summary =
        '🛡️ Scam Shield Verdict: ${result.level.label}\n'
        'Risk score: ${result.score} (${result.mode})\n\n'
        'Message checked:\n"${result.message}"\n\n'
        'Why:\n$reasonsText\n\n'
        'What to do:\n${result.advice}';

    await Clipboard.setData(ClipboardData(text: summary));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Copied summary! You can now paste it in WhatsApp to share with family.',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Color get _accentColor => switch (result.level) {
        VerdictLevel.scam => const Color(0xFFF87171),
        VerdictLevel.suspicious => const Color(0xFFFBBF24),
        VerdictLevel.clean => const Color(0xFF34D399),
      };

  Color get _pillBgColor => switch (result.level) {
        VerdictLevel.scam => const Color(0xFF2D1618),
        VerdictLevel.suspicious => const Color(0xFF2B2111),
        VerdictLevel.clean => const Color(0xFF0E2E22),
      };

  Color get _adviceBgColor => switch (result.level) {
        VerdictLevel.scam => const Color(0xFF1F1314),
        VerdictLevel.suspicious => const Color(0xFF1F1A10),
        VerdictLevel.clean => const Color(0xFF0C241B),
      };

  String get _subtitle => switch (result.level) {
        VerdictLevel.scam => 'Do not click. Do not reply.',
        VerdictLevel.suspicious => 'Verify independently before acting.',
        VerdictLevel.clean => 'No scam signs found. Still, never share your OTP.',
      };

  @override
  Widget build(BuildContext context) {
    final level = result.level;
    final accent = _accentColor;

    return Scaffold(
      backgroundColor: const Color(0xFF071510),
      appBar: AppBar(
        toolbarHeight: 60,
        backgroundColor: const Color(0xFF071510),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Check result',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFFF8FAFC),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              tooltip: 'Copy summary for family',
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF0E231C),
                side: const BorderSide(color: Color(0xFF1F3D32)),
              ),
              icon: const Icon(
                Icons.share_outlined,
                color: Color(0xFFF8FAFC),
                size: 20,
              ),
              onPressed: () => _copySummaryForFamily(context),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            children: [
              if (result.isDemo) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B2111),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFBBF24)),
                  ),
                  child: const Text(
                    'DEMO DATA - sample verdict',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFBBF24),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Circular Risk Score Ring (Mockups 2 & 3)
              Center(
                child: _RiskScoreGauge(
                  score: result.score,
                  color: accent,
                ),
              ),
              const SizedBox(height: 10),

              // Verdict Pill Badge
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _pillBgColor,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(level.icon, color: accent, size: 22),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          level.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  color: Color(0xFFCBD5E1),
                ),
              ),
              const SizedBox(height: 10),

              // The message that was checked.
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D221B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1F3D32)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MESSAGE',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      result.message,
                      style: const TextStyle(
                        fontSize: 18,
                        height: 1.4,
                        color: Color(0xFFF8FAFC),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // REASONS - structured dark card
              const Text(
                'Why we say this:',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFF8FAFC),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D221B),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF1F3D32)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (result.reasons.isEmpty)
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF133326),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.verified_user_outlined,
                              color: Color(0xFF34D399),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'No warning signs matched in this message.',
                              style: TextStyle(
                                fontSize: 18,
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                          ),
                          const Text(
                            '0',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF34D399),
                            ),
                          ),
                        ],
                      ),
                    for (var i = 0; i < result.reasons.length; i++) ...[
                      if (i > 0)
                        const Divider(
                          color: Color(0xFF18352B),
                          height: 10,
                        ),
                      _ReasonRow(
                        reason: result.reasons[i],
                        accent: accent,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // ADVICE - tinted card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _adviceBgColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: accent,
                          size: 23,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'What to do',
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      result.advice,
                      style: const TextStyle(
                        fontSize: 18,
                        height: 1.4,
                        color: Color(0xFFF1F5F9),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // SCORE - secondary badge at the bottom (preserved for test 1 & 4).
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E231C),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF1F3D32)),
                  ),
                  child: Text(
                    'Risk score: ${result.score}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE5B842),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Phase 5 footer: which layers judged this message.
              Center(
                child: Text(
                  result.mode,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Warm Gold Pill Button: Copy warning for family
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: () => _copySummaryForFamily(context),
                  icon: const Icon(Icons.copy_all_rounded, size: 22),
                  label: const Text('Copy warning for family'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE5B842),
                    foregroundColor: const Color(0xFF071510),
                    textStyle: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  final String reason;
  final Color accent;

  const _ReasonRow({required this.reason, required this.accent});

  @override
  Widget build(BuildContext context) {
    final isAi = reason.contains('Wording looks similar');
    final isLink = reason.contains('Suspicious Link');
    final isUrgency = reason.contains('Urgency');

    final icon = isAi
        ? Icons.psychology_outlined
        : isLink
            ? Icons.link_rounded
            : isUrgency
                ? Icons.schedule_rounded
                : Icons.bolt_rounded;
    final badgeColor = isAi ? const Color(0xFFE5B842) : accent;

    // Extract trailing (+NN) for rule points badge
    String rightBadge = '';
    final plusMatch = RegExp(r'\(\+(\d+)\)').firstMatch(reason);
    if (plusMatch != null) {
      rightBadge = '+${plusMatch.group(1)}';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: badgeColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            reason,
            style: const TextStyle(
              fontSize: 18,
              height: 1.35,
              color: Color(0xFFF1F5F9),
            ),
          ),
        ),
        if (rightBadge.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(
            rightBadge,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: badgeColor,
            ),
          ),
        ],
      ],
    );
  }
}

class _RiskScoreGauge extends StatelessWidget {
  final double score;
  final Color color;

  const _RiskScoreGauge({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    final displayScore =
        score == score.roundToDouble() ? score.toInt().toString() : '$score';

    return SizedBox(
      width: 100,
      height: 100,
      child: CustomPaint(
        painter: _GaugeRingPainter(score: score, color: color),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'RISK SCORE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                displayScore,
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFF8FAFC),
                  height: 1.05,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GaugeRingPainter extends CustomPainter {
  final double score;
  final Color color;

  _GaugeRingPainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 9.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = const Color(0xFF182C24);
    canvas.drawCircle(center, radius, trackPaint);

    // Clamp sweep fraction between 0.06 (small dot at top for score 0) and 1.0
    final fraction = score <= 0 ? 0.06 : (score / 100.0).clamp(0.12, 1.0);
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * fraction,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugeRingPainter oldDelegate) =>
      oldDelegate.score != score || oldDelegate.color != color;
}
