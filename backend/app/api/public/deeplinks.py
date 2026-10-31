"""Les pages d'atterrissage des liens d'invitation Pokou.

Le symptôme : « les liens profonds mènent souvent à une page introuvable
avant de parfois mener au bon endroit ». La cause n'était pas dans la
vérification de domaine — elle marche — mais dans le fait que **rien ne
servait ces URL**.

`assetlinks.json` dit à Android que Pokou a le droit d'ouvrir
`https://pok.app/invite/…`. Il ne rend pas cette adresse existante
pour autant. Dès qu'un lien n'est PAS intercepté par l'application — parce
qu'elle n'est pas installée, parce qu'on a choisi « ouvrir dans le
navigateur » une fois, ou parce que le lien est ouvert dans le navigateur
intégré de WhatsApp, qui ne déclenche pas les App Links — le navigateur va
vraiment chercher la page. Elle n'existait pas : 404.

Et le « avant de parfois mener au bon endroit » s'explique aussi : le
navigateur affiche l'erreur, puis Android résout le lien et bascule sur
l'application. L'utilisateur voit passer une page introuvable au milieu.

Ces routes sont enregistrées SANS le préfixe `/api/v1` (voir `main.py`) :
ce sont des adresses publiques destinées à des humains et à leur navigateur,
pas des points d'API.

**Aucun contenu privé n'est révélé ici.** La page ne dit pas le nom du
groupe, ni qui invite, ni combien ils sont : le code d'invitation circule
dans des conversations, il finit dans des historiques de navigation et des
aperçus de lien. Elle dit seulement de quelle NATURE est l'invitation, et
comment l'ouvrir.
"""
import html as html_lib
from typing import Optional

from fastapi import APIRouter, Depends
from fastapi.responses import HTMLResponse
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models import Channel, ChannelPost

router = APIRouter(tags=["liens d'invitation"])

PLAY_STORE_URL = "https://play.google.com/store/apps/details?id=com.pokou.pokou"
ANDROID_PACKAGE = "com.pokou.pokou"
DEFAULT_OG_IMAGE = "https://pok.app/static/pokou-banner.png"

_KIND_LABELS = {
    "bot": ("un bot", "Discutez avec ce bot sur Pokou"),
    "group": ("une invitation à un groupe", "Rejoignez la conversation"),
    "community": ("une invitation à une communauté", "Rejoignez la communauté"),
    "channel": ("une invitation à une chaîne", "Suivez cette chaîne"),
    "unknown": ("une invitation Pokou", "Ouvrez-la dans Pokou"),
}


def _intent_url(path: str) -> str:
    """Le lien `intent://` d'Android.

    Il fait ce qu'un lien `https` ne peut pas faire depuis une page déjà
    ouverte : forcer l'ouverture de CETTE application. Et `browser_fallback_url`
    envoie vers le Play Store quand elle n'est pas installée — ce qui est
    exactement ce qu'on veut d'un lien d'invitation.
    """
    return (
        f"intent://pok.app{path}#Intent;scheme=https;"
        f"package={ANDROID_PACKAGE};"
        f"S.browser_fallback_url={PLAY_STORE_URL};end"
    )


