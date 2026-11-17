import 'dart:convert';

import 'models.dart';

/// The scoring engine. Pure Dart, no I/O, no Flutter - this same class
/// will run inside the app in Phase 2/3 with zero changes.
class ScamEngine {
  final List<ScamPattern> patterns;

  /// Phase 4.5: hosts that are ALLOWED to appear in a message without
  /// penalty (real banks, NPCI, India Post...). Filled from the
  /// "trustedDomains" array in patterns.json; empty if the payload
  /// doesn't carry one (e.g. a bare top-level pattern list).
  final List<String> trustedDomains;

  ScamEngine(this.patterns, {this.trustedDomains = const []});

  /// Builds an engine from the contents of patterns.json.
  ///
  /// Accepts either shape (Phase 4 safeguard - server wrapper vs raw list):
  ///   {"version": 4, "patterns": [...], "trustedDomains": [...]}
  ///   [{"id": "...", ...}, ...]          - a bare top-level pattern list
  factory ScamEngine.fromJson(String jsonString) {
    final decoded = jsonDecode(jsonString);
    final List<dynamic> list;
    var trusted = const <String>[];
    if (decoded is Map<String, dynamic>) {
      list = decoded['patterns'] as List<dynamic>;
      trusted =
          (decoded['trustedDomains'] as List<dynamic>?)?.cast<String>() ??
              const [];
    } else if (decoded is List<dynamic>) {
      list = decoded;
    } else {
      throw const FormatException('Rules JSON must be an object or a list');
    }
    final patterns = list
        .map((p) => ScamPattern.fromJson(p as Map<String, dynamic>))
        .toList();
    return ScamEngine(patterns, trustedDomains: trusted);
  }

  /// Scores a message and returns the verdict + every reason that matched.
  ///
  /// Math (mentor's blueprint):
  ///   1. find all matching rules
  ///   2. cap: per category keep only the highest-scoring match
  ///   3. baseScore = sum of the category winners
  ///   4. if >= 2 categories matched -> combo multiplier x1.5
  ///   5. >= 50 scam | >= 20 suspicious | else no warning signs
  AnalysisResult analyze(String message) {
    final lower = message.toLowerCase();

    // Step 1: which rules fire?
    final matches = <MatchedRule>[];
    for (final pattern in patterns) {
      final hit = pattern.match(lower);
      if (hit != null) {
        matches.add(MatchedRule(pattern: pattern, matchedOn: hit));
      }
    }

    // Phase 4.5: smart URL detection - only when NO link rule already
    // fired (the server can still ship its own link_* rules; this is
    // the always-on fallback that catches any URL patterns don't know).
    final hasLinkRule =
        matches.any((m) => m.pattern.category == SignalCategory.suspiciousLink);
    if (!hasLinkRule) {
      final url = _findSuspiciousUrl(lower);
      if (url != null) {
        matches.add(MatchedRule(pattern: _smartLinkRule, matchedOn: url));
      }
    }

    // Step 2: cap per category (a long message can't farm one category).
    final categoryScores = <SignalCategory, int>{};
    for (final m in matches) {
      final current = categoryScores[m.pattern.category] ?? 0;
      if (m.pattern.points > current) {
        categoryScores[m.pattern.category] = m.pattern.points;
      }
    }

    // Steps 3-5: combo multiplier and verdict thresholds.
    final base = categoryScores.values.fold<int>(0, (sum, p) => sum + p);
    final combo = categoryScores.length >= 2;
    final score = combo ? base * 1.5 : base.toDouble();

    final verdict = score >= 50
        ? Verdict.scam
        : score >= 20
            ? Verdict.suspicious
            : Verdict.clean;

    return AnalysisResult(
      score: score,
      verdict: verdict,
      matches: matches,
      categoryScores: categoryScores,
      comboApplied: combo,
    );
  }

  // --- Phase 4.5: smart URL detection -------------------------------

  /// The synthetic rule shown when the detector (not a JSON pattern)
  /// flags a link - so the result card can say "Suspicious Link" like
  /// it always has.
  static final ScamPattern _smartLinkRule = ScamPattern(
    id: 'link_smart_url',
    category: SignalCategory.suspiciousLink,
    points: 40,
  );

  static const _shorteners = {
    'bit.ly', 'tinyurl.com', 't.co', 'goo.gl', 'cutt.ly',
    'rb.gy', 'is.gd', 'shorturl.at', 'tiny.cc',
  };

  static const _suspiciousTlds = {'xyz', 'top', 'click', 'buzz', 'loan'};

  /// URL-ish candidates: with a scheme (http/https/www) or a bare
  /// domain that ends in a real TLD ([a-z]{2,}) - which kills false
  /// hits like "Rs.2", "450.00", "20-Nov.".
  static final _urlRe = RegExp(
    r'(?:https?://|www\.)[^\s]+'
    r'|(?:[a-z0-9-]+\.)+[a-z]{2,}(?:/[^\s]*)?',
    caseSensitive: false,
  );

  /// Returns the first suspicious URL in [lower] (already lowercased),
  /// or null - either because every URL found is trusted, or none were.
  String? _findSuspiciousUrl(String lower) {
    for (final m in _urlRe.allMatches(lower)) {
      final candidate = _trimUrl(m.group(0)!);
      if (candidate.isEmpty) continue;
      if (_isSuspiciousUrl(candidate)) return candidate;
    }
    return null;
  }

  /// Phase 5 safety lock: true when the message links to one of the
  /// trusted domains (banks, India Post, ...) - used to force
  /// mlPoints = 0 for genuine messages even if ML is unsure.
  bool containsTrustedLink(String lower) {
    for (final m in _urlRe.allMatches(lower)) {
      final candidate = _trimUrl(m.group(0)!);
      if (candidate.isEmpty) continue;
      if (_isTrustedHost(_hostOf(candidate))) return true;
    }
    return false;
  }

  /// Sentence punctuation a URL may be glued to: "...sbi.co.in."
  static String _trimUrl(String candidate) {
    var c = candidate;
    while (c.isNotEmpty && '.,;:!?)]}\'"'.contains(c[c.length - 1])) {
      c = c.substring(0, c.length - 1);
    }
    return c;
  }

  /// Classification order (mentor's spec):
  ///   1. raw http://            -> +40 (banks never use plain http)
  ///   2. contains .apk          -> +40
  ///   3. known shortener host   -> +40
  ///   4. suspicious TLD         -> +40
  ///   5. trusted host           -> skip (return false, keep looking)
  ///   6. anything else          -> +40 (unrecognized domain)
  bool _isSuspiciousUrl(String candidate) {
    if (candidate.startsWith('http://')) return true;
    if (candidate.contains('.apk')) return true;

    final host = _hostOf(candidate);
    if (_shorteners.contains(host)) return true;
    if (_suspiciousTlds.any((t) => host == t || host.endsWith('.$t'))) {
      return true;
    }
    return !_isTrustedHost(host);
  }

  /// Scheme, path and "www." stripped: "https://www.x.com/p" -> "x.com".
  static String _hostOf(String candidate) {
    var host = candidate;
    final schemeIdx = host.indexOf('://');
    if (schemeIdx != -1) host = host.substring(schemeIdx + 3);
    final slash = host.indexOf('/');
    if (slash != -1) host = host.substring(0, slash);
    if (host.startsWith('www.')) host = host.substring(4);
    return host;
  }

  /// Trusted: exact host or a subdomain of one ("www." already gone).
  bool _isTrustedHost(String host) =>
      trustedDomains.any((d) => host == d || host.endsWith('.$d'));
}
