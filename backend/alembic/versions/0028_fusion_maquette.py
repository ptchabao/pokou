"""Fusion des quatre branches 0027 nées en parallèle (maquette, 16 nov. 2026) :
référencement d'officine, recherche de coursier, sondages de groupe et
demandes de support. Aucune opération : elles touchent des tables distinctes.

Revision ID: 0028_fusion_maquette
Revises: 0027_officine_referencement, 0027_officine_coursier,
         0027_sondage_groupe, 0027_support_tickets
"""

revision = "0028_fusion_maquette"
down_revision = (
    "0027_officine_referencement",
    "0027_officine_coursier",
    "0027_sondage_groupe",
    "0027_support_tickets",
)
branch_labels = None
depends_on = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
