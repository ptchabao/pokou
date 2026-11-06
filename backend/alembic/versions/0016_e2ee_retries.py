"""Reçus de nouvel essai : re-livraison des messages non déchiffrables.

Revision ID: 0016_e2ee_retries
Revises: 0015_group_settings
"""
from alembic import op
import sqlalchemy as sa


revision = "0016_e2ee_retries"
down_revision = "0015_group_settings"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "e2ee_retries",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("kind", sa.String(length=8), nullable=False),
        sa.Column("message_id", sa.String(length=64), nullable=False),
        sa.Column("group_id", sa.Integer(), nullable=True),
        sa.Column("requester_id", sa.Integer(), nullable=False),
        sa.Column("sender_id", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(length=12), nullable=False, server_default="PENDING"),
        sa.Column("encryption", sa.String(length=16), nullable=True),
        sa.Column("ciphertext", sa.Text(), nullable=True),
        sa.Column("envelope", sa.JSON(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["group_id"], ["groups.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["requester_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["sender_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("kind", "message_id", "requester_id", name="uq_e2ee_retry"),
    )
    op.create_index("ix_e2ee_retries_message_id", "e2ee_retries", ["message_id"])
    op.create_index("ix_e2ee_retries_requester_id", "e2ee_retries", ["requester_id"])
    op.create_index("ix_e2ee_retries_sender_id", "e2ee_retries", ["sender_id"])
    op.create_index("ix_e2ee_retries_status", "e2ee_retries", ["status"])


def downgrade() -> None:
    op.drop_table("e2ee_retries")
