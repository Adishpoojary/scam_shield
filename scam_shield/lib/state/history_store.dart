import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/engine.dart';
import '../engine/models.dart';
import '../models/check_result.dart';
import '../models/ml_prediction.dart';

/// Phase 5: fetches the ML verdict. The default implementation talks
/// to FastAPI (POST /predict, 1.5s cap, null when unreachable);
/// widget tests inject their own to stay hermetic.
typedef MlPredictor = Future<MlPrediction?> Function(String text);

/// The app's single source of truth: the active [ScamEngine] + past checks.
///
/// Golden rule of Provider:
///   - HistoryScreen uses `context.watch<HistoryStore>()` in build()
///     -> rebuilds the list the moment a check is saved.
///   - CheckScreen uses `context.read<HistoryStore>()` in onPressed
///     -> just calls methods, never rebuilds the button.
///
/// The engine lives in this store on purpose (mentor polish point 3):
/// Phase 4's FastAPI only has to hand us a new rules JSON string and call
/// [loadEngine] - zero refactor.
class HistoryStore extends ChangeNotifier {
  /// Where the Phase 1 rules ship inside the app (offline default).
  static const _assetRulesPath = 'lib/engine/patterns.json';

  /// Configurable server URL via `--dart-define=API_BASE_URL=...`
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  /// Phase 5: the ML endpoint (Layer 2).
  static const predictUrl = '$baseUrl/predict';

  /// Optional test seam - when set, it REPLACES the real HTTP call.
  final MlPredictor? _mlPredictor;

  HistoryStore({this._mlPredictor});

  // Keys for local storage (shared_preferences).
  static const _historyKey = 'history_v1';
  static const _engineKey = 'engine_rules_v1';

  /// The active rules. Loaded from the asset, or from a cached copy
  /// that Phase 4 (FastAPI) may have written earlier.
  late ScamEngine engine;

  /// Newest check first. Watched by HistoryScreen.
  final List<CheckResult> history = [];

  SharedPreferences? _prefs;

  /// The bundled rules JSON, loaded once per process. The file never
  /// changes at runtime (Phase 4 swaps rules via [loadEngine] + prefs),
  /// so caching it is safe - and it keeps tests from re-hitting the
  /// asset channel for every store they create.
  static String? _assetRulesJson;

  Future<String> _loadAssetRules() async {
    return _assetRulesJson ??= await rootBundle.loadString(_assetRulesPath);
  }

  /// Load the engine (cached rules > bundled asset) and saved history.
  /// Called once from main() before runApp.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    // Engine: prefer rules cached by Phase 4, fall back to the bundled asset.
    // If a cached copy is ever corrupt, fall back to the asset too.
    try {
      final cached = _prefs!.getString(_engineKey);
      engine = ScamEngine.fromJson(cached ?? await _loadAssetRules());
    } catch (_) {
      engine = ScamEngine.fromJson(await _loadAssetRules());
    }

    // History: a JSON string on disk -> typed results.
    final raw = _prefs!.getString(_historyKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      history.addAll(
        list.map((e) => CheckResult.fromJson(e as Map<String, dynamic>)),
      );
    }