def _page(
    path: str,
    kind: str,
    custom_title: Optional[str] = None,
    custom_description: Optional[str] = None,
    custom_headline: Optional[str] = None,
    custom_image: Optional[str] = None,
    og_type: str = "website",
) -> HTMLResponse:
    default_label, default_headline = _KIND_LABELS.get(kind, _KIND_LABELS["unknown"])
    label = default_label
    headline = custom_headline or default_headline
    title = custom_title or f"{headline} — Pokou Messenger"
    description = (
        custom_description
        or f"Vous avez reçu {label}. Ouvrez-la dans Pokou Messenger, la messagerie instantanée fluide et sécurisée."
    )
    image_url = custom_image or DEFAULT_OG_IMAGE
    intent = _intent_url(path)

    escaped_title = html_lib.escape(title)
    escaped_description = html_lib.escape(description)
    escaped_headline = html_lib.escape(headline)
    escaped_label = html_lib.escape(label)
    escaped_image = html_lib.escape(image_url)
    if kind in ("group", "community", "unknown"):
        canonical_url = f"https://pok.app/invite/{kind}"
    else:
        canonical_url = f"https://pok.app{path}"

    html = f"""<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{escaped_title}</title>
<meta name="robots" content="noindex">

<!-- Métadonnées Open Graph pour les aperçus sociaux (WhatsApp, Telegram, etc.) -->
<meta property="og:site_name" content="Pokou Messenger">
<meta property="og:type" content="{og_type}">
<meta property="og:title" content="{escaped_title}">
<meta property="og:description" content="{escaped_description}">
<meta property="og:image" content="{escaped_image}">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:url" content="{canonical_url}">

<!-- Twitter Card -->
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="{escaped_title}">
<meta name="twitter:description" content="{escaped_description}">
<meta name="twitter:image" content="{escaped_image}">

<style>
  :root {{ color-scheme: light; }}
  * {{ box-sizing: border-box; }}
  body {{
    margin: 0; min-height: 100vh; display: flex; align-items: center;
    justify-content: center; padding: 24px;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    background: #f7f8fa; color: #111b21;
  }}
  .card {{
    width: 100%; max-width: 400px; background: #fff; border: 1px solid #e9edef;
    border-radius: 20px; padding: 32px 26px; text-align: center;
    box-shadow: 0 4px 16px rgba(0,0,0,.08);
  }}
  .mark {{
    width: 60px; height: 60px; margin: 0 auto 20px; border-radius: 18px;
    background: linear-gradient(135deg, #10b981 0%, #059669 100%);
    display: flex; align-items: center; justify-content: center;
    box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
  }}
  .mark svg {{ width: 30px; height: 30px; fill: #fff; }}
  h1 {{ font-size: 21px; margin: 0 0 8px; color: #111b21; font-weight: 700; }}
  p {{ color: #667781; font-size: 14.5px; line-height: 1.5; margin: 0 0 24px; }}
  a {{
    display: block; text-decoration: none; border-radius: 24px;
    padding: 14px 20px; font-size: 15px; font-weight: 600;
    transition: transform 0.15s ease, background-color 0.15s ease;
  }}
  a:active {{ transform: scale(0.98); }}
  .primary {{ background: #075e54; color: #fff; }}
  .primary:hover {{ background: #054c44; }}
  .secondary {{ background: #f7f8fa; color: #111b21; border: 1px solid #e9edef; margin-top: 10px; }}
  .secondary:hover {{ background: #eef1f4; }}
  .fine {{ margin: 24px 0 0; font-size: 12px; color: #8696a0; }}
</style>
</head>
<body>
  <div class="card">
    <div class="mark">
      <svg viewBox="0 0 24 24"><path d="M12 1 3 5v6c0 5.6 3.8 10.7 9 12 5.2-1.3 9-6.4 9-12V5l-9-4Zm0 10.9h7c-.5 4.1-3.2 7.8-7 9V12H5V6.3l7-3.1v8.7Z"/></svg>
    </div>
    <h1>{escaped_headline}</h1>
    <p>Vous avez reçu {escaped_label}. Ouvrez-la dans Pokou Messenger pour continuer.</p>
    <a class="primary" href="{intent}">Ouvrir dans Pokou</a>
    <a class="secondary" href="{PLAY_STORE_URL}">Je n’ai pas encore Pokou</a>
    <p class="fine">Pokou Messenger — messagerie chiffrée de bout en bout.</p>
  </div>
</body>
</html>"""
    return HTMLResponse(content=html, headers={"Cache-Control": "no-store"})


