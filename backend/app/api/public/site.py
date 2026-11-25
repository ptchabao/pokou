"""Le site officiel (pokou.app) et l'aiguillage des sous-domaines.

Tous les noms de pokou.app arrivent sur cette même API (un seul Ingress) ;
c'est le nom demandé qui décide de ce qu'on sert :

- `pokou.app` : le site vitrine (`app/site/`), plus les pages
  « Conditions » et « Confidentialité », rendues depuis `app/legal/` — le
  même texte que dans l'application, une seule source ;
- `www.pokou.app` : redirige vers `pokou.app` ;
- `extranet.pokou.app` : la console d'administration (la racine y mène),
  et l'espace officine sous `/officine/` ; ailleurs, `/console/` y renvoie ;
- `deep.pokou.app` (liens d'invitation) : la racine mène au site.

Le reste (API, liens profonds, `.well-known`, pages de suppression) est
servi à l'identique sous chaque nom.
"""
import html
import re
from pathlib import Path
from typing import Optional

from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import FileResponse, HTMLResponse, RedirectResponse, Response

from app.core.config import get_settings

router = APIRouter(tags=["site"], include_in_schema=False)

_SITE = (Path(__file__).resolve().parents[2] / "site").resolve()
_LEGAL = Path(__file__).resolve().parents[2] / "legal"
_DOCS = {"conditions": "conditions.md", "confidentialite": "confidentialite.md"}
_HEADERS = {
    "Content-Security-Policy": (
        "default-src 'self'; script-src 'none'; style-src 'self'; img-src 'self' data:; "
        "frame-ancestors 'none'; base-uri 'none'; form-action 'none'"
    ),
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "strict-origin-when-cross-origin",
}
_TYPES = {".css": "text/css; charset=utf-8", ".jpg": "image/jpeg", ".png": "image/png", ".html": "text/html; charset=utf-8"}


def _host(request: Request) -> str:
    return (request.headers.get("host") or "").split(":")[0].strip().lower()


def site_redirect(request: Request) -> Optional[Response]:
    """La redirection propre à un sous-domaine, ou None (appelé par main.py)."""
    settings = get_settings()
    host = _host(request)
    site = settings.site_host
    path = request.url.path
    if host == f"www.{site}":
        target = f"https://{site}{path}"
        if request.url.query:
            target += f"?{request.url.query}"
        return RedirectResponse(target, status_code=301)
    if path == "/" and host == settings.extranet_host:
        return RedirectResponse("/console/", status_code=302)
    # La console ne vit que sur l'extranet : sous un autre nom de pokou.app,
    # on y renvoie (les autres hôtes — tests, développement — ne bougent pas).
    if (path == "/console" or path.startswith("/console/")) and host != settings.extranet_host \
            and (host == site or host.endswith("." + site)):
        target = f"https://{settings.extranet_host}{path}"
        if request.url.query:
            target += f"?{request.url.query}"
        return RedirectResponse(target, status_code=301)
    link_host = settings.public_link_base_url.split("://", 1)[-1].split("/")[0].lower()
    if path == "/" and host == link_host and host != site:
        return RedirectResponse(f"https://{site}/", status_code=302)
    if host == site and path == "/":
        return _file("index.html")
    if host == site and path.strip("/") in _DOCS:
        return _legal_page(path.strip("/"))
    return None


def _file(name: str) -> FileResponse:
    target = (_SITE / name).resolve()
    if not target.is_file() or _SITE not in target.parents:
        raise HTTPException(status_code=404)
    headers = dict(_HEADERS)
    headers["Cache-Control"] = "no-cache" if target.suffix == ".html" else "public, max-age=86400"
    return FileResponse(target, media_type=_TYPES.get(target.suffix, "application/octet-stream"), headers=headers)


@router.get("/site/{name:path}")
def site_asset(name: str):
    return _file(name)


def _inline(text: str) -> str:
    out = html.escape(text, quote=False)
    out = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", out)
    out = re.sub(r"(?<!\*)\*(?!\s)(.+?)(?<!\s)\*(?!\*)", r"<em>\1</em>", out)
    return out


def markdown_to_html(source: str) -> str:
    """Le sous-ensemble de Markdown des textes légaux : titres, paragraphes,
    listes, citations, gras et italique. Tout le texte est échappé."""
    blocks: list[str] = []
    para: list[str] = []
    items: list[str] = []
    quote: list[str] = []

    def flush():
        if para:
            blocks.append(f"<p>{_inline(' '.join(para))}</p>")
            para.clear()
        if items:
            blocks.append("<ul>" + "".join(f"<li>{_inline(i)}</li>" for i in items) + "</ul>")
            items.clear()
        if quote:
            blocks.append(f"<blockquote><p>{_inline(' '.join(quote))}</p></blockquote>")
            quote.clear()

    for raw in source.splitlines():
        line = raw.rstrip()
        stripped = line.strip()
        if not stripped:
            flush()
            continue
        heading = re.match(r"^(#{1,3})\s+(.*)$", stripped)
        if heading:
            flush()
            level = len(heading.group(1))
            blocks.append(f"<h{level}>{_inline(heading.group(2))}</h{level}>")
        elif stripped.startswith(">"):
            if para or items:
                flush()
            quote.append(stripped.lstrip(">").strip())
        elif re.match(r"^[-*]\s+", stripped):
            if para or quote:
                flush()
            items.append(re.sub(r"^[-*]\s+", "", stripped))
        elif items and line.startswith((" ", "\t")):
            items[-1] += " " + stripped
        elif quote:
            quote.append(stripped)
        else:
            if items:
                flush()
            para.append(stripped)
    flush()
    return "\n".join(blocks)


def _legal_page(name: str) -> HTMLResponse:
    source = (_LEGAL / _DOCS[name]).read_text(encoding="utf-8")
    title = html.escape(source.splitlines()[0].lstrip("# ").strip())
    body = markdown_to_html(source)
    page = f"""<!doctype html>
<html lang="fr">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{title}</title>
  <link rel="icon" href="/site/img/favicon-32.png" sizes="32x32">
  <link rel="stylesheet" href="/site/site.css">
</head>
<body>
  <main class="doc">
    <div class="wrap narrow">
      <a class="back" href="/">← Pokou</a>
      {body}
    </div>
  </main>
</body>
</html>"""
    headers = dict(_HEADERS)
    headers["Cache-Control"] = "no-cache"
    return HTMLResponse(page, headers=headers)
