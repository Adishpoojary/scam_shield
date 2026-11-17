# Scam Shield — Project Status (Ready for Mentor Handoff ✅)

## Architecture Summary
**Scam Shield** is an offline-first, parent-friendly hybrid scam detector built for Indian families.

* **Layer 1 — On-Device Dart Rule Engine (`scam_shield_engine` & `scam_shield/lib/engine/`)**:
  * Runs synchronously on-device (`<1ms`) with 4 signal categories (`urgency` +15, `authority_or_lure` +20, `action_trap` +30, `suspicious_link` +40), category score capping, `1.5×` multi-category combo multiplier, word-boundary phrase matching, defensive OTP guards, and a smart URL classifier with 10 trusted Indian domains.
  * Supports **OTA rule hot-swap** (`GET /patterns`, currently **v6** with Hinglish scam phrases: *"aapka khata band ho jayega"*, *"bijli bill baki hai"*, *"turant update kare"*, *"pm kisan yojana bonus"*, *"aadhaar pan link kare"*).
* **Two-Tier Privacy Gate (`HistoryStore.checkMessage`)**:
  * If Layer 1 already scores `>= 50` (Likely Scam) OR a bank safety lock triggers (`do not share` / trusted bank domain with zero rule hits), **`POST /predict` is never called** — zero network leakage for known scams and genuine bank OTPs.
  * Configurable backend URL via `--dart-define=API_BASE_URL=...` (defaults to `http://localhost:8000`).
* **Layer 2 — Explainable Smart Check (`server/ml_model.py`, `tfidf-logreg-v3`)**:
  * `TfidfVectorizer(1–2 n-grams, sublinear_tf=True)` + `LogisticRegression(class_weight="balanced", C=5.0)` trained on **203 de-duplicated, grouped India SMS examples** (`dataset.json` v3).
  * Calibrated blending thresholds: **`0.65`** (`+25` pts Amber) and **`0.82`** (`round(P × 65)` pts Red), rendered in plain English (*"⚠️ Wording looks similar to known scam messages"*).

---

## Test Coverage & Analyzer Status

| Suite | Scope | Status |
| :--- | :--- | :--- |
| **Dart Engine (`scam_shield_engine`)** | Scoring math, combo multiplier, word boundaries, OTP guards, URL classifier, 10-message benchmark | `19/19` passing |
| **Flutter App (`scam_shield`)** | UI flows, clipboard, persistence, OTA hot-swap, privacy gate, `0.65`/`0.82` thresholds, Dark Emerald `18px+` UI | `14/14` passing |
| **Flutter Static Analysis** | `flutter analyze` across `lib/` and `test/` | `0` issues |
| **Backend ML (`server/test_ml.py`)** | Held-out conversational scams, genuine SMS, zero leakage check, `GroupKFold(5)` FPR & precision gates | `5/5` passing |

---

## ML Model Performance (`tfidf-logreg-v3`, Honest Leak-Free Evaluation)

Run anytime with:
```powershell
cd D:\Projects\scam_shield\server
python evaluate.py
```

* **Dataset**: `v3` — **203 de-duplicated examples** (`98` scam / `105` legit) across **21 template groups** (English + Hinglish + everyday Indian hard negatives).
* **Validation**: **`GroupKFold(5)`** at the app's Amber threshold (**`0.65`**) — entire template groups held out per fold, zero template leakage.
* **False Positive Rate (FPR)**: **`1.90%`** (`2 / 105` legitimate messages flagged out-of-fold)
* **Precision**: **`95.56%`**
* **Recall**: **`43.88%`** *(on top of Layer 1 rules)*
* **F1-Score**: **`60.14%`**
* **ROC-AUC**: **`90.75%`**
* **Out-of-Fold Confusion Matrix**: `TN = 103`, `FP = 2`, `FN = 55`, `TP = 43`
