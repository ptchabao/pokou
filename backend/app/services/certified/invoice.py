"""La facture d'un paiement de Pokou certifié, en PDF.

« Facture disponible dans ton compte » (maquette « 2. Vérifier et payer ») :
une ligne, la TVA du pays et le total payé par Mobile Money. Même mise en
page que la facture de Pokou Business (services/business/invoice_pdf.py),
dont elle reprend le formatage des montants.
"""
from __future__ import annotations

from datetime import datetime
from io import BytesIO
from typing import Optional

from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas

from app.services.business.invoice_pdf import fcfa

EMETTEUR = ["Pokou", "Lomé, Togo"]


def render_invoice(
    *,
    number: str,
    issued_at: datetime,
    customer: str,
    label: str,
    price_ht: int,
    vat_rate: float,
    total_ttc: int,
    currency: str = "XOF",
    reference: Optional[str] = None,
) -> bytes:
    tampon = BytesIO()
    page = canvas.Canvas(tampon, pagesize=A4)
    largeur, hauteur = A4
    marge = 20 * mm
    y = hauteur - marge

    page.setTitle(f"Facture {number}")
    page.setFont("Helvetica-Bold", 18)
    page.drawString(marge, y, "FACTURE")
    page.setFont("Helvetica", 10)
    page.drawRightString(largeur - marge, y, number)
    y -= 6 * mm
    page.drawRightString(largeur - marge, y, f"Émise le {issued_at:%d/%m/%Y}")
    y -= 5 * mm
    page.drawRightString(largeur - marge, y, "Statut : Payée")

    y -= 14 * mm
    page.setFont("Helvetica-Bold", 10)
    page.drawString(marge, y, "Émetteur")
    page.drawString(largeur / 2, y, "Client")
    page.setFont("Helvetica", 10)
    for i, ligne in enumerate(EMETTEUR):
        y -= 5 * mm
        page.drawString(marge, y, ligne)
        if i == 0:
            page.drawString(largeur / 2, y, customer[:60])

    y -= 14 * mm
    page.setFont("Helvetica-Bold", 10)
    page.drawString(marge, y, "Désignation")
    page.drawRightString(largeur - marge, y, "Montant")
    y -= 2 * mm
    page.line(marge, y, largeur - marge, y)
    page.setFont("Helvetica", 10)
    y -= 6 * mm
    page.drawString(marge, y, label[:70])
    page.drawRightString(largeur - marge, y, fcfa(price_ht) + " HT")
    y -= 4 * mm
    page.line(marge, y, largeur - marge, y)

    # La TVA se déduit du total réellement payé : un arrondi du pays ne doit
    # pas faire mentir la facture d'un franc.
    for libelle, montant, gras in (
        ("Sous-total HT", price_ht, False),
        (f"TVA ({vat_rate * 100:g} %)", total_ttc - price_ht, False),
        ("Total TTC", total_ttc, True),
    ):
        y -= 6 * mm
        page.setFont("Helvetica-Bold" if gras else "Helvetica", 10)
        page.drawRightString(largeur - marge - 45 * mm, y, libelle)
        page.drawRightString(largeur - marge, y, fcfa(montant))

    page.setFont("Helvetica", 8)
    pied = f"Payé par Mobile Money (CashPay). Montants en francs CFA ({currency})."
    if reference:
        pied += f" Référence : {reference}."
    page.drawString(marge, marge, pied)
    page.showPage()
    page.save()
    return tampon.getvalue()
