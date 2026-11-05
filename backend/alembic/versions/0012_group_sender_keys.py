"""End-to-end encrypted group messages and sender-key distribution.

Revision ID: 0012_group_sender_keys
Revises: 0011_status_e2ee
"""
from alembic import op
import sqlalchemy as sa


revision = "0012_group_sender_keys"
down_revision = "0011_status_e2ee"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "groups",
        sa.Column("crypto_epoch", sa.Integer(), nullable=False, server_default="1"),
    )
    op.add_column("group_messages", sa.Column("encryption", sa.String(length=16), nullable=True))
    op.add_column("group_messages", sa.Column("ciphertext", sa.Text(), nullable=True))
    op.add_column("group_messages", sa.Column("crypto_epoch", sa.Integer(), nullable=True))
    # Existing group content was stored in clear. It cannot safely be exposed
    # as encrypted history; redact it during the transition.
    op.execute(
        "UPDATE group_messages SET content = NULL, original_content = NULL, "
        "payload = NULL, media_asset_id = NULL, poll_id = NULL"
    )
    op.create_table(
        "group_sender_key_distributions",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("group_id", sa.Integer(), nullable=False),
        sa.Column("epoch", sa.Integer(), nullable=False),
        sa.Column("sender_id", sa.Integer(), nullable=False),
        sa.Column("recipient_id", sa.Integer(), nullable=False),
        sa.Column("encryption", sa.String(length=16), nullable=False),
        sa.Column("ciphertext", sa.Text(), nullable=False),
        sa.Column("envelope", sa.JSON(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["group_id"], ["groups.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["sender_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["recipient_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "group_id", "epoch", "sender_id", "recipient_id",
            name="uq_group_sender_key_recipient",
        ),
    )
    op.create_index(
        "ix_group_sender_key_distributions_group_id",
        "group_sender_key_distributions",
        ["group_id"],
    )
    op.create_index(
        "ix_group_sender_key_distributions_recipient_id",
        "group_sender_key_distributions",
        ["recipient_id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_group_sender_key_distributions_recipient_id",
        table_name="group_sender_key_distributions",
    )
    op.drop_index(
        "ix_group_sender_key_distributions_group_id",
        table_name="group_sender_key_distributions",
    )
    op.drop_table("group_sender_key_distributions")
    op.drop_column("group_messages", "crypto_epoch")
    op.drop_column("group_messages", "ciphertext")
    op.drop_column("group_messages", "encryption")
    op.drop_column("groups", "crypto_epoch")
