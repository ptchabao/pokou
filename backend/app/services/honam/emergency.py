"""Les numéros d'urgence, pays par pays (section « Urgences » de Honam).

La référence est un fichier de données versionné :

- `app/data/emergency_numbers.csv` : la liste de l'équipe pour tous les pays
  d'Afrique (copie du tableur « Pokou — Numéros d'urgence », mise à jour en
  remplaçant le fichier) ;
- `app/data/emergency_numbers_extra.csv` : les pays hors de cette liste dont
  on a besoin (la France, pays de test), au même format.

Une valeur comme « 170 (ou 110, 111) » donne un numéro principal (170) et
des alternatives (110, 111) ; « 10 111 (10 112 depuis un mobile) » donne
10111, l'alternative 10112 et la précision « depuis un mobile ».

La console garde la main : `emergency_numbers` de la configuration du pays
(app/core/countries.py) remplace le numéro principal d'un service.
"""
import csv
import re
from functools import lru_cache
from pathlib import Path
from typing import Any, Optional

from sqlalchemy.orm import Session

from app.core.countries import country_config

_DATA = Path(__file__).resolve().parents[2] / "data"
_FILES = ("emergency_numbers.csv", "emergency_numbers_extra.csv")

#: Les colonnes du fichier et la clé que l'application connaît.
SERVICE_COLUMNS = (
    ("police", "Police"),
    ("pompiers", "Pompiers"),
    ("samu", "SAMU / ambulance"),
    ("gendarmerie", "Gendarmerie"),
    ("unique", "Numéro unique"),
)
SERVICE_KEYS = tuple(key for key, _ in SERVICE_COLUMNS)
#: Les anciennes versions de l'app n'affichent que ces trois-là.
LEGACY_KEYS = ("police", "pompiers", "samu")

_RELIABILITY = {"elevee": "high", "moyenne": "medium", "faible": "low"}
_NUMBER = re.compile(r"\+?\d[\d ]*\d|\d")


def _ascii(value: str) -> str:
    import unicodedata

    return unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode().strip().lower()


def _dial(value: str) -> str:
    return value.replace(" ", "")


def parse_number(raw: Optional[str]) -> Optional[dict[str, Any]]:
    """« 170 (ou 110, 111) » → {number: "170", alternatives: ["110", "111"]}.

    Le premier numéro est le principal ; ceux entre parenthèses sont des
    alternatives ; les mots qui restent entre parenthèses (« depuis un
    mobile », « privé ») sont une précision.
    """
    # L'apostrophe de tête vient du tableur (« '+269 … » pour garder le +).
    text = (raw or "").strip().lstrip("'").strip()
    if not text:
        return None
    main, _, rest = text.partition("(")
    found = _NUMBER.findall(main)
    if not found:
        return None
    number = _dial(found[0])
    alternatives = [_dial(n) for n in found[1:]]
    note = None
    if rest:
        inside = rest.rsplit(")", 1)[0]
        alternatives += [_dial(n) for n in _NUMBER.findall(inside)]
        words = _NUMBER.sub(" ", inside)
        words = re.sub(r"^\s*ou\b|\bou\b", " ", words)
        words = " ".join(words.replace(",", " ").split()).strip(" ,;:-")
        note = words or None
    alternatives = [a for i, a in enumerate(alternatives) if a != number and a not in alternatives[:i]]
    return {"number": number, "alternatives": alternatives, "note": note}


def parse_others(raw: Optional[str]) -> list[dict[str, Any]]:
    """« Protection civile (ANPC) : 170 · Police : 1244 » → une entrée par
    service, avec son libellé tel que la liste l'écrit."""
    items = []
    for part in (raw or "").split("·"):
        label, sep, value = part.rpartition(" : ")
        if not sep:
            label, sep, value = part.rpartition(":")
        parsed = parse_number(value) if sep else None
        if parsed is None or not label.strip():
            continue
        items.append({"label": label.strip(), **parsed})
    return items


@lru_cache(maxsize=1)
def _table() -> dict[str, dict[str, Any]]:
    table: dict[str, dict[str, Any]] = {}
    for name in _FILES:
        path = _DATA / name
        if not path.exists():
            continue
        with path.open(encoding="utf-8-sig", newline="") as handle:
            for row in csv.DictReader(handle):
                code = (row.get("Code ISO") or "").strip().upper()
                if len(code) != 2 or code in table:
                    continue
                reliability_label = (row.get("Fiabilité") or "").strip() or None
                table[code] = {
                    "country": code,
                    "country_name": (row.get("Pays") or "").strip() or None,
                    "services": {
                        key: parsed
                        for key, column in SERVICE_COLUMNS
                        if (parsed := parse_number(row.get(column))) is not None
                    },
                    "others": parse_others(row.get("Autres services d'urgence")),
                    "reliability": _RELIABILITY.get(_ascii(reliability_label or "")),
                    "reliability_label": reliability_label,
                    "remarks": (row.get("Remarques") or "").strip() or None,
                    "verified_on": (row.get("Vérifié le") or "").strip() or None,
                }
    return table


def known_countries() -> list[str]:
    return sorted(_table())


def emergency_for(db: Session, country: Optional[str]) -> dict[str, Any]:
    """Les numéros d'un pays, prêts à afficher : la liste de référence, puis
    les surcharges de la console. Un pays inconnu n'a aucun service."""
    code = (country or "").upper() or None
    reference = _table().get(code or "", {})
    services = {key: dict(value) for key, value in reference.get("services", {}).items()}
    overrides = country_config(db, code).get("emergency_numbers") or {} if code else {}
    for key, value in overrides.items():
        if key not in SERVICE_KEYS or not value:
            continue
        previous = services.get(key)
        known = ([previous["number"], *previous["alternatives"]] if previous else [])
        services[key] = {
            "number": str(value),
            "alternatives": [n for n in known if n != str(value)],
            "note": None,
        }
    return {
        "country": code,
        "country_name": reference.get("country_name"),
        "services": [{"key": key, **services[key]} for key in SERVICE_KEYS if key in services],
        "others": reference.get("others", []),
        "reliability": reference.get("reliability"),
        "reliability_label": reference.get("reliability_label"),
        "remarks": reference.get("remarks"),
        "verified_on": reference.get("verified_on"),
    }


def legacy_numbers(emergency: dict[str, Any]) -> dict[str, str]:
    """La forme d'avant (`{"police": "117", …}`), pour les versions de l'app
    qui ne connaissent que police, pompiers et SAMU."""
    return {s["key"]: s["number"] for s in emergency["services"] if s["key"] in LEGACY_KEYS}
