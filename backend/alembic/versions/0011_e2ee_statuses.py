"""Store status content only as recipient-specific E2EE envelopes.

Revision ID: 0011_status_e2ee
Revises: 0010
"""
from alembic import op
import sqlalchemy as sa


revision = "0011_status_e2ee"
down_revision = "0010"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Legacy status text/media was stored in plaintext. Do not retain it after
    # enabling an API which promises that the server cannot read status data.
    op.execute("DELETE FROM status_views")
    op.execute("DELETE FROM statuses")
    with op.batch_alter_table("statuses") as batch:
        batch.drop_column("text_content")

    op.create_table(
        "status_recipients",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("status_id", sa.String(length=36), nullable=False),
        sa.Column("recipient_id", sa.Integer(), nullable=False),
        sa.Column("encryption", sa.String(length=32), nullable=False),
        sa.Column("ciphertext", sa.Text(), nullable=False),
        sa.Column("envelope", sa.JSON(), nullable=False),
        sa.ForeignKeyConstraint(["recipient_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["status_id"], ["statuses.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("status_id", "recipient_id", name="uq_status_recipient_status_user"),
    )
    op.create_index("ix_status_recipients_status_id", "status_recipients", ["status_id"])
    op.create_index("ix_status_recipients_recipient_id", "status_recipients", ["recipient_id"])


def downgrade() -> None:
    op.drop_index("ix_status_recipients_recipient_id", table_name="status_recipients")
    op.drop_index("ix_status_recipients_status_id", table_name="status_recipients")
    op.drop_table("status_recipients")
    with op.batch_alter_table("statuses") as batch:
        batch.add_column(sa.Column("text_content", sa.Text(), nullable=True))
