import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/history_store.dart';
import 'result_screen.dart';

/// Tab 1 - the home screen. Dark Emerald Radar Vault aesthetic.
///
/// Phase 3-6: runs the local rule engine + hybrid AI classifier,
/// saves the check via `context.read<HistoryStore>()`, then pushes Result.
class CheckScreen extends StatefulWidget {
  const CheckScreen({super.key});

  @override
  State<CheckScreen> createState() => _CheckScreenState();
}

class _CheckScreenState extends State<CheckScreen> {
  final TextEditingController _controller = TextEditingController();

  static const _samples = <(String label, IconData icon, Color color, String text)>[
    (
      'Pension OTP Trap',
      Icons.warning_amber_rounded,
      Color(0xFFF87171),
      'Hello sir, pension arrears of Rs 48,000 pending verification, '
          'reply with the 6-digit code sent to your mobile',
    ),
    (
      'SBI KYC Link',
      Icons.link_rounded,
      Color(0xFFE5B842),
      'dear customer, your sbi kyc has expired, update immediately: '
          'bit.ly/3xk9',
    ),
    (
      'Real Bank OTP',
      Icons.verified_user_outlined,
      Color(0xFF34D399),
      'ICICI Bank: Never share your OTP or PIN with anyone, '
          'including us. Your OTP 774219 is for this transaction only.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onCheckPressed() async {
    // Golden rule: read() for button callbacks - just call, never rebuild.
    final store = context.read<HistoryStore>();
    final text = _controller.text;

    if (text.trim().isEmpty) {
      // Polish 1: never save a blank check. If the clipboard has a
      // message, fill the box AND run the check in the same tap
      // (mentor's UX rule: tap #1 must never feel "broken").
      String clipText = '';
      try {
        final clip = await Clipboard.getData(Clipboard.kTextPlain);
        clipText = clip?.text?.trim() ?? '';
      } catch (_) {
        clipText = '';
      }
      if (!mounted) return;

      if (clipText.isNotEmpty) {
        _controller.text = clipText;
        await _runCheck(clipText, store);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Paste the suspicious message first, then tap Check.',
              style: TextStyle(fontSize: 17),
            ),
          ),
        );
      }
      return;
    }

    await _runCheck(text, store);
  }

  Future<void> _runCheck(String message, HistoryStore store) async {
    // Phase 4.5 (zero-F5): quietly refresh rules before analyzing -
    // throttled to once per 15s and capped at 1.2s, so offline taps
    // fall through instantly to the current engine.
    await store.syncBeforeCheck();
    if (!mounted) return;

    // Phase 5: rules first, ML when reachable, blended verdict back.
    final result = await store.checkMessage(message);
    if (!mounted) return;

    store.addCheck(result); // saves to disk + notifies History tab
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => ResultScreen(result: result)),
    );
  }

  Future<void> _pasteFromClipboard() async {
    String clipText = '';
    try {
      final clip = await Clipboard.getData(Clipboard.kTextPlain);
      clipText = clip?.text ?? '';
    } catch (_) {
      clipText = '';
    }
    if (!mounted) return;
    if (clipText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clipboard is empty.')),
      );
      return;
    }
    setState(() => _controller.text = clipText);
  }

  @override
  Widget build(BuildContext context) {
    final charCount = _controller.text.length;
    final hasText = _controller.text.trim().isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Radar Shield Hero
          const Center(child: _RadarShieldHero()),
          const SizedBox(height: 4),
          const Text(
            'Is this message real?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 25,
              fontWeight: FontWeight.w700,
              color: Color(0xFFF8FAFC),
              height: 1.12,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Paste any SMS or WhatsApp text to check it right away.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              height: 1.25,
              color: Color(0xFFCBD5E1),
            ),
          ),
          const SizedBox(height: 8),

          // Dark Glass Scanner Input Card with integrated bottom toolbar
          SizedBox(
            height: 126,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0D221B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1F3D32), width: 1.2),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onChanged: (_) => setState(() {}),
                      expands: true,
                      minLines: null,
                      maxLines: null,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(
                        fontSize: 18,
                        height: 1.4,
                        color: Color(0xFFF8FAFC),
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Paste the message here...',
                        hintStyle: TextStyle(
                          fontSize: 18,
                          color: Color(0xFF64748B),
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.fromLTRB(16, 14, 16, 6),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 10, 6),
                    child: Row(
                      children: [
                        Text(
                          '$charCount characters',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _pasteFromClipboard,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF34D399),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.content_paste_rounded, size: 19),
                          label: const Text(
                            'Paste',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Clear text',
                          visualDensity: VisualDensity.compact,
                          onPressed: hasText
                              ? () => setState(() => _controller.clear())
                              : null,
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                            color: hasText
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Warm Gold Pill CTA Button
          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: _onCheckPressed,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE5B842),
                foregroundColor: const Color(0xFF071510),
                elevation: 0,
                textStyle: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_scanner_rounded, size: 22),
                  SizedBox(width: 10),
                  Text('CHECK MESSAGE'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Checks run privately on your phone. Smart check never saves your messages.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFFCBD5E1),
            ),
          ),
          const SizedBox(height: 12),

          // TRY A SAMPLE strip
          const Text(
            'TRY A SAMPLE',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final sample in _samples)
                InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => setState(() {
                    _controller.text = sample.$4;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF102820),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFF214236)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(sample.$2, size: 17, color: sample.$3),
                        const SizedBox(width: 6),
                        Text(
                          sample.$1,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFF1F5F9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The concentric emerald Radar + Gold Shield emblem from Mockup 1.
class _RadarShieldHero extends StatelessWidget {
  const _RadarShieldHero();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: CustomPaint(
        painter: _RadarPainter(),
        child: Center(
          child: Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFFE5B842),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Color(0xFF071510),
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.width / 2;

    // Subtle radar sweep cone
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: -math.pi / 2,
        endAngle: 0,
        colors: [
          const Color(0xFF10B981).withValues(alpha: 0.0),
          const Color(0xFF10B981).withValues(alpha: 0.22),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: outerR));
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: outerR),
      -math.pi / 2,
      math.pi / 2.2,
      true,
      sweepPaint,
    );

    // 3 concentric radar rings
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFF1F4738);
    for (final factor in [1.0, 0.74, 0.48]) {
      canvas.drawCircle(center, outerR * factor, ringPaint);
    }

    // Red threat blip (top-right)
    final redBlip = Offset(
      center.dx + outerR * 0.46,
      center.dy - outerR * 0.72,
    );
    canvas.drawCircle(
      redBlip,
      4.0,
      Paint()..color = const Color(0xFFF87171),
    );

    // Green safe blip (bottom-left)
    final greenBlip = Offset(
      center.dx - outerR * 0.52,
      center.dy + outerR * 0.24,
    );
    canvas.drawCircle(
      greenBlip,
      3.5,
      Paint()..color = const Color(0xFF34D399),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
