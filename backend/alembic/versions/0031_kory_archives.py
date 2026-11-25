"""Kory : archiver une collecte terminée ou expirée, pour soi seulement.

Une ligne par (collecte, membre) : l'archive est un réglage personnel, pas
un état de la collecte. Voir models/kory.py::KoryArchive.

Revision ID: 0031_kory_archives
Revises: 0030_numero_masque_effacement
"""
from alembic import op
import sqlalchemy as sa


revision = "0031_kory_archives"
down_revision = "0030_numero_masque_effacement"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "kory_archives",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("pot_id", sa.Integer(), sa.ForeignKey("kory_pots.id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("archived_at", sa.DateTime(), nullable=False),
        sa.UniqueConstraint("pot_id", "user_id", name="uq_kory_archive"),
    )
    for column in ("id", "pot_id", "user_id"):
        op.create_index(f"ix_kory_archives_{column}", "kory_archives", [column])


def downgrade() -> None:
    for column in ("id", "pot_id", "user_id"):
        op.drop_index(f"ix_kory_archives_{column}", table_name="kory_archives")
    op.drop_table("kory_archives")
