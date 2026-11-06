"""Baba servi par l'API Pokou : fil de discussion.

Revision ID: 0014_baba_messages
Revises: 0013_pin_reset_request
"""
from alembic import op
import sqlalchemy as sa


revision = "0014_baba_messages"
down_revision = "0013_pin_reset_request"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "baba_messages",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("direction", sa.String(length=3), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("provider", sa.String(length=32), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_baba_messages_user_id", "baba_messages", ["user_id"])
    op.create_index("ix_baba_messages_created_at", "baba_messages", ["created_at"])


def downgrade() -> None:
    op.drop_index("ix_baba_messages_created_at", table_name="baba_messages")
    op.drop_index("ix_baba_messages_user_id", table_name="baba_messages")
    op.drop_table("baba_messages")
