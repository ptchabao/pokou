"""La réponse à un sondage reste modifiable 15 minutes, puis devient définitive.

Changer d'avis sans limite faisait du sondage un jeu : on revotait au gré
des résultats, et la décision qu'il devait trancher ne l'était jamais. La
fenêtre court à partir du PREMIER vote de la personne, et un retrait ne la
rouvre pas (voir models/groups.py::PollVoteWindow).

C'est le SERVEUR qui l'impose : l'horloge d'un téléphone se règle à la main,
l'application ne fait qu'afficher le temps qui reste.
"""
from __future__ import annotations

from datetime import datetime, timedelta
from typing import Iterable, Optional

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models import PollVoteWindow

#: La durée pendant laquelle une réponse peut encore changer.
POLL_EDIT_WINDOW = timedelta(minutes=15)
POLL_EDIT_WINDOW_SECONDS = int(POLL_EDIT_WINDOW.total_seconds())

#: Le texte du refus — affiché tel quel par l'application.
FINAL_ANSWER_DETAIL = "Ta réponse est définitive : elle ne peut plus être modifiée"


def window_of(db: Session, poll_key: str, user_id: int) -> Optional[PollVoteWindow]:
    return (
        db.query(PollVoteWindow)
        .filter(PollVoteWindow.poll_key == poll_key, PollVoteWindow.user_id == user_id)
        .first()
    )


def locks_at(window: Optional[PollVoteWindow]) -> Optional[datetime]:
    return window.first_voted_at + POLL_EDIT_WINDOW if window is not None else None


def enforce(
    db: Session,
    poll_key: str,
    user_id: int,
    *,
    casting: bool,
    now: Optional[datetime] = None,
) -> Optional[PollVoteWindow]:
    """Refuse (409) un changement hors fenêtre ; ouvre la fenêtre au premier
    vote. `casting` : la requête pose au moins un choix (un retrait pur n'ouvre
    pas de fenêtre — on ne commence pas le compte à rebours de quelqu'un qui
    n'a jamais voté)."""
    now = now or datetime.utcnow()
    window = window_of(db, poll_key, user_id)
    if window is not None:
        if now >= window.first_voted_at + POLL_EDIT_WINDOW:
            raise HTTPException(status_code=409, detail=FINAL_ANSWER_DETAIL)
        return window
    if not casting:
        return None
    window = PollVoteWindow(poll_key=poll_key, user_id=user_id, first_voted_at=now)
    db.add(window)
    db.flush()
    return window


def serialize_for(windows: Iterable[PollVoteWindow], viewer_id: Optional[int]) -> dict:
    """Ce que le LECTEUR doit savoir de sa propre fenêtre : jusqu'à quand il
    peut encore changer sa réponse (`my_locks_at`, nul s'il n'a jamais voté),
    et la durée de la règle, pour l'afficher sans la coder en dur."""
    mine = next((w for w in windows if viewer_id is not None and w.user_id == viewer_id), None)
    when = locks_at(mine)
    return {
        "edit_window_seconds": POLL_EDIT_WINDOW_SECONDS,
        "my_locks_at": when.isoformat() if when is not None else None,
    }
