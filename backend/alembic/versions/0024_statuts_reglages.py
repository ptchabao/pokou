"""Statuts et réglages : cœur sur un statut, appels d'inconnus coupés,
push des services coupés par module.

Revision ID: 0024_statuts_reglages
Revises: 0023_kory_plus_fee
"""
from alembic import op
import sqlalchemy as sa


revision = "0024_statuts_reglages"
down_revision = "0023_kory_plus_fee"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("status_views") as batch:
        batch.add_column(sa.Column("liked_at", sa.DateTime(), nullable=True))
    with op.batch_alter_table("users") as batch:
        batch.add_column(
            sa.Column(
                "silence_unknown_calls",
                sa.Boolean(),
                nullable=False,
                server_default=sa.false(),
            )
        )
        batch.add_column(sa.Column("muted_service_pushes", sa.JSON(), nullable=True))


def downgrade() -> None:
    with op.batch_alter_table("users") as batch:
        batch.drop_column("muted_service_pushes")
        batch.drop_column("silence_unknown_calls")
    with op.batch_alter_table("status_views") as batch:
        batch.drop_column("liked_at")
