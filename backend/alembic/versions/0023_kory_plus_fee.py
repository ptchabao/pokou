"""Kory Plus : frais d'ouverture d'une tontine, payés par chaque membre.

Revision ID: 0023_kory_plus_fee
Revises: 0022_kory_mockup
"""
from alembic import op
import sqlalchemy as sa


revision = "0023_kory_plus_fee"
down_revision = "0022_kory_mockup"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("kory_members") as batch:
        batch.add_column(sa.Column("fee_paid_at", sa.DateTime(), nullable=True))
        batch.add_column(sa.Column("fee_payment_id", sa.Integer(), nullable=True))


def downgrade() -> None:
    with op.batch_alter_table("kory_members") as batch:
        batch.drop_column("fee_payment_id")
        batch.drop_column("fee_paid_at")
