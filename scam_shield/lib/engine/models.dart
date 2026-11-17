/// The four signal categories a rule can belong to.
///
/// Scams are combinations, not single words. Every matched rule belongs
/// to exactly one category, and matching ACROSS categories is what
/// pushes a message into the red (the combo multiplier).
enum SignalCategory {
  urgency, // A - urgency / fear
  authorityOrLure, // B - authority claim or lure
  actionTrap, // C - high-risk action requested
  suspiciousLink, // D - suspicious link
}

extension SignalCategoryInfo on SignalCategory {
  String get label => switch (this) {
        SignalCategory.urgency => 'Urgency / Fear',
        SignalCategory.authorityOrLure => 'Authority / Lure',
        SignalCategory.actionTrap => 'High-Risk Action',
        SignalCategory.suspiciousLink => 'Suspicious Link',
      };
}

/// The three possible outcomes of an analysis.
enum Verdict { scam, suspicious, clean }

extension VerdictInfo on Verdict {
  String get label => switch (this) {
        Verdict.scam => 'Likely Scam',
        Verdict.suspicious => 'Suspicious - Be Careful',
        Verdict.clean => 'No Known Warning Signs Found',
      };

  String get emoji => switch (this) {
        Verdict.scam => '[RED]',
        Verdict.suspicious => '[AMBER]',
        Verdict.clean => '[GREEN]',
      };

  /// Never says "safe" - a new scam could always slip past the rules.
  String get advice => switch (this) {
        Verdict.scam =>
          "Don't click any link and don't share any details. Open your bank's official app or call the helpline printed on your card.",
        Verdict.suspicious =>
          "Treat this as risky. Don't click links - verify directly in the official app or call the company's official number.",
        Verdict.clean =>
          'No known warning signs found - but no scanner can guarantee safety. Never share OTP, PIN or card details with anyone.',
      };
}

/// One rule loaded from patterns.json.
class ScamPattern {
  final String id;
  final SignalCategory category;
  final int points;
  final List<String> phrases;

  /// Phase 4.5 OTP guard: if ANY guard phrase appears in the message,
  /// this rule silently refuses to fire. Example: a real bank SMS says
  /// "Do not share this OTP with anyone" - that must never trigger the
  /// action_trap rules just because it contains the word "OTP".
  final List<String> guards;
  final RegExp? regex;

  const ScamPattern({
    required this.id,
    required this.category,
    required this.points,
    this.phrases = const [],
    this.guards = const [],
    this.regex,
  });

  factory ScamPattern.fromJson(Map<String, dynamic> json) {
    final regexSource = json['regex'] as String?;
    return ScamPattern(
      id: json['id'] as String,
      category: _categoryFrom(json['category'] as String),
      points: json['points'] as int,
      phrases:
          (json['phrases'] as List<dynamic>?)?.cast<String>() ?? const [],
      guards: (json['guards'] as List<dynamic>?)?.cast<String>() ?? const [],
      regex: regexSource == null
          ? null
          : RegExp(regexSource, caseSensitive: false),
    );
  }

  /// Returns the exact text that matched, or null if nothing matched.
  /// [message] must already be lowercased.
  String? match(String message) {
    for (final guard in guards) {
      if (_hasWordBoundary(message, guard)) return null;
    }
    for (final phrase in phrases) {
      if (_hasWordBoundary(message, phrase)) return phrase;
    }
    return regex?.firstMatch(message)?.group(0);
  }

  /// \b-style phrase search: "pan" must NOT match inside "company",
  /// but must match in "your pan is blocked" / "pan," / "(pan)".
  /// Pure string scanning (no RegExp compile per call), equivalent to
  /// RegExp(r'(?:^|[^\w])' + escape(phrase) + r'(?:[^\w]|$)').
  static bool _hasWordBoundary(String message, String phrase) {
    var idx = message.indexOf(phrase);
    while (idx != -1) {
      final before = idx == 0 ? null : message.codeUnitAt(idx - 1);
      final afterIdx = idx + phrase.length;
      final after =
          afterIdx >= message.length ? null : message.codeUnitAt(afterIdx);
      final beforeOk = before == null || !_isWordChar(before);
      final afterOk = after == null || !_isWordChar(after);
      if (beforeOk && afterOk) return true;
      idx = message.indexOf(phrase, idx + 1);
    }
    return false;
  }

  /// [A-Za-z0-9_] - what \w matches.
  static bool _isWordChar(int unit) =>
      (unit >= 0x30 && unit <= 0x39) ||
      (unit >= 0x41 && unit <= 0x5A) ||
      (unit >= 0x61 && unit <= 0x7A) ||
      unit == 0x5F;
}

SignalCategory _categoryFrom(String raw) => switch (raw) {
      'urgency' => SignalCategory.urgency,
      'authority_or_lure' => SignalCategory.authorityOrLure,
      'action_trap' => SignalCategory.actionTrap,
      'suspicious_link' => SignalCategory.suspiciousLink,
      _ => throw FormatException('Unknown category "$raw"'),
    };

/// A rule that fired during analysis - what gets shown line by line.
class MatchedRule {
  final ScamPattern pattern;
  final String matchedOn;

  const MatchedRule({required this.pattern, required this.matchedOn});
}

/// Everything the UI needs to render the result card.
class AnalysisResult {
  final double score;
  final Verdict verdict;
  final List<MatchedRule> matches; // all matches, for display
  final Map<SignalCategory, int> categoryScores; // capped, for scoring
  final bool comboApplied;

  const AnalysisResult({
    required this.score,
    required this.verdict,
    required this.matches,
    required this.categoryScores,
    required this.comboApplied,
  });

  int get categoryCount => categoryScores.length;
  int get baseScore =>
      categoryScores.values.fold<int>(0, (sum, points) => sum + points);
}
