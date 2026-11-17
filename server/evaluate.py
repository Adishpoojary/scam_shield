"""Phase 6 ML Evaluation & Benchmark Report (Stratified 5-Fold CV).

Prints a complete, interview-ready evaluation report:
  1. Dataset summary (version, total, class balance)
  2. Stratified 5-Fold Cross-Validation metrics (Accuracy, Precision,
     Recall, F1-Score, ROC-AUC, per-fold F1)
  3. 2x2 Out-of-Fold Confusion Matrix + False Positive Rate
  4. Top 10 Scam vs. Legit N-Grams (explainability audit)
  5. Held-out Unseen Conversational Scams & Genuine SMS verification

Run:  python evaluate.py
"""

from ml_model import evaluate_model, predict_sms, top_model_features
from test_ml import GENUINE, NOVEL_SCAMS


def main() -> None:
    m = evaluate_model(k=5)
    cm = m["confusion_matrix"]
    feats = top_model_features(n=10)

    print("=" * 72)
    print(f" SCAM SHIELD - PHASE 6 ML EVALUATION REPORT ({m['model_version']})")
    print("=" * 72)
    print(
        f" Dataset Version : v{m['dataset_version']} "
        f"({m['dataset_size']} examples: {m['scam_count']} scam / "
        f"{m['legit_count']} legit)"
    )
    print(
        f" Validation      : {m['cv_strategy']} across {m['group_count']} "
        f"template groups (threshold={m['threshold']})"
    )
    print("-" * 72)
    print(f" Accuracy        : {m['accuracy'] * 100:6.2f}%")
    print(f" Precision       : {m['precision'] * 100:6.2f}%")
    print(f" Recall          : {m['recall'] * 100:6.2f}%")
    print(f" F1-Score        : {m['f1_score'] * 100:6.2f}%")
    print(f" ROC-AUC         : {m['roc_auc'] * 100:6.2f}%")
    print(f" Per-Fold F1     : {m['per_fold_f1']}")
    print("-" * 72)
    print(
        f" Out-of-Fold Confusion Matrix "
        f"({m['dataset_size']} held-out predictions):"
    )
    print(f"   True Negatives  (Legit -> Legit) : {cm['tn']:3d}")
    print(f"   False Positives (Legit -> Scam)  : {cm['fp']:3d}   "
          f"(FPR: {m['false_positive_rate'] * 100:.2f}%)")
    print(f"   False Negatives (Scam  -> Legit) : {cm['fn']:3d}")
    print(f"   True Positives  (Scam  -> Scam)  : {cm['tp']:3d}")
    print("-" * 72)
    scam_grams = ", ".join(
        f"{g['ngram']} (+{g['weight']})" for g in feats["top_scam_ngrams"][:6]
    )
    legit_grams = ", ".join(
        f"{g['ngram']} ({g['weight']})" for g in feats["top_legit_ngrams"][:6]
    )
    print(f" Top Scam N-Grams  : {scam_grams}")
    print(f" Top Legit N-Grams : {legit_grams}")
    print("-" * 72)
    print(" Held-Out Novel Conversational Scams (target >= 0.70):")
    for msg in NOVEL_SCAMS:
        r = predict_sms(msg)
        print(
            f"   [SCAM  {r['scam_probability']:.4f}] "
            f"signals={r['top_signals']} | {msg[:52]}..."
        )
    print("-" * 72)
    print(" Genuine Bank & Personal SMS (target < 0.45):")
    for msg in GENUINE:
        r = predict_sms(msg)
        print(
            f"   [LEGIT {r['scam_probability']:.4f}] "
            f"signals={r['top_signals']} | {msg[:52]}..."
        )
    print("=" * 72)


if __name__ == "__main__":
    main()
