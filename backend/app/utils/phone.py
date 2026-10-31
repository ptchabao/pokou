from typing import Optional

import phonenumbers


def normalize_e164(raw: str, default_region: str = "TG") -> Optional[str]:
    """Normalise un numéro WhatsApp brut (ex: "00228 90 00 00 00", "+228 90000000",
    "whatsapp:+22890000000") en E.164 strict (ex: "+22890000000").

    Les utilisateurs tapent souvent 00228 au lieu de +228 — default_region
    sert de repère quand le numéro n'a pas déjà un préfixe international
    explicite. Retourne None si le numéro n'est pas un numéro valide."""
    if not raw:
        return None
    cleaned = raw.strip()
    if cleaned.lower().startswith("whatsapp:"):
        cleaned = cleaned[len("whatsapp:"):]
    parsed = _parse(cleaned, default_region)
    # Passerelle WhatsApp : l'expéditeur arrive en chiffres nus, sans « + »
    # (« 2250700000000 », de « 2250700000000@c.us »). Lu avec la région par
    # défaut TG, un tel numéro n'est un numéro togolais valide que si son
    # indicatif EST 228 — d'où le rejet silencieux de TOUT numéro ivoirien
    # ou béninois, alors que Minou s'adresse justement à Abidjan et Cotonou
    # autant qu'à Lomé. Deuxième lecture, donc : chiffres nus = numéro déjà
    # international.
    #
    # Dans cet ordre et pas l'inverse : la première lecture reste la région
    # par défaut, pour qu'un numéro local (« 90112233 ») continue de
    # s'interpréter comme togolais et non comme un indicatif +90.
    if parsed is None and cleaned.isdigit():
        parsed = _parse(f"+{cleaned}", default_region)
    if parsed is None:
        return None
    return phonenumbers.format_number(parsed, phonenumbers.PhoneNumberFormat.E164)


def _parse(candidate: str, default_region: str):
    """Le numéro analysé s'il est VALIDE, None sinon — « analysable » ne
    suffit pas : phonenumbers accepte volontiers des suites de chiffres qui
    ne correspondent à aucun abonné."""
    try:
        parsed = phonenumbers.parse(candidate, default_region)
    except phonenumbers.NumberParseException:
        return None
    return parsed if phonenumbers.is_valid_number(parsed) else None


def country_for_e164(phone: str) -> Optional[str]:
    """Derives the ISO-2 region code (e.g. "TG", "BJ", "CI") from an
    already-normalized E.164 number — used to match Minou merchants against
    country-tagged KnowledgeBaseEntry rows without storing a separate
    country field on MinouUser (the phone number already carries it)."""
    try:
        parsed = phonenumbers.parse(phone, None)
    except phonenumbers.NumberParseException:
        return None
    return phonenumbers.region_code_for_number(parsed)
