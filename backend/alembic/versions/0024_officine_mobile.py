"""Espace officine sur téléphone : remboursement déclaré (référence du
transfert), course déclarée payée au coursier, original rapporté.

Revision ID: 0024_officine_mobile
Revises: 0024_kory_maquette
"""
from alembic import op
import sqlalchemy as sa


revision = "0024_officine_mobile"
down_revision = "0024_kory_maquette"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("honam_orders") as batch:
        batch.add_column(sa.Column("refund_sent_at", sa.DateTime(), nullable=True))
        batch.add_column(sa.Column("refund_reference", sa.String(length=40), nullable=True))
        batch.add_column(sa.Column("courier_paid_declared_at", sa.DateTime(), nullable=True))


def downgrade() -> None:
    with op.batch_alter_table("honam_orders") as batch:
        batch.drop_column("courier_paid_declared_at")
        batch.drop_column("refund_reference")
        batch.drop_column("refund_sent_at")
