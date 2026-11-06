"""Réglages de groupe (DIS-26) : qui modifie le nom et la photo, approbation
des nouveaux membres, et demandes d'adhésion par lien.

Revision ID: 0015_group_settings
Revises: 0014_baba_messages
"""
from alembic import op
import sqlalchemy as sa


revision = "0015_group_settings"
down_revision = "0014_baba_messages"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("groups", sa.Column("members_can_edit_info", sa.Boolean(), nullable=False, server_default=sa.false()))
    op.add_column("groups", sa.Column("join_approval", sa.Boolean(), nullable=False, server_default=sa.false()))
    op.create_table(
        "group_join_requests",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("group_id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(length=12), nullable=False, server_default="PENDING"),
        sa.Column("decided_by", sa.Integer(), nullable=True),
        sa.Column("decided_at", sa.DateTime(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["group_id"], ["groups.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["decided_by"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("group_id", "user_id", name="uq_group_join_request"),
    )
    op.create_index("ix_group_join_requests_group_id", "group_join_requests", ["group_id"])


def downgrade() -> None:
    op.drop_index("ix_group_join_requests_group_id", table_name="group_join_requests")
    op.drop_table("group_join_requests")
    op.drop_column("groups", "join_approval")
    op.drop_column("groups", "members_can_edit_info")
