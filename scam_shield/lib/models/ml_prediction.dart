/// Phase 5: the ML layer's answer for one message
/// (POST http://localhost:8000/predict).
class MlPrediction {
  /// P(scam) from the TF-IDF + Logistic Regression pipeline, 0.0 - 1.0.
  final double scamProbability;

  /// Top n-grams that pushed the score up (tfidf x coefficient).
  final List<String> topSignals;

  final String modelVersion;

  const MlPrediction({
    required this.scamProbability,
    required this.topSignals,
    required this.modelVersion,
  });

  factory MlPrediction.fromJson(Map<String, dynamic> json) => MlPrediction(
        scamProbability: (json['scam_probability'] as num).toDouble(),
        topSignals:
            (json['top_signals'] as List<dynamic>?)?.cast<String>() ??
                const [],
        modelVersion: json['model_version'] as String? ?? 'unknown',
      );
}
