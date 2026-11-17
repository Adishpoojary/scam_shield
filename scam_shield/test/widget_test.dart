import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:scam_shield/main.dart';
import 'package:scam_shield/engine/models.dart';
import 'package:scam_shield/models/check_result.dart';
import 'package:scam_shield/models/ml_prediction.dart';
import 'package:scam_shield/screens/result_screen.dart';
import 'package:scam_shield/state/history_store.dart';

/// The Phase 1 KYC example: (20 + 15 + 40) x 1.5 = 112.5 -> Likely Scam.
const kycMessage =
    'dear customer, your sbi kyc has expired, update immediately: '
    'bit.ly/3xk9';

Future<HistoryStore> makeStore({MlPredictor? mlPredictor}) async {
  final store = HistoryStore(mlPredictor: mlPredictor);
  await store.init(); // loads patterns.json asset + empty history
  return store;
}

Future<void> pumpApp(WidgetTester tester, HistoryStore store) async {
  await tester.pumpWidget(ScamShieldApp(store: store));
  await tester.pumpAndSettle();
}

/// Clipboard mock: tests control what Clipboard.getData returns.
void mockClipboard(WidgetTester tester, {String? text}) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.getData') {
        // Real platforms return null (not {text: null}) for an empty
        // clipboard - and Clipboard.getData throws on a null text field.
        return text == null ? null : <String, dynamic>{'text': text};
      }
      return null;
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // In-memory storage for shared_preferences (no real disk in tests).
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('paste KYC message -> real engine verdict with score 112.5',
      (tester) async {
    final store = await makeStore();
    await pumpApp(tester, store);

    await tester.enterText(find.byType(TextField), kycMessage);
    await tester.tap(find.text('CHECK MESSAGE'));
    await tester.pumpAndSettle();

    // The Result screen was pushed with REAL engine output...
    expect(find.byType(ResultScreen), findsOneWidget);
    expect(find.text('Likely Scam'), findsOneWidget);
    // ...no more demo data (Phase 3 removed it).
    expect(find.text('DEMO DATA - sample verdict'), findsNothing);

    // Score badge sits at the bottom of the ListView - scroll like a user.
    await tester.drag(
      find.descendant(
        of: find.byType(ResultScreen),
        matching: find.byType(ListView),
      ),
      const Offset(0, -550),
    );
    await tester.pumpAndSettle();
    expect(find.text('Risk score: 112.5'), findsOneWidget);

    // Reasons came from the 18-rule engine.
    expect(find.textContaining('Suspicious Link'), findsWidgets);

    // And the check was saved to the store (History tab reads this).
    expect(store.history, hasLength(1));
    expect(store.history.first.level, VerdictLevel.scam);
  });

  testWidgets('empty box + empty clipboard -> friendly SnackBar, no blank save',
      (tester) async {
    mockClipboard(tester, text: null);
    final store = await makeStore();
    await pumpApp(tester, store);

    await tester.tap(find.text('CHECK MESSAGE'));
    await tester.pump(); // start the SnackBar animation
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('Paste the suspicious message first, then tap Check.'),
      findsOneWidget,
    );
    expect(store.history, isEmpty); // nothing blank was ever saved
  });

  testWidgets('empty box + clipboard text -> pastes AND checks in one tap',
      (tester) async {
    mockClipboard(tester, text: kycMessage);
    final store = await makeStore();
    await pumpApp(tester, store);

    await tester.tap(find.text('CHECK MESSAGE'));
    await tester.pumpAndSettle();

    // One tap did both: box filled from clipboard and verdict shown.
    expect(find.byType(ResultScreen), findsOneWidget);
    expect(find.text('Likely Scam'), findsOneWidget);
    expect(store.history, hasLength(1));
  });

  testWidgets('check lands in History; tapping the row reopens its Result',
      (tester) async {
    final store = await makeStore();
    await pumpApp(tester, store);

    await tester.enterText(find.byType(TextField), kycMessage);
    await tester.tap(find.text('CHECK MESSAGE'));
    await tester.pumpAndSettle();
    expect(store.history, hasLength(1));

    // Back to the tab shell, then open History (watch rebuilds the list).
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(find.text('Likely Scam'), findsOneWidget);

    // Polish 2: the row is tappable -> full ResultScreen again.
    await tester.tap(find.text('Likely Scam'));
    await tester.pumpAndSettle();
    expect(find.byType(ResultScreen), findsOneWidget);
    expect(find.text('Risk score: 112.5'), findsNothing); // badge below fold
  });

  testWidgets('Clear History asks for confirmation, then empties the list',
      (tester) async {
    final store = await makeStore();
    await pumpApp(tester, store);

    await tester.enterText(find.byType(TextField), kycMessage);
    await tester.tap(find.text('CHECK MESSAGE'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(store.history, hasLength(1));

    // Polish 2: confirmation dialog before destroying anything.
    await tester.tap(find.text('Clear History'));
    await tester.pumpAndSettle();
    expect(find.text('Clear all history?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.history, hasLength(1)); // cancel keeps the data

    await tester.tap(find.text('Clear History'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(store.history, isEmpty);
    expect(find.text('No checks yet'), findsOneWidget);
  });

  test('history survives an app restart (shared_preferences round-trip)',
      () async {
    // "App open #1": run a check and save it.
    final store1 = HistoryStore();
    await store1.init();
    final result = CheckResult.fromAnalysis(
      kycMessage,
      store1.engine.analyze(kycMessage),
    );
    await store1.addCheck(result);

    // "App restart": a brand-new store reads the same storage.
    final store2 = HistoryStore();
    await store2.init();

    expect(store2.history, hasLength(1));
    expect(store2.history.first.message, kycMessage);
    expect(store2.history.first.level, VerdictLevel.scam);
    expect(store2.history.first.score, 112.5);
  });

  test('syncRules with a dead server leaves the engine untouched', () async {
    // flutter_test mocks all HTTP (every request answers 400) - exactly
    // the "FastAPI isn't running" path a parent's phone will hit.
    final store = HistoryStore();
    await store.init();
    final patternsBefore = store.engine.patterns.length;

    await store.syncRules(); // must never throw...

    expect(store.engine.patterns.length, patternsBefore);
    expect(store.rulesVersion, 4); // ...and never claim an upgrade
  });

  test('loadEngine rejects bad payloads before anything is cached', () async {
    final store = HistoryStore();
    await store.init();
    final before = store.engine.patterns.length;

    // Empty pattern list -> rejected.
    await expectLater(
      store.loadEngine('{"version": 9, "patterns": []}'),
      throwsA(isA<FormatException>()),
    );
    expect(store.engine.patterns.length, before);

    // Not even valid JSON -> rejected.
    await expectLater(
      store.loadEngine('this is not json'),
      throwsA(isA<FormatException>()),
    );
    // Nothing was written: the active version is still the bundled one.
    expect(store.rulesVersion, 4);
    expect(store.rulesCount, before);
  });

  test('Phase 4 hot-swap: new server rules detect a new scam phrase',
      () async {
    final store = HistoryStore();
    await store.init();
    const festivalMsg =
        'Congrats! Your diwali bonus of Rs.2000 has been credited. '
        'Click to claim: bit.ly/dwl7k';

    // Bundled v1 rules have never heard of a "diwali bonus".
    final before = store.engine.analyze(festivalMsg);
    expect(before.matches.any((m) => m.matchedOn.contains('diwali')), isFalse);

    // Server payload (v2): only the two rules relevant to this message.
    const serverPayload = r'''
{"version": 2, "patterns": [
  {"id": "lure_festival_bonus", "category": "authority_or_lure", "points": 20, "phrases": ["diwali bonus"]},
  {"id": "link_shortener", "category": "suspicious_link", "points": 40, "regex": "(?:https?://)?(?:bit\\.ly)/"}
]}
''';
    await store.loadEngine(serverPayload);

    // Badge data updates instantly (this is what the AppBar shows).
    expect(store.rulesVersion, 2);
    expect(store.rulesCount, 2);

    // And the SAME message now matches the brand-new rule.
    final after = store.engine.analyze(festivalMsg);
    expect(after.matches.any((m) => m.matchedOn.contains('diwali')), isTrue);
    expect(after.score, 90); // (20 + 40) x 1.5
  });

  // --- Phase 4.5 mentor benchmark: 10 messages, bundled v4 rules ---
  // 5 UNSEEN scam shapes must land >= 50 (Likely Scam);
  // 5 legit/personal messages must stay < 50 (never a red verdict).
  test('Phase 4.5 benchmark: 5 unseen scams score >=50, 5 legit stay <50',
      () async {
    final store = await makeStore();

    const scams = {
      'digital arrest threat':
          'Your name in the FIR complaint matches. You are under '
          'digital arrest for illegal goods. Pay Rs.5000 fine immediately '
          'or case filed against you.',
      'loan offer + raw http':
          'Pre-approved loan of Rs.5 lakh at 0% interest! Pay '
          'verification fee Rs.299 to disburse: http://apply4u.xyz/loan',
      'fake India Post + raw http':
          'India Post: incomplete address, package held. Pay '
          're-delivery fee Rs.25 to release: '
          'http://indiapost-track.xyz/pk',
      'otp + account blocked':
          'Urgent: share OTP 482910 or account blocked. Do it '
          'within 2 hours.',
      'lottery + upi pin':
          'You have won Rs.25000 lottery! Act now - send your '
          'UPI PIN to claim prize money.',
    };

    const legit = {
      'SBI EMI (onlinesbi.sbi)':
          'Dear Customer, EMI of Rs.12,500 for your SBI loan is due '
          'on 20-Nov. Pay at onlinesbi.sbi to avoid late fee.',
      'HDFC debit alert (hdfcbank.com)':
          'HDFC Bank: Debit card ending 9042 used for Rs.2,399 at '
          'SHOPMART. If not you, log in to hdfcbank.com to block.',
      'ICICI do-not-share warning':
          'ICICI Bank: Never share your OTP or PIN with anyone, '
          'including us. Your OTP 774219 is for this transaction only.',
      'India Post tracking (indiapost.gov.in)':
          'India Post: Your parcel NX4471 is out for delivery. Track '
          'it at indiapost.gov.in/track. Thank you for using India Post.',
      'family text':
          'Hi beta, reaching station at 6.30. Bring the yellow bag '
          'and call me when free. - Papa',
    };

    for (final e in scams.entries) {
      final r = store.engine.analyze(e.value);
      expect(r.score, greaterThanOrEqualTo(50),
          reason: 'scam "${e.key}" scored ${r.score} (need >=50)');
      expect(r.verdict, Verdict.scam, reason: 'scam "${e.key}"');
    }

    for (final e in legit.entries) {
      final r = store.engine.analyze(e.value);
      expect(r.score, lessThan(50),
          reason: 'legit "${e.key}" scored ${r.score} (need <50)');
      expect(r.verdict, isNot(Verdict.scam), reason: 'legit "${e.key}"');
    }
  });

  // --- Phase 5: hybrid Rules + AI blending ---

  testWidgets(
      'Phase 5: AI hybrid boosts a sneaky conversational scam to '
      'Likely Scam', (tester) async {
    // Mocked /predict endpoint: high confidence on this one message.
    final store = await makeStore(
      mlPredictor: (text) async => const MlPrediction(
        scamProbability: 0.85,
        topSignals: ['pension arrears', '6 digit'],
        modelVersion: 'tfidf-logreg-v3',
      ),
    );
    await pumpApp(tester, store);

    const sneaky =
        'Hello sir, pension arrears of Rs 48,000 pending verification, '
        'reply with the 6-digit code sent to your mobile';

    // On RULES alone this conversational scam stays far below 50 -
    // that gap is exactly why Phase 5 exists.
    expect(store.engine.analyze(sneaky).score, lessThan(20));

    await tester.enterText(find.byType(TextField), sneaky);
    await tester.tap(find.text('CHECK MESSAGE'));
    await tester.pumpAndSettle();

    // Blended verdict: rules 0 + round(0.85 x 65) = +55 -> Likely Scam.
    expect(find.byType(ResultScreen), findsOneWidget);
    expect(find.text('Likely Scam'), findsOneWidget);
    expect(
      find.textContaining('Wording looks similar to known scam messages'),
      findsOneWidget,
    );
    expect(
      find.textContaining("'pension arrears', '6 digit'"),
      findsOneWidget,
    );
    expect(store.history.first.score, greaterThanOrEqualTo(50));

    // Footer (below the fold, like the score badge) shows Smart Check mode.
    await tester.drag(
      find.descendant(
        of: find.byType(ResultScreen),
        matching: find.byType(ListView),
      ),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Offline + Smart Check'), findsOneWidget);
  });

  testWidgets(
      'Phase 5: /predict unreachable -> check still succeeds offline',
      (tester) async {
    // No injected predictor: the real POST goes through flutter_test's
    // HTTP mock (400) = "FastAPI is not running" on a parent's phone.
    final store = await makeStore();
    await pumpApp(tester, store);

    await tester.enterText(find.byType(TextField), kycMessage);
    await tester.tap(find.text('CHECK MESSAGE'));
    await tester.pumpAndSettle();

    // Pure local-rules result, instantly, no exception, no AI line.
    expect(find.byType(ResultScreen), findsOneWidget);
    expect(find.text('Likely Scam'), findsOneWidget);
    expect(
      find.textContaining('Wording looks similar to known scam messages'),
      findsNothing,
    );
    expect(store.history, hasLength(1));

    await tester.drag(
      find.descendant(
        of: find.byType(ResultScreen),
        matching: find.byType(ListView),
      ),
      const Offset(0, -550),
    );
    await tester.pumpAndSettle();
    expect(find.text('Risk score: 112.5'), findsOneWidget);
    expect(find.textContaining('On-device'), findsOneWidget);
  });

  test('Phase 5.5: privacy gate skips /predict when rules >= 50 or locked, '
      'and enforces 0.65 / 0.82 thresholds', () async {
    var mlCalled = 0;
    final store = await makeStore(
      mlPredictor: (text) async {
        mlCalled++;
        if (text.contains('borderline')) {
          return const MlPrediction(
            scamProbability: 0.60,
            topSignals: ['borderline'],
            modelVersion: 'tfidf-logreg-v3',
          );
        }
        if (text.contains('amber')) {
          return const MlPrediction(
            scamProbability: 0.68,
            topSignals: ['amber'],
            modelVersion: 'tfidf-logreg-v3',
          );
        }
        return const MlPrediction(
          scamProbability: 0.85,
          topSignals: ['red'],
          modelVersion: 'tfidf-logreg-v3',
        );
      },
    );

    // 1. Rules >= 50 (KYC scam) -> never calls ML.
    await store.checkMessage(kycMessage);
    expect(mlCalled, 0);

    // 2. Defensive OTP warning -> never calls ML.
    await store.checkMessage(
      'ICICI Bank: Never share your OTP with anyone. OTP is 774219.',
    );
    expect(mlCalled, 0);

    // 3. Unsure message with proba 0.60 (< 0.65) -> stays 0 ML points.
    final low = await store.checkMessage('hello borderline message');
    expect(mlCalled, 1);
    expect(low.score, 0);
    expect(low.level, VerdictLevel.clean);

    // 4. Unsure message with proba 0.68 (>= 0.65, < 0.82) -> +25 Amber.
    final mid = await store.checkMessage('hello amber message');
    expect(mid.score, 25);
    expect(mid.level, VerdictLevel.suspicious);

    // 5. Unsure message with proba 0.85 (>= 0.82) -> +55 Red.
    final high = await store.checkMessage('hello red message');
    expect(high.score, 55);
    expect(high.level, VerdictLevel.scam);
  });

  testWidgets(
      'Phase 6 UI polish: sample chip fills scanner and Learn tab shows '
      '2-layer shield explainer', (tester) async {
    final store = await makeStore();
    await pumpApp(tester, store);

    expect(find.text('Scam Protection Active'), findsOneWidget);

    // Tapping a quick-try sample chip populates the TextField immediately.
    await tester.ensureVisible(find.text('SBI KYC Link'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SBI KYC Link'));
    await tester.pumpAndSettle();
    expect(find.textContaining('sbi kyc has expired'), findsOneWidget);

    // Switching to the Learn tab shows the 2-Layer Shield architecture card.
    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();
    expect(find.text('How Our 2-Layer Shield Works'), findsOneWidget);
  });
}
