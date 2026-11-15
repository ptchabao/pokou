"""Messagerie conforme à la maquette : favoris, blocage d'un inconnu (date,
après signalement), mention « Transféré », signalement d'un groupe avec les
5 derniers messages.

Revision ID: 0024_messagerie_maquette
Revises: 0023_kory_plus_fee
"""
from alembic import op
import sqlalchemy as sa


revision = "0024_messagerie_maquette"
down_revision = "0023_kory_plus_fee"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("contacts") as batch:
        batch.add_column(sa.Column("is_favorite", sa.Boolean(), nullable=False, server_default=sa.false()))
        batch.add_column(sa.Column("blocked_at", sa.DateTime(), nullable=True))
        batch.add_column(
            sa.Column("blocked_after_report", sa.Boolean(), nullable=False, server_default=sa.false())
        )
        batch.add_column(sa.Column("added_by_block", sa.Boolean(), nullable=False, server_default=sa.false()))
    with op.batch_alter_table("group_members") as batch:
        batch.add_column(sa.Column("is_favorite", sa.Boolean(), nullable=False, server_default=sa.false()))
    with op.batch_alter_table("direct_messages") as batch:
        batch.add_column(sa.Column("forward_score", sa.Integer(), nullable=False, server_default="0"))
    with op.batch_alter_table("group_messages") as batch:
        batch.add_column(sa.Column("forward_score", sa.Integer(), nullable=False, server_default="0"))
    with op.batch_alter_table("abuse_reports") as batch:
        batch.alter_column("target_user_id", existing_type=sa.Integer(), nullable=True)
        batch.add_column(sa.Column("group_id", sa.Integer(), nullable=True))
        batch.add_column(sa.Column("recent_messages", sa.JSON(), nullable=True))
        batch.create_foreign_key(
            "fk_abuse_reports_group_id", "groups", ["group_id"], ["id"], ondelete="CASCADE"
        )
        batch.create_index("ix_abuse_reports_group_id", ["group_id"])


def downgrade() -> None:
    with op.batch_alter_table("abuse_reports") as batch:
        batch.drop_index("ix_abuse_reports_group_id")
        batch.drop_constraint("fk_abuse_reports_group_id", type_="foreignkey")
        batch.drop_column("recent_messages")
        batch.drop_column("group_id")
        batch.alter_column("target_user_id", existing_type=sa.Integer(), nullable=False)
    with op.batch_alter_table("group_messages") as batch:
        batch.drop_column("forward_score")
    with op.batch_alter_table("direct_messages") as batch:
        batch.drop_column("forward_score")
    with op.batch_alter_table("group_members") as batch:
        batch.drop_column("is_favorite")
    with op.batch_alter_table("contacts") as batch:
        batch.drop_column("added_by_block")
        batch.drop_column("blocked_after_report")
        batch.drop_column("blocked_at")
        batch.drop_column("is_favorite")
