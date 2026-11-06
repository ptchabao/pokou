"""Code PIN oublié : demande de levée après un délai (REG-6, AUTH-11).

Revision ID: 0013_pin_reset_request
Revises: 0012_group_sender_keys
"""
from alembic import op
import sqlalchemy as sa


revision = "0013_pin_reset_request"
down_revision = "0012_group_sender_keys"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("two_step_reset_requested_at", sa.DateTime(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("users", "two_step_reset_requested_at")
