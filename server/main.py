"""Scam Shield rules + ML server (Phase 4 + Phase 5 + Phase 6).

GET  /patterns  -> latest rules JSON. To push new rules to installed
                   apps, edit patterns.json (bump "version", add rules) -
                   the file is read on every request, no restart needed.
POST /predict   -> Phase 5/6 ML verdict for one SMS (TF-IDF + LogReg,
                   trained from dataset.json at startup, < 0.2s).
GET  /metrics   -> Phase 6 Stratified 5-Fold CV report (Precision,
                   Recall, F1, ROC-AUC, Confusion Matrix).

Run:  uvicorn main:app --port 8000
"""

import json
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

import ml_model

app = FastAPI(title="Scam Shield Rules & ML Server")

# Dev safeguard: allow every origin so localhost vs 127.0.0.1 (or a
# different Flutter port) never blocks the browser fetch.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

RULES_FILE = Path(__file__).parent / "patterns.json"


class PredictRequest(BaseModel):
    """Phase 5 request body: {"text": "..."}"""

    text: str


@app.get("/patterns")
def get_patterns() -> dict:
    """Latest rules: {"version": N, "patterns": [...]}"""
    return json.loads(RULES_FILE.read_text(encoding="utf-8"))


@app.post("/predict")
def predict(req: PredictRequest) -> dict:
    """Phase 5/6: ML verdict for one SMS.

    Response: {"scam_probability": 0.84, "top_signals": [...],
               "model_version": "tfidf-logreg-v2"}
    """
    if not req.text.strip():
        raise HTTPException(status_code=400, detail="text is empty")
    return ml_model.predict_sms(req.text)


@app.get("/metrics")
def get_metrics() -> dict:
    """Phase 6: Stratified 5-Fold Cross-Validation evaluation metrics."""
    return ml_model.evaluate_model(k=5)
