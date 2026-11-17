"""Phase 5.5 ML layer: TF-IDF + Logistic Regression for India SMS.

Trained at server startup from dataset.json (< 0.2s).
The pipeline is intentionally explainable and calibrated:
  * predict_sms() returns scam_probability, model_version, and the top
    informative n-grams (tfidf_value * coef).
  * evaluate_model() runs GroupKFold cross-validation grouped by template
    category so near-similar templates never leak across train/val folds,
    evaluated at the app's actual Amber trigger threshold (0.65).

Run standalone:  python ml_model.py
"""

import json
from pathlib import Path

import numpy as np
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (
    accuracy_score,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
    roc_auc_score,
)
from sklearn.model_selection import GroupKFold

MODEL_VERSION = "tfidf-logreg-v3"
AMBER_THRESHOLD = 0.65
RED_THRESHOLD = 0.82
DATASET_FILE = Path(__file__).parent / "dataset.json"

_vectorizer = TfidfVectorizer(
    ngram_range=(1, 2),
    lowercase=True,
    sublinear_tf=True,
)
_classifier = LogisticRegression(
    class_weight="balanced",
    C=5.0,
    max_iter=500,
)

_feature_names: list[str] | None = None

# Signal hygiene: skip stopwords and pure number tokens so explanations
# read clearly for parents.
_STOPWORDS = frozenset({
    "the", "to", "and", "of", "is", "in", "on", "for", "a", "an", "or",
    "at", "by", "with", "your", "you", "this", "that", "my", "me", "we",
    "it", "as", "be", "from", "will", "can", "has", "have", "had", "not",
    "no", "if", "so", "but", "his", "her", "he", "she", "they", "them",
    "our", "us", "are", "was", "were", "been", "than", "then", "there",
    "here", "when", "what", "which", "who", "how", "all", "any", "out",
    "up", "off", "got", "let", "just", "also", "more", "most", "some",
    "such", "only", "same", "too", "very", "because", "do", "does",
    "did", "am", "i", "its", "into", "over", "after", "before", "about",
})


def _informative(gram: str) -> bool:
    """Every word must be >= 3 letters, not a stopword, contain a letter."""
    return all(
        len(w) >= 3 and w not in _STOPWORDS and any(c.isalpha() for c in w)
        for w in gram.split()
    )


def _load_dataset() -> tuple[int, list[str], list[int], list[str]]:
    data = json.loads(DATASET_FILE.read_text(encoding="utf-8"))
    version = int(data.get("version", 1))
    texts = [ex["text"] for ex in data["examples"]]
    labels = [int(ex["label"]) for ex in data["examples"]]
    groups = [
        str(ex.get("group", f"ungrouped_{i}"))
        for i, ex in enumerate(data["examples"])
    ]
    return version, texts, labels, groups


def train() -> None:
    """Fit the pipeline on dataset.json. Idempotent, called at startup."""
    global _feature_names
    _, texts, labels, _ = _load_dataset()
    X = _vectorizer.fit_transform(texts)
    _classifier.fit(X, labels)
    _feature_names = list(_vectorizer.get_feature_names_out())


def predict_sms(text: str) -> dict:
    """Classify one SMS.

    Returns:
        {
          "scam_probability": 0.8421,     # P(scam), 4 decimals
          "top_signals": ["pension", "pending", "digit"],
          "model_version": "tfidf-logreg-v3",
        }
    """
    if _feature_names is None:
        train()

    X = _vectorizer.transform([text])
    proba = float(_classifier.predict_proba(X)[0][1])

    # Explainability: per-ngram contribution = tfidf_value * coefficient.
    row = X.toarray()[0]
    coefs = _classifier.coef_[0]
    positive = [
        i
        for i in range(len(row))
        if row[i] > 0 and coefs[i] > 0 and _informative(_feature_names[i])
    ]
    top = sorted(positive, key=lambda i: row[i] * coefs[i], reverse=True)[:3]
    top_signals = [_feature_names[i] for i in top]

    return {
        "scam_probability": round(proba, 4),
        "top_signals": top_signals,
        "model_version": MODEL_VERSION,
    }


