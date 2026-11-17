import 'dart:io';

import 'package:scam_shield_engine/engine.dart';
import 'package:scam_shield_engine/models.dart';
import 'package:test/test.dart';

void main() {
  late ScamEngine engine;

  setUpAll(() {
    // Same file the demo uses - one source of truth.
    engine =
        ScamEngine.fromJson(File('lib/patterns.json').readAsStringSync());
  });

  test('KYC phishing example scores 112.5 and flags as scam', () {
    final r = engine.analyze(
        'dear customer, your sbi kyc has expired, update immediately: bit.ly/3xk9');

    expect(r.score, 112.5); // (20 + 15 + 40) x 1.5
    expect(r.verdict, Verdict.scam);
    expect(r.categoryCount, 3);
    expect(r.comboApplied, isTrue);
    expect(r.matches, hasLength(3));
  });

  test('a normal message never flags (the false-positive guard)', () {
    final r = engine.analyze('Hi mom, I will be home by 7 for dinner');

    expect(r.score, 0);
    expect(r.verdict, Verdict.clean);
    expect(r.matches, isEmpty);
  });

  test('urgency alone stays clean (below the 20 threshold)', () {
    final r = engine.analyze('Please reply immediately to confirm');

    expect(r.score, 15);
    expect(r.verdict, Verdict.clean);
    expect(r.comboApplied, isFalse);
  });

  test('KYC mention alone is suspicious, NOT scam (one category only)', () {
    final r = engine.analyze('Your SBI KYC has expired. Update it now.');

    expect(r.score, 20);
    expect(r.verdict, Verdict.suspicious);
    expect(r.comboApplied, isFalse);
  });

  test('a shortened link alone is suspicious, NOT scam', () {
    final r = engine.analyze('See details at bit.ly/3xk9');

    expect(r.score, 40);
    expect(r.verdict, Verdict.suspicious);
  });

  test('empty message is clean', () {
    final r = engine.analyze('');

    expect(r.score, 0);
    expect(r.verdict, Verdict.clean);
  });

  test('clean verdict never uses the word "safe"', () {
    final r = engine.analyze('Hello, how are you?');

    expect(r.verdict, Verdict.clean);
    expect(r.verdict.label.toLowerCase(), isNot(contains('safe')));
    expect(r.verdict.advice.toLowerCase(), isNot(contains('guaranteed')));
  });

  // --- Phase 4 safeguard: fromJson must accept both JSON shapes ---

  test('fromJson accepts the {version, patterns} server wrapper', () {
    final wrapped = ScamEngine.fromJson(
        '{"version": 2, "patterns": [{"id": "x", "category": "urgency", "points": 15, "phrases": ["now"]}]}');

    expect(wrapped.patterns, hasLength(1));
    expect(wrapped.patterns.first.id, 'x');
  });

  test('fromJson accepts a bare top-level pattern list', () {
    final bare = ScamEngine.fromJson(
        '[{"id": "x", "category": "urgency", "points": 15, "phrases": ["now"]}]');

    expect(bare.patterns, hasLength(1));
    expect(bare.patterns.first.points, 15);
  });

  // --- Phase 4.5 mentor benchmark: 10 messages, bundled v4 rules ---

  group('Phase 4.5 benchmark: 5 unseen scams vs 5 legit messages', () {
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

    scams.forEach((label, message) {
      test('scam "$label" scores >= 50', () {
        final r = engine.analyze(message);
        expect(r.score, greaterThanOrEqualTo(50),
            reason: 'scored ${r.score} (need >=50)');
        expect(r.verdict, Verdict.scam);
      });
    });

    legit.forEach((label, message) {
      test('legit "$label" stays under 50', () {
        final r = engine.analyze(message);
        expect(r.score, lessThan(50),
            reason: 'scored ${r.score} (need <50)');
        expect(r.verdict, isNot(Verdict.scam));
      });
    });
  });
}
