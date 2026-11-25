"""Les officines de démonstration de Honam (testeurs).

    python -m scripts.honam_demo_pharmacies status   # les lister
    python -m scripts.honam_demo_pharmacies remove   # les supprimer

Pour seulement les CACHER, sans rien supprimer : console → Pays → décocher
« Officines de démonstration » pour le pays concerné.
"""
import sys

from app import models  # noqa: F401
from app.core.database import SessionLocal
from app.models import Pharmacy
from app.services.honam.demo import remove_demo_pharmacies


def main(argv: list[str]) -> int:
    action = argv[1] if len(argv) > 1 else "status"
    db = SessionLocal()
    try:
        if action == "remove":
            result = remove_demo_pharmacies(db)
            print(f"Officines de démonstration : {result['removed']} supprimée(s), "
                  f"{result['excluded']} exclue(s) (elles avaient des commandes).")
            return 0
        if action == "status":
            rows = db.query(Pharmacy).filter(Pharmacy.is_demo.is_(True)).all()
            for p in rows:
                print(f"#{p.id} {p.country} {p.name} — {p.status}")
            print(f"{len(rows)} officine(s) de démonstration.")
            return 0
        print(__doc__)
        return 2
    finally:
        db.close()


if __name__ == "__main__":
    sys.exit(main(sys.argv))