def evaluate_model(
    k: int = 5,
    threshold: float = AMBER_THRESHOLD,
) -> dict:
    """Phase 5.5: GroupKFold cross-validation metrics on dataset.json.

    Holds out entire template groups per fold so there is zero template
    leakage across training and validation, and evaluates at the app's
    actual ML trigger threshold (default 0.65).
    """
    dataset_version, texts, labels, groups = _load_dataset()
    y = np.array(labels, dtype=int)
    oof_preds = np.zeros_like(y)
    oof_probas = np.zeros(len(y), dtype=float)
    fold_f1s: list[float] = []

    gkf = GroupKFold(n_splits=k)
    for train_idx, val_idx in gkf.split(texts, y, groups):
        vec = TfidfVectorizer(
            ngram_range=(1, 2),
            lowercase=True,
            sublinear_tf=True,
        )
        clf = LogisticRegression(
            class_weight="balanced",
            C=5.0,
            max_iter=500,
        )
        train_texts = [texts[i] for i in train_idx]
        val_texts = [texts[i] for i in val_idx]
        X_train = vec.fit_transform(train_texts)
        clf.fit(X_train, y[train_idx])

        X_val = vec.transform(val_texts)
        probas = clf.predict_proba(X_val)[:, 1]
        preds = (probas >= threshold).astype(int)

        oof_probas[val_idx] = probas
        oof_preds[val_idx] = preds
        fold_f1s.append(
            round(float(f1_score(y[val_idx], preds, zero_division=0)), 4)
        )

    tn, fp, fn, tp = confusion_matrix(y, oof_preds).ravel()
    fpr = float(fp / (fp + tn)) if (fp + tn) > 0 else 0.0

    return {
        "model_version": MODEL_VERSION,
        "dataset_version": dataset_version,
        "dataset_size": len(texts),
        "scam_count": int(y.sum()),
        "legit_count": int(len(y) - y.sum()),
        "group_count": len(set(groups)),
        "cv_strategy": f"GroupKFold({k})",
        "cv_folds": k,
        "threshold": threshold,
        "accuracy": round(float(accuracy_score(y, oof_preds)), 4),
        "precision": round(float(precision_score(y, oof_preds)), 4),
        "recall": round(float(recall_score(y, oof_preds)), 4),
        "f1_score": round(float(f1_score(y, oof_preds)), 4),
        "roc_auc": round(float(roc_auc_score(y, oof_probas)), 4),
        "false_positive_rate": round(fpr, 4),
        "confusion_matrix": {
            "tn": int(tn),
            "fp": int(fp),
            "fn": int(fn),
            "tp": int(tp),
        },
        "per_fold_f1": fold_f1s,
    }


def top_model_features(n: int = 10) -> dict:
    """Return the globally strongest scam and legit informative n-grams."""
    if _feature_names is None:
        train()
    coefs = _classifier.coef_[0]
    informative_idx = [
        i for i, name in enumerate(_feature_names) if _informative(name)
    ]
    top_scam = sorted(informative_idx, key=lambda i: coefs[i], reverse=True)[:n]
    top_legit = sorted(informative_idx, key=lambda i: coefs[i])[:n]
    return {
        "top_scam_ngrams": [
            {"ngram": _feature_names[i], "weight": round(float(coefs[i]), 3)}
            for i in top_scam
        ],
        "top_legit_ngrams": [
            {"ngram": _feature_names[i], "weight": round(float(coefs[i]), 3)}
            for i in top_legit
        ],
    }


# Train at import time = server startup (~0.02s).
train()


if __name__ == "__main__":
    import time

    t0 = time.perf_counter()
    train()
    elapsed = time.perf_counter() - t0
    metrics = evaluate_model(k=5)
    print(
        f"trained {MODEL_VERSION} on {metrics['dataset_size']} examples "
        f"({metrics['group_count']} groups) in {elapsed:.3f}s | "
        f"{metrics['cv_strategy']} @ {metrics['threshold']}: "
        f"F1={metrics['f1_score']:.4f} (P={metrics['precision']:.4f}, "
        f"R={metrics['recall']:.4f}, FPR={metrics['false_positive_rate']:.4f}, "
        f"AUC={metrics['roc_auc']:.4f})"
    )
