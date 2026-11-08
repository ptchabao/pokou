"""Espace d'administration : file des signalements d'abus.

Revision ID: 0018_admin_space
Revises: 0017_kory_pledges
"""
from alembic import op
import sqlalchemy as sa


revision = "0018_admin_space"
down_revision = "0017_kory_pledges"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "abuse_reports",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("reporter_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("target_user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("reason", sa.String(length=280), nullable=True),
        sa.Column("blocked", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("status", sa.String(length=12), nullable=False, server_default="OPEN"),
        sa.Column("resolution", sa.String(length=280), nullable=True),
        sa.Column("resolved_by", sa.Integer(), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("resolved_at", sa.DateTime(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_abuse_reports_status", "abuse_reports", ["status"])
    op.create_index("ix_abuse_reports_target", "abuse_reports", ["target_user_id"])
    op.create_index("ix_abuse_reports_created", "abuse_reports", ["created_at"])


def downgrade() -> None:
    op.drop_table("abuse_reports")
