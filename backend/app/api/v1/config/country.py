"""La configuration du pays de la personne connectée (NAV-01).

L'application la lit au démarrage pour savoir quels onglets afficher : un
module non lancé dans le pays n'apparaît pas, et la décision se prend ici,
pas dans le binaire.
"""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.countries import country_config, country_of_phone
from app.core.database import get_db
from app.core.security import get_current_user
from app.models import User

router = APIRouter(prefix="/config", tags=["Pokou configuration"])


@router.get("/country")
def my_country(current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == current_user["user_id"]).first()
    return country_config(db, country_of_phone(user.phone if user else None))
