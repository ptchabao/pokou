"""La facture imprimable, en PDF (reportlab, déjà utilisé pour les rapports).

Une facture est un document que l'entreprise remet à son comptable : elle
porte le numéro, les deux parties, les lignes, la taxe et le total, et
rien d'autre. Les montants sont en FCFA entiers, séparés par des espaces
fines à la française (12 500 FCFA).
"""
from __future__ import annotations

from io import BytesIO

from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas

from app.models.business import Invoice, BusinessOrganization

EMETTEUR = [
    "Pokou Business",
    "Lomé, Togo",
    "business@pok.app",
]

STATUTS = {
    "PAID": "Payée",
    "ISSUED": "À régler",
    "OVERDUE": "En retard",
    "VOID": "Annulée",
}


def fcfa(montant: int) -> str:
    return f"{montant:,}".replace(",", " ") + " FCFA"


def _date(d) -> str:
    return d.strftime("%d/%m/%Y") if d else "—"


def rendre(facture: Invoice, org: BusinessOrganization) -> bytes:
    tampon = BytesIO()
    page = canvas.Canvas(tampon, pagesize=A4)
    largeur, hauteur = A4
    marge = 20 * mm
    y = hauteur - marge

    page.setTitle(f"Facture {facture.number}")
    page.setFont("Helvetica-Bold", 18)
    page.drawString(marge, y, "FACTURE" if facture.kind == "MONTHLY" else "FACTURE — RECHARGE")
    page.setFont("Helvetica", 10)
    page.drawRightString(largeur - marge, y, facture.number)
    y -= 6 * mm
    page.drawRightString(largeur - marge, y, f"Émise le {_date(facture.issued_at)}")
    if facture.due_at and facture.status != "PAID":
        y -= 5 * mm
        page.drawRightString(largeur - marge, y, f"Échéance : {_date(facture.due_at)}")
    y -= 5 * mm
    page.drawRightString(largeur - marge, y, f"Statut : {STATUTS.get(facture.status, facture.status)}")

    y -= 14 * mm
    page.setFont("Helvetica-Bold", 10)
    page.drawString(marge, y, "Émetteur")
    page.drawString(largeur / 2, y, "Client")
    page.setFont("Helvetica", 10)
    client = [
        org.legal_name or org.name,
        *(f"RCCM : {org.rccm}" for _ in [0] if org.rccm),
        *(f"NIF : {org.nif}" for _ in [0] if org.nif),
        *([org.address] if org.address else []),
        *([org.billing_email] if org.billing_email else []),
    ]
    for i in range(max(len(EMETTEUR), len(client))):
        y -= 5 * mm
        if i < len(EMETTEUR):
            page.drawString(marge, y, EMETTEUR[i])
        if i < len(client):
            page.drawString(largeur / 2, y, client[i])

    if facture.period_start and facture.period_end:
        y -= 10 * mm
        page.drawString(
            marge, y, f"Période : du {_date(facture.period_start)} au {_date(facture.period_end)} (exclu)"
        )

    y -= 12 * mm
    colonnes = [marge, marge + 95 * mm, marge + 120 * mm, largeur - marge]
    page.setFont("Helvetica-Bold", 10)
    page.drawString(colonnes[0], y, "Désignation")
    page.drawRightString(colonnes[1] + 15 * mm, y, "Quantité")
    page.drawRightString(colonnes[2] + 20 * mm, y, "Prix unitaire")
    page.drawRightString(colonnes[3], y, "Montant")
    y -= 2 * mm
    page.line(marge, y, largeur - marge, y)
    page.setFont("Helvetica", 10)
    for ligne in facture.lines or []:
        y -= 6 * mm
        page.drawString(colonnes[0], y, str(ligne.get("label", ""))[:60])
        page.drawRightString(colonnes[1] + 15 * mm, y, f"{int(ligne.get('quantity', 0)):,}".replace(",", " "))
        page.drawRightString(colonnes[2] + 20 * mm, y, fcfa(int(ligne.get("unit_price", 0))))
        page.drawRightString(colonnes[3], y, fcfa(int(ligne.get("amount", 0))))

    y -= 4 * mm
    page.line(marge, y, largeur - marge, y)
    totaux = [("Sous-total", facture.subtotal)]
    if facture.tax_rate_bp:
        totaux.append((f"Taxe ({facture.tax_rate_bp / 100:g} %)", facture.tax_amount))
    totaux.append(("Total", facture.total))
    for libelle, montant in totaux:
        y -= 6 * mm
        page.setFont("Helvetica-Bold" if libelle == "Total" else "Helvetica", 10)
        page.drawRightString(colonnes[2] + 20 * mm, y, libelle)
        page.drawRightString(colonnes[3], y, fcfa(int(montant)))

    page.setFont("Helvetica", 8)
    page.drawString(
        marge,
        marge,
        "Paiement par Mobile Money depuis le portail Pokou Business. Montants en francs CFA (XOF).",
    )
    page.showPage()
    page.save()
    return tampon.getvalue()
