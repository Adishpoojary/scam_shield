import 'package:flutter/material.dart';

import '../engine/models.dart';

/// The three possible outcomes - mirrors the Phase 1 engine's Verdict.
enum VerdictLevel { scam, suspicious, clean }

extension VerdictLevelInfo on VerdictLevel {
  /// Exact wording. The clean verdict must NEVER say "Safe" -
  /// a brand-new scam could always slip past the rules.
  String get label => switch (this) {
        VerdictLevel.scam => 'Likely Scam',
        VerdictLevel.suspicious => 'Suspicious - Be Careful',
        VerdictLevel.clean => 'No known warning signs found',
      };

  Color get color => switch (this) {
        VerdictLevel.scam => const Color(0xFFC62828),
        VerdictLevel.suspicious => const Color(0xFFEF6C00),
        VerdictLevel.clean => const Color(0xFF2E7D32),
      };

  IconData get icon => switch (this) {
        VerdictLevel.scam => Icons.error,
        VerdictLevel.suspicious => Icons.warning_amber,
        VerdictLevel.clean => Icons.check_circle,
      };
}

/// The single shape every screen reads a check result from.
///
/// Phase 3 fills it from the real engine via [CheckResult.fromAnalysis].
/// The Result screen never cares where it came from - that is why it
/// needed zero changes between Phase 2 and Phase 3.
class CheckResult {
  final String message;
  final VerdictLevel level;
  final List<String> reasons;
  final String advice;
  final double score;
  final String checkedAt;
  final bool isDemo;

  /// Phase 5: which layers judged this message -
  /// "Hybrid: Rules v5 + AI" or "Offline: Rules v4".
  final String mode;

  const CheckResult({
    required this.message,
    required this.level,
    required this.reasons,
    required this.advice,
    required this.score,
    required this.checkedAt,
    this.isDemo = false,
    this.mode = 'Offline rules',
  });

  /// Bridges the Phase 1 engine's output to the UI shape:
  /// every matched rule becomes one human-readable reason line,
  /// the engine's verdict/advice/score come across untouched.
  /// [extraReasons] lets Phase 5 append the AI classifier line.
  factory CheckResult.fromAnalysis(
    String message,
    AnalysisResult analysis, {
    List<String> extraReasons = const [],
    String mode = 'Offline rules',
  }) {
    return CheckResult(
      message: message,
      level: switch (analysis.verdict) {
        Verdict.scam => VerdictLevel.scam,
        Verdict.suspicious => VerdictLevel.suspicious,
        Verdict.clean => VerdictLevel.clean,
      },
      reasons: [
        for (final m in analysis.matches)
          '"${m.matchedOn}" - ${m.pattern.category.label} (+${m.pattern.points})',
        ...extraReasons,
      ],
      advice: analysis.verdict.advice,
      score: analysis.score,
      checkedAt: formatCheckedAt(DateTime.now()),
      mode: mode,
    );
  }

  // --- persistence (shared_preferences stores one JSON list) ---

  Map<String, dynamic> toJson() => {
        'message': message,
        'level': level.name,
        'reasons': reasons,
        'advice': advice,
        'score': score,
        'checkedAt': checkedAt,
        'isDemo': isDemo,
        'mode': mode,
      };

  factory CheckResult.fromJson(Map<String, dynamic> json) => CheckResult(
        message: json['message'] as String,
        level: VerdictLevel.values.byName(json['level'] as String),
        reasons: (json['reasons'] as List<dynamic>).cast<String>(),
        advice: json['advice'] as String,
        score: (json['score'] as num).toDouble(),
        checkedAt: json['checkedAt'] as String,
        isDemo: json['isDemo'] as bool? ?? false,
        // Pre-Phase-5 history entries have no mode.
        mode: json['mode'] as String? ?? 'Offline rules',
      );
}

/// "Today, 9:14 AM" / "Yesterday, 6:02 PM" / "Mon, 8:31 PM".
String formatCheckedAt(DateTime time, {DateTime? now}) {
  now ??= DateTime.now();
  const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(time.year, time.month, time.day);

  var hour = time.hour % 12;
  if (hour == 0) hour = 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final ampm = time.hour < 12 ? 'AM' : 'PM';
  final clock = '$hour:$minute $ampm';

  if (day == today) return 'Today, $clock';
  if (day == today.subtract(const Duration(days: 1))) {
    return 'Yesterday, $clock';
  }
  return '${dayNames[time.weekday - 1]}, $clock';
}
