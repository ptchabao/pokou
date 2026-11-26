"""Mark the dedicated store-review account.

Revision ID: 0033_store_review_account
Revises: 0032_honam_demo_main_propre
"""
from alembic import op
import sqlalchemy as sa


revision = "0033_store_review_account"
down_revision = "0032_honam_demo_main_propre"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column(
            "is_store_review_account",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )


def downgrade() -> None:
    op.drop_column("users", "is_store_review_account")