    notifyListeners();
  }

  /// Phase 4 entry point: hot-swap the rules from a JSON string
  /// (fetched from FastAPI, cached in shared_preferences).
  ///
  /// Safeguard: the payload is parsed and validated BEFORE anything is
  /// written to disk - a corrupted server response can never overwrite
  /// the working local cache.
  Future<void> loadEngine(String rulesJson) async {
    final newEngine = ScamEngine.fromJson(rulesJson); // throws if corrupt
    if (newEngine.patterns.isEmpty) {
      throw const FormatException('Rules payload contains no patterns');
    }
    engine = newEngine;
    await _prefs?.setString(_engineKey, rulesJson);
    notifyListeners();
  }

  /// Version + size of the ACTIVE rules - shown as the tiny AppBar badge
  /// so the Phase 4 hot-swap is visible on screen (safeguard 4).
  int get rulesVersion {
    final source = _prefs?.getString(_engineKey) ?? _assetRulesJson;
    if (source != null) {
      try {
        final decoded = jsonDecode(source);
        if (decoded is Map<String, dynamic> && decoded['version'] is int) {
          return decoded['version'] as int;
        }
      } catch (_) {
        // Fall through to the bundled default.
      }
    }
    return 1;
  }

  int get rulesCount => engine.patterns.length;

  /// Phase 4: ask FastAPI for newer rules. Non-blocking, 3s cap, silent
  /// when offline - the current engine is never touched unless the
  /// server genuinely has a HIGHER version.
  static const serverUrl = '$baseUrl/patterns';

  /// Phase 4.5 (zero-F5 auto-sync): when syncRules was last ATTEMPTED,
  /// no matter how it ended - used to throttle background refreshes.
  DateTime? _lastSyncAttempt;

  /// A parent tapping CHECK never waits more than ~1.2s on the network,
  /// and we never spam the server faster than one attempt per 15s.
  static const _syncThrottle = Duration(seconds: 15);
  static const _checkSyncCap = Duration(milliseconds: 1200);

  Future<void> syncRules({Duration timeout = const Duration(seconds: 3)}) async {
    _lastSyncAttempt = DateTime.now();
    try {
      final resp = await http
          .get(Uri.parse(serverUrl))
          .timeout(timeout);
      if (resp.statusCode != 200) return;
      final body = jsonDecode(resp.body);
      if (body is! Map<String, dynamic>) return;
      final serverVersion = body['version'];
      if (serverVersion is! int || serverVersion <= rulesVersion) return;
      await loadEngine(resp.body); // validates before caching
    } catch (_) {
      // Offline / unreachable / bad payload: keep current rules. Silent.
    }
  }

  /// Phase 4.5: called right before engine.analyze on every CHECK tap.
  /// Syncs only when none was attempted yet or the last attempt is
  /// older than 15s; capped at 1200ms so the button stays instant.
  /// Never throws - on timeout/offline the current rules are used.
  Future<void> syncBeforeCheck() async {
    final last = _lastSyncAttempt;
    if (last != null && DateTime.now().difference(last) < _syncThrottle) {
      return;
    }
    await syncRules(timeout: _checkSyncCap);
  }

  // --- Phase 5: ML layer (POST /predict) + hybrid blending ---

  /// Best-effort ML verdict. Never throws: offline, timeout (1.5s cap),
  /// 400/500 or a malformed body all mean "null" = offline fallback.
  Future<MlPrediction?> _fetchMl(String text) async {
    try {
      final resp = await http
          .post(
            Uri.parse(predictUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': text}),
          )
          .timeout(const Duration(milliseconds: 1500));
      if (resp.statusCode != 200) return null;
      final body = jsonDecode(resp.body);
      if (body is! Map<String, dynamic>) return null;
      return MlPrediction.fromJson(body);
    } catch (_) {
      return null;
    }
  }

  /// The full Phase 5.5 check:
  ///  1. Layer 1 (Dart rules, instant) always runs first on-device.
  ///  2. Privacy gate: if rules already scored >= 50 (Likely Scam), OR
  ///     if a safety lock triggered (defensive "do not share" wording or
  ///     trusted bank link with zero rule matches), NEVER send the SMS
  ///     over the network.
  ///  3. Otherwise, ask Layer 2 (ML) when reachable, and blend:
  ///     * proba < 0.65 -> 0, 0.65-0.82 -> +25 (Amber), >= 0.82 -> round(p * 65) (Red)
  ///     * final = rulesScore + mlPoints
  Future<CheckResult> checkMessage(String message) async {
    final analysis = engine.analyze(message); // Layer 1 - always runs

    // Legit-SMS safety lock + privacy gate: skip network if already
    // confirmed scam (>= 50) or if a genuine bank guard triggered.
    final lower = message.toLowerCase();
    final defensive = const ['do not share', 'never share', "don't share"]
        .any(lower.contains);
    final trustedOnly =
        analysis.matches.isEmpty && engine.containsTrustedLink(lower);

    final offlineMode = 'v$rulesVersion • On-device';
    if (analysis.score >= 50 || defensive || trustedOnly) {
      return CheckResult.fromAnalysis(message, analysis, mode: offlineMode);
    }

    MlPrediction? ml;
    try {
      ml = _mlPredictor != null
          ? await _mlPredictor(message)
          : await _fetchMl(message);
    } catch (_) {
      ml = null; // an injected predictor may also fail - stay offline
    }

    if (ml == null) {
      return CheckResult.fromAnalysis(message, analysis, mode: offlineMode);
    }

    final p = ml.scamProbability;
    final mlPoints = p >= 0.82 ? (p * 65).round() : p >= 0.65 ? 25 : 0;
    final hybridMode = 'v$rulesVersion • Offline + Smart Check';

    if (mlPoints == 0) {
      return CheckResult.fromAnalysis(message, analysis, mode: hybridMode);
    }

    // Blend: finalScore = ruleScore + mlPoints.
    final blended = analysis.score + mlPoints;
    final verdict = blended >= 50
        ? Verdict.scam
        : blended >= 20
            ? Verdict.suspicious
            : Verdict.clean;
    final augmented = AnalysisResult(
      score: blended,
      verdict: verdict,
      matches: analysis.matches,
      categoryScores: analysis.categoryScores,
      comboApplied: analysis.comboApplied,
    );

    final reasonLine = ml.topSignals.isEmpty
        ? '⚠️ Wording looks similar to known scam messages'
        : '⚠️ Wording looks similar to known scam messages '
            '(mentions ${ml.topSignals.map((s) => "'$s'").join(', ')})';
    return CheckResult.fromAnalysis(
      message,
      augmented,
      extraReasons: [reasonLine],
      mode: hybridMode,
    );
  }

  /// Save a fresh check (called from CheckScreen via context.read).
  Future<void> addCheck(CheckResult result) {
    history.insert(0, result); // newest first
    notifyListeners(); // History tab rebuilds instantly
    return _save();
  }

  /// Wipe everything (called from HistoryScreen's Clear History button).
  Future<void> clearHistory() async {
    history.clear();
    notifyListeners();
    await _prefs?.remove(_historyKey);
  }

  Future<void> _save() async {
    final raw = jsonEncode(history.map((r) => r.toJson()).toList());
    await _prefs?.setString(_historyKey, raw);
  }
}
