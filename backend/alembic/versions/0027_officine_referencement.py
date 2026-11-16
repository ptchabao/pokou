"""Honam, maquettes Officine 14 à 16 : « Référencer votre officine ».

Le dossier qu'un pharmacien envoie depuis l'application, vérifié par le
support sous 48 h avant que l'officine ne soit créée.

Revision ID: 0027_officine_referencement
Revises: 0026_assime_maquette
"""
from alembic import op
import sqlalchemy as sa


revision = "0027_officine_referencement"
down_revision = "0026_assime_maquette"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "honam_pharmacy_applications",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("country", sa.String(2), nullable=False),
        sa.Column("name", sa.String(160), nullable=False),
        sa.Column("address", sa.String(255), nullable=False),
        sa.Column("license_number", sa.String(64), nullable=False),
        sa.Column("wallet_phone", sa.String(32), nullable=False),
        sa.Column("authorization_media_id", sa.Integer(),
                  sa.ForeignKey("media_assets.id", ondelete="SET NULL"), nullable=True),
        sa.Column("plan", sa.String(8), nullable=False),
        sa.Column("latitude", sa.Float(), nullable=True),
        sa.Column("longitude", sa.Float(), nullable=True),
        sa.Column("status", sa.String(12), nullable=False, server_default="PENDING"),
        sa.Column("review_note", sa.String(500), nullable=True),
        sa.Column("submitted_at", sa.DateTime(), nullable=False),
        sa.Column("review_due_at", sa.DateTime(), nullable=False),
        sa.Column("reviewed_at", sa.DateTime(), nullable=True),
        sa.Column("reviewer_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("pharmacy_id", sa.Integer(),
                  sa.ForeignKey("honam_pharmacies.id", ondelete="SET NULL"), nullable=True),
    )
    op.create_index("ix_honam_pharmacy_applications_id", "honam_pharmacy_applications", ["id"])
    op.create_index("ix_honam_pharmacy_applications_user_id", "honam_pharmacy_applications", ["user_id"], unique=True)
    op.create_index("ix_honam_pharmacy_applications_country", "honam_pharmacy_applications", ["country"])
    op.create_index("ix_honam_pharmacy_applications_status", "honam_pharmacy_applications", ["status"])


def downgrade() -> None:
    op.drop_index("ix_honam_pharmacy_applications_status", table_name="honam_pharmacy_applications")
    op.drop_index("ix_honam_pharmacy_applications_country", table_name="honam_pharmacy_applications")
    op.drop_index("ix_honam_pharmacy_applications_user_id", table_name="honam_pharmacy_applications")
    op.drop_index("ix_honam_pharmacy_applications_id", table_name="honam_pharmacy_applications")
    op.drop_table("honam_pharmacy_applications")
