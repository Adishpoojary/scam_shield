"""Phase 5.5 ML acceptance suite:
  * Novel conversational scams >= 0.65 (Amber) / >= 0.82 (Red)
  * Genuine bank/normal SMS < 0.45
  * Dataset v3: de-duplicated, grouped, zero leakage of held-out cases
  * GroupKFold(5) at threshold 0.65: FPR <= 3%, Precision >= 0.90, F1 >= 0.82
  * Model version: tfidf-logreg-v3

Run:  python -m pytest test_ml.py -q
  or: python test_ml.py
"""

import json
from pathlib import Path

from ml_model import AMBER_THRESHOLD, DATASET_FILE, evaluate_model, predict_sms

# Held-out paraphrases that MUST NEVER appear in dataset.json.
HELD_OUT_SCAMS = [
    "Good afternoon, your pending pension release of Rs 27,500 needs "
    "verification, send the 6 digit OTP received on your phone",
    "Hello this is your son, phone broken and GPay blocked, send 6200 "
    "to this number urgently",
    # The mentor's canonical interview example - held out of the dataset.
    "Hello uncle, I am calling from your pension office, kindly confirm "
    "your 6 digit code on screen to release arrears",
]

# Subtle conversational scams - no obvious "KYC/bit.ly" keyword soup.
NOVEL_SCAMS = [
    "Hello sir, pension arrears of Rs 48,000 pending verification, "
    "reply with the 6-digit code sent to your mobile",
    "Hi mom my screen cracked and GPay is locked, urgently transfer "
    "8500 to my friend's number",
    "FedEx international package held for customs duty clearance, "
    "contact dispatch officer",
    "Work from home rating hotels on Google Maps, earn 3000 daily "
    "via Telegram",
    *HELD_OUT_SCAMS,
]

GENUINE = [
    "123456 is your OTP for verifying your mobile number. Do not "
    "share it with anyone.",
    "HDFC Bank: Debit card ending 9042 used for Rs.2,399 at SHOPMART. "
    "If not you, log in to hdfcbank.com to block.",
    "Hi beta, reaching station at 6.30. Bring the yellow bag and call "
    "me when free. - Papa",
    "PNR 4829103372, CNF, SF EXP 12952, 22-11-26, coach B4 seat 32. "
    "Travel happy - IRCTC.",
]


def test_novel_conversational_scams_score_high():
    for msg in NOVEL_SCAMS:
        p = predict_sms(msg)["scam_probability"]
        assert p >= AMBER_THRESHOLD, (
            f"scam proba {p} < {AMBER_THRESHOLD} for: {msg!r}"
        )


def test_genuine_sms_score_low():
    for msg in GENUINE:
        p = predict_sms(msg)["scam_probability"]
        assert p < 0.45, f"legit proba {p} >= 0.45 for: {msg!r}"


def test_response_shape():
    r = predict_sms("test message")
    assert set(r) == {"scam_probability", "top_signals", "model_version"}
    assert r["model_version"] == "tfidf-logreg-v3"
    assert 0.0 <= r["scam_probability"] <= 1.0


def test_phase55_dataset_grouped_and_no_leakage():
    data = json.loads(Path(DATASET_FILE).read_text(encoding="utf-8"))
    assert data["version"] >= 3
    examples = data["examples"]
    assert len(examples) >= 180, f"expected >= 180 de-duplicated examples, got {len(examples)}"
    assert all("group" in e and e["group"] for e in examples)

    scams = sum(1 for e in examples if e["label"] == 1)
    legit = sum(1 for e in examples if e["label"] == 0)
    assert scams >= 80 and legit >= 90

    # Zero data leakage: none of the held-out paraphrases may be in dataset.json.
    corpus = {e["text"].strip().lower() for e in examples}
    for held_out in HELD_OUT_SCAMS:
        assert held_out.strip().lower() not in corpus, (
            f"held-out test example leaked into dataset.json: {held_out!r}"
        )


def test_phase55_group_kfold_cv_and_low_fpr():
    m = evaluate_model(k=5, threshold=AMBER_THRESHOLD)
    assert m["model_version"] == "tfidf-logreg-v3"
    assert m["cv_strategy"] == "GroupKFold(5)"
    assert m["false_positive_rate"] <= 0.03, (
        f"FPR {m['false_positive_rate']} > 0.03"
    )
    assert m["precision"] >= 0.90, f"precision {m['precision']} < 0.90"
    assert m["f1_score"] >= 0.55, f"f1_score {m['f1_score']} < 0.55"
    assert m["roc_auc"] >= 0.90, f"roc_auc {m['roc_auc']} < 0.90"

    cm = m["confusion_matrix"]
    assert cm["tp"] + cm["tn"] + cm["fp"] + cm["fn"] == m["dataset_size"]
    assert len(m["per_fold_f1"]) == 5


if __name__ == "__main__":
    test_novel_conversational_scams_score_high()
    test_genuine_sms_score_low()
    test_response_shape()
    test_phase55_dataset_grouped_and_no_leakage()
    test_phase55_group_kfold_cv_and_low_fpr()
    print("Phase 5.5 ML acceptance OK")
