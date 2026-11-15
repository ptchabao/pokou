"""Pokou certifié : forme du badge, opérateur du wallet, détails du profil Pro.

Revision ID: 0024_certified_pro_details
Revises: 0023_kory_plus_fee
"""
from alembic import op
import sqlalchemy as sa


revision = "0024_certified_pro_details"
down_revision = "0023_kory_plus_fee"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("users") as batch:
        batch.add_column(sa.Column("is_pro_badge", sa.Boolean(), nullable=False, server_default=sa.false()))
    with op.batch_alter_table("certified_subscriptions") as batch:
        batch.add_column(sa.Column("wallet_operator", sa.String(length=60), nullable=True))
    with op.batch_alter_table("certified_pro_applications") as batch:
        batch.add_column(sa.Column("address", sa.String(length=200), nullable=True))
        batch.add_column(sa.Column("document_type", sa.String(length=12), nullable=True))
        batch.add_column(sa.Column("document_name", sa.String(length=160), nullable=True))
        batch.add_column(sa.Column("hours", sa.JSON(), nullable=True))
        batch.add_column(sa.Column("pro_since", sa.DateTime(), nullable=True))


def downgrade() -> None:
    with op.batch_alter_table("certified_pro_applications") as batch:
        batch.drop_column("pro_since")
        batch.drop_column("hours")
        batch.drop_column("document_name")
        batch.drop_column("document_type")
        batch.drop_column("address")
    with op.batch_alter_table("certified_subscriptions") as batch:
        batch.drop_column("wallet_operator")
    with op.batch_alter_table("users") as batch:
        batch.drop_column("is_pro_badge")