@router.get("/invite/channel/{code}/post/{post_id}", response_class=HTMLResponse)
@router.get("/channel/{code}/post/{post_id}", response_class=HTMLResponse)
async def channel_post_landing(
    code: str, post_id: int, db: Session = Depends(get_db)
):
    """Lien profond vers une publication spécifique d'une chaîne."""
    path = f"/channel/{code}/post/{post_id}"
    try:
        channel = db.query(Channel).filter(Channel.invite_code == code).first()
        if channel:
            post = (
                db.query(ChannelPost)
                .filter(ChannelPost.id == post_id, ChannelPost.channel_id == channel.id)
                .first()
            )
            if post:
                headline = f"Publication de {channel.name}"
                title = f"{headline} — Pokou Messenger"
                desc = (
                    post.text_content[:200]
                    if post.text_content
                    else f"Découvrez cette publication sur la chaîne {channel.name} dans Pokou Messenger."
                )
                return _page(
                    path,
                    "channel",
                    custom_title=title,
                    custom_description=desc,
                    custom_headline=headline,
                    og_type="article",
                )
            return _page(
                path,
                "channel",
                custom_title=f"Chaîne {channel.name} — Pokou Messenger",
                custom_headline=channel.name,
            )
    except Exception:
        pass
    return _page(path, "channel")


@router.get("/invite/{kind}/{code}", response_class=HTMLResponse)
async def invite_canonical(kind: str, code: str, db: Session = Depends(get_db)):
    """Format canonique : `/invite/group/{code}`, `/invite/community/{code}`,
    `/invite/channel/{code}`."""
    normalized = kind.lower()
    if normalized not in {"group", "community", "channel"}:
        return _page(f"/invite/{kind}/{code}", "unknown")

    if normalized == "channel":
        try:
            channel = db.query(Channel).filter(Channel.invite_code == code).first()
            if channel:
                return _page(
                    f"/invite/channel/{code}",
                    "channel",
                    custom_title=f"Chaîne {channel.name} — Pokou Messenger",
                    custom_description=channel.description
                    or f"Suivez la chaîne {channel.name} sur Pokou Messenger.",
                    custom_headline=channel.name,
                )
        except Exception:
            pass

    return _page(f"/invite/{normalized}/{code}", normalized)


@router.get("/invite/{code}", response_class=HTMLResponse)
async def invite_legacy(code: str):
    """Format historique des groupes — voir group_model.dart::inviteLinkFor."""
    return _page(f"/invite/{code}", "group")


@router.get("/c/{code}", response_class=HTMLResponse)
async def community_legacy(code: str):
    """Format historique des communautés — community_model.dart."""
    return _page(f"/c/{code}", "community")


@router.get("/channel/{code}", response_class=HTMLResponse)
async def channel_link(code: str, db: Session = Depends(get_db)):
    try:
        channel = db.query(Channel).filter(Channel.invite_code == code).first()
        if channel:
            return _page(
                f"/channel/{code}",
                "channel",
                custom_title=f"Chaîne {channel.name} — Pokou Messenger",
                custom_description=channel.description
                or f"Suivez la chaîne {channel.name} sur Pokou Messenger.",
                custom_headline=channel.name,
            )
    except Exception:
        pass
    return _page(f"/channel/{code}", "channel")


@router.get("/bot/{handle}", response_class=HTMLResponse)
async def bot_link(handle: str, db: Session = Depends(get_db)):
    """Le lien d'un bot Pokou Business (`pok.app/bot/<handle>`).
    L'aperçu ne montre que les bots d'entreprises VÉRIFIÉES : un bot de bac
    à sable n'a pas à se présenter au public sous son nom."""
    try:
        from app.models.business import Bot, BusinessOrganization

        bot = db.query(Bot).filter(Bot.handle == handle.lower(), Bot.is_active.is_(True)).first()
        org = (
            db.query(BusinessOrganization).filter(BusinessOrganization.id == bot.organization_id).first()
            if bot
            else None
        )
        if bot and org and org.status == "VERIFIED":
            return _page(
                f"/bot/{bot.handle}",
                "bot",
                custom_title=f"{bot.name} — Pokou Messenger",
                custom_description=bot.description or f"Écrivez à {bot.name} sur Pokou Messenger.",
                custom_headline=bot.name,
            )
    except Exception:
        pass
    return _page(f"/bot/{handle}", "bot")
