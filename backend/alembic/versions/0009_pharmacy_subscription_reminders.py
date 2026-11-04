"""Suivi des relances d'abonnement des officines.

Revision ID: 0009
Revises: 0008
Create Date: 2026-11-04

"""
from alembic import op
import sqlalchemy as sa


revision = "0009"
down_revision = "0008"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("honam_pharmacies", schema=None) as batch_op:
        batch_op.add_column(sa.Column("subscription_reminder_7d_for", sa.DateTime(), nullable=True))
        batch_op.add_column(sa.Column("subscription_reminder_1d_for", sa.DateTime(), nullable=True))


def downgrade() -> None:
    with op.batch_alter_table("honam_pharmacies", schema=None) as batch_op:
        batch_op.drop_column("subscription_reminder_1d_for")
        batch_op.drop_column("subscription_reminder_7d_for")
