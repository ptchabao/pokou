"""Demandes de support et problèmes signalés depuis Aide et support.

Le texte de la personne et la réponse de l'équipe sont chiffrés au repos
(REPORTS_ENCRYPTION_KEY, voir app/core/report_crypto.py).

Revision ID: 0027_support_tickets
Revises: 0026_assime_maquette
"""
from alembic import op
import sqlalchemy as sa


revision = "0027_support_tickets"
down_revision = "0026_assime_maquette"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "support_tickets",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("kind", sa.String(10), nullable=False, server_default="SUPPORT"),
        sa.Column("category", sa.String(20), nullable=False, server_default="OTHER"),
        sa.Column("description_encrypted", sa.Text(), nullable=False),
        sa.Column("app_version", sa.String(32), nullable=True),
        sa.Column("platform", sa.String(16), nullable=True),
        sa.Column(
            "screenshot_media_id", sa.Integer(),
            sa.ForeignKey("media_assets.id", ondelete="SET NULL"), nullable=True,
        ),
        sa.Column("status", sa.String(10), nullable=False, server_default="OPEN"),
        sa.Column("reply_encrypted", sa.Text(), nullable=True),
        sa.Column("replied_by", sa.Integer(), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("replied_at", sa.DateTime(), nullable=True),
        sa.Column("closed_at", sa.DateTime(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_support_tickets_id", "support_tickets", ["id"])
    op.create_index("ix_support_tickets_user_id", "support_tickets", ["user_id"])
    op.create_index("ix_support_tickets_kind", "support_tickets", ["kind"])
    op.create_index("ix_support_tickets_status", "support_tickets", ["status"])
    op.create_index("ix_support_tickets_created_at", "support_tickets", ["created_at"])


def downgrade() -> None:
    op.drop_index("ix_support_tickets_created_at", table_name="support_tickets")
    op.drop_index("ix_support_tickets_status", table_name="support_tickets")
    op.drop_index("ix_support_tickets_kind", table_name="support_tickets")
    op.drop_index("ix_support_tickets_user_id", table_name="support_tickets")
    op.drop_index("ix_support_tickets_id", table_name="support_tickets")
    op.drop_table("support_tickets")
