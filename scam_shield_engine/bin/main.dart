import 'dart:io';

import 'package:scam_shield_engine/engine.dart';
import 'package:scam_shield_engine/models.dart';

/// The KYC phishing example from the project brief - our north star.
/// Run with no arguments to test it:
///   dart run bin/main.dart
/// Or pass your own message to test anything:
///   dart run bin/main.dart "Hi mom, running late for dinner"
const kycExample =
    'dear customer, your sbi kyc has expired, update immediately: bit.ly/3xk9';

Future<void> main(List<String> args) async {
  final message = args.isNotEmpty ? args.join(' ') : kycExample;

  final patternsFile = File('lib/patterns.json');
  if (!patternsFile.existsSync()) {
    stderr.writeln('Run this from the package root:');
    stderr.writeln('  cd scam_shield_engine');
    stderr.writeln('  dart run bin/main.dart');
    exit(1);
  }

  final engine = ScamEngine.fromJson(await patternsFile.readAsString());
  final result = engine.analyze(message);

  _printReport(message, result);
}

void _printReport(String message, AnalysisResult r) {
  final line = '-' * 60;

  print(line);
  print(' MESSAGE');
  print(line);
  print(message);

  print('');
  print(line);
  print(' SCORE:   ${_num(r.score)}'
      '   (base ${r.baseScore}'
      '${r.comboApplied ? ' x 1.5 combo' : ''}'
      ' - ${r.categoryCount} ${r.categoryCount == 1 ? 'category' : 'categories'} matched)');
  print(' VERDICT: ${r.verdict.emoji} ${r.verdict.label.toUpperCase()}');
  print(line);

  if (r.matches.isEmpty) {
    print(' No patterns matched.');
  } else {
    print(' MATCHED PATTERNS:');
    for (final m in r.matches) {
      print('   * "${m.matchedOn}"'
          ' - ${m.pattern.category.label} (+${m.pattern.points})');
    }
  }

  print('');
  print(' ADVICE:');
  print(' ${r.verdict.advice}');
  print(line);
}

/// Prints 112.5 as "112.5" but 15.0 as "15" (scores look cleaner).
String _num(num n) => n == n.roundToDouble() ? n.toInt().toString() : '$n';
