"""L'export daté d'une discussion en mode preuve (maquettes 8 et 9).

Un PDF et non un fichier texte : il se transmet tel quel à un avocat, une
police ou un chef de quartier, et chaque page porte la date d'export. Les
messages supprimés y figurent barrés, les messages modifiés avec leur
version d'origine — c'est tout l'intérêt du mode preuve.

Limite connue : les polices de base de reportlab ne couvrent pas les lettres
éwé et kabiyè (ɖ, ɛ, ŋ, ɔ…). Elles s'impriment remplacées ; embarquer Inter
dans le PDF est la suite logique.
"""
from datetime import datetime
from io import BytesIO
from xml.sax.saxutils import escape

from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer


def _fmt(moment: datetime) -> str:
    return moment.strftime("%d/%m/%Y %H:%M") + " GMT"


def render(group_name: str, since: datetime | None, messages: list[dict], exported_by: str) -> bytes:
    buffer = BytesIO()
    exported_at = datetime.utcnow()

    def stamp(canvas, doc):
        canvas.saveState()
        canvas.setFont("Helvetica", 8)
        canvas.drawString(15 * mm, 10 * mm, f"Pokou — export du {_fmt(exported_at)} — page {doc.page}")
        canvas.restoreState()

    doc = SimpleDocTemplate(buffer, pagesize=A4, leftMargin=15 * mm, rightMargin=15 * mm,
                            topMargin=15 * mm, bottomMargin=18 * mm, title=f"Mode preuve — {group_name}")
    styles = getSampleStyleSheet()
    body, small = styles["BodyText"], styles["Italic"]
    story = [
        Paragraph(escape(f"Discussion « {group_name} » — mode preuve"), styles["Title"]),
        Paragraph(escape(f"Exporté le {_fmt(exported_at)} par {exported_by}."), body),
        Paragraph(escape(f"Mode preuve actif depuis le {_fmt(since)}." if since else "Mode preuve."), body),
        Spacer(1, 6 * mm),
    ]
    for m in messages:
        head = f"<b>{escape(m['sender'])}</b> — {_fmt(m['created_at'])}"
        content = escape(m["content"] or f"[{m['type']}]")
        if m.get("deleted_at"):
            story.append(Paragraph(f"{head} — <i>supprimé le {_fmt(m['deleted_at'])}</i>", body))
            story.append(Paragraph(f"<strike>{content}</strike>", body))
        elif m.get("original_content"):
            story.append(Paragraph(f"{head} — <i>modifié le {_fmt(m['edited_at'])}</i>", body))
            story.append(Paragraph(f"Version d'origine : {escape(m['original_content'])}", small))
            story.append(Paragraph(content, body))
        else:
            story.append(Paragraph(head, body))
            story.append(Paragraph(content, body))
        story.append(Spacer(1, 2 * mm))
    doc.build(story, onFirstPage=stamp, onLaterPages=stamp)
    return buffer.getvalue()
