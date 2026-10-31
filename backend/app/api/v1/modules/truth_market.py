"""Truth Market — poser une question payée, y répondre ou refuser.

**La revente anonyme du concept initial n'est pas implémentée**, et ce n'est
pas un oubli : quelqu'un répond à UN acheteur, pas au public. Redistribuer sa
confession en ferait un outil de chantage hébergé par Pokou, et la première
plainte porterait sur nous.
"""
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models import TruthQuestion, User
from app.api.v1.modules.common import open_payment, payment_json, require_module
from app.core.security import get_current_user

router = APIRouter(prefix="/truth", tags=["Pokou Truth Market"])

MODULE_SLUG = "truth_market"

MIN_AMOUNT = 200
MAX_AMOUNT = 20000
#: Au-delà, la question s'éteint. Sans échéance, l'argent resterait bloqué
#: indéfiniment sur un silence, et l'acheteur n'aurait aucun recours.
QUESTION_TTL = timedelta(days=7)


class QuestionCreate(BaseModel):
    target_id: int
    question: str = Field(..., min_length=3, max_length=280)
    amount: int = Field(..., ge=MIN_AMOUNT, le=MAX_AMOUNT)


class AnswerCreate(BaseModel):
    answer: str = Field(..., min_length=1, max_length=2000)


def _serialize(q: TruthQuestion, *, viewer_id: int, names: dict) -> dict:
    is_asker = q.asker_id == viewer_id
    return {
        "id": q.id,
        "question": q.question,
        "amount": q.amount,
        "status": q.status,
        "created_at": q.created_at.isoformat(),
        "expires_at": q.expires_at.isoformat(),
        # L'ACHETEUR reste anonyme pour celui qui répond, et c'est ce qui
        # rend la question posable. Le nommer transformerait chaque question
        # en confrontation, et personne n'en poserait.
        "asker_name": names.get(q.asker_id) if is_asker else None,
        "target_name": names.get(q.target_id) if is_asker else None,
        "is_mine": is_asker,
        # La réponse n'est lisible que par celui qui l'a payée, et par celui
        # qui l'a écrite.
        "answer": q.answer if q.status == "ANSWERED" else None,
        "answered_at": q.answered_at.isoformat() if q.answered_at else None,
    }


def _names(db: Session, questions: list[TruthQuestion]) -> dict:
    ids = {q.asker_id for q in questions} | {q.target_id for q in questions}
    return {
        u.id: (u.full_name or u.phone or "Utilisateur")
        for u in db.query(User).filter(User.id.in_(ids))
    } if ids else {}


@router.post("")
async def ask(
    payload: QuestionCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Ouvre une question. Elle n'est POSÉE qu'une fois payée.

    Sans ce séquencement, on pourrait inonder quelqu'un de questions
    gratuites — c'est le prix qui limite le volume, et c'est aussi ce qui
    rend l'attention de celui qui répond réellement demandée.
    """
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    if payload.target_id == user_id:
        raise HTTPException(status_code=400, detail="Destinataire invalide")
    if not db.query(User.id).filter(User.id == payload.target_id).first():
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")

    now = datetime.utcnow()
    question = TruthQuestion(
        asker_id=user_id,
        target_id=payload.target_id,
        question=payload.question.strip(),
        amount=payload.amount,
        status="DRAFT",
        expires_at=now + QUESTION_TTL,
    )
    db.add(question)
    db.flush()

    payment = open_payment(
        db, user_id,
        kind="TRUTH_QUESTION",
        amount=payload.amount,
        description="Truth Market — une question",
        metadata={"module": MODULE_SLUG, "question_id": question.id},
    )
    question.payment_id = payment.id
    db.commit()
    return {"question_id": question.id, **payment_json(payment)}


@router.get("/received")
async def received(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Les questions qui m'attendent. Seulement celles qui sont PAYÉES."""
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    now = datetime.utcnow()
    rows = (
        db.query(TruthQuestion)
        .filter(
            TruthQuestion.target_id == user_id,
            TruthQuestion.status == "PENDING",
            TruthQuestion.expires_at > now,
        )
        .order_by(TruthQuestion.amount.desc(), TruthQuestion.created_at)
        .all()
    )
    return {"items": [_serialize(q, viewer_id=user_id, names=_names(db, rows)) for q in rows]}


@router.get("/sent")
async def sent(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    rows = (
        db.query(TruthQuestion)
        .filter(TruthQuestion.asker_id == user_id, TruthQuestion.status != "DRAFT")
        .order_by(TruthQuestion.created_at.desc())
        .limit(50)
        .all()
    )
    names = _names(db, rows)
    return {"items": [_serialize(q, viewer_id=user_id, names=names) for q in rows]}


def _own_pending(db: Session, question_id: int, user_id: int) -> TruthQuestion:
    question = (
        db.query(TruthQuestion)
        .filter(TruthQuestion.id == question_id, TruthQuestion.target_id == user_id)
        .first()
    )
    if question is None or question.status != "PENDING":
        raise HTTPException(status_code=404, detail="Question introuvable")
    if question.expires_at <= datetime.utcnow():
        raise HTTPException(status_code=409, detail="Cette question a expiré")
    return question


@router.post("/{question_id}/answer")
async def answer(
    question_id: int,
    payload: AnswerCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    question = _own_pending(db, question_id, user_id)

    question.answer = payload.answer.strip()
    question.status = "ANSWERED"
    question.answered_at = datetime.utcnow()
    db.commit()
    return {"id": question.id, "status": question.status}


@router.post("/{question_id}/decline")
async def decline(
    question_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Refuser est TOUJOURS possible, et ne rapporte rien.

    L'argent n'est versé qu'à la réponse. Payer à la question donnerait de
    l'argent pour un silence, et ferait du refus un gain — ce qui viderait
    le module de son sens en une semaine.
    """
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    question = _own_pending(db, question_id, user_id)
    question.status = "DECLINED"
    db.commit()
    return {"id": question.id, "status": question.status}


def apply_confirmed_payment(db: Session, payment) -> dict | None:
    """La question devient POSÉE une fois payée."""
    question_id = (payment.metadata_json or {}).get("question_id")
    if not question_id:
        return None
    question = db.query(TruthQuestion).filter(TruthQuestion.id == int(question_id)).first()
    if question is None or question.status != "DRAFT":
        return None
    question.status = "PENDING"
    return {"question_id": question.id, "status": question.status}
