"""Messages épinglés (discussions à deux et groupes).

Deux tables qui ne tiennent que des IDENTIFIANTS de messages : le contenu
est chiffré de bout en bout et reste sur les téléphones. Voir
models/messaging.py::DirectMessagePin et models/groups.py::GroupMessagePin.

Revision ID: 0029_messages_epingles
Revises: 0028_fusion_maquette
"""
from alembic import op
import sqlalchemy as sa


revision = "0029_messages_epingles"
down_revision = "0028_fusion_maquette"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "direct_message_pins",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_low_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_high_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column(
            "message_id",
            sa.String(36),
            sa.ForeignKey("direct_messages.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("pinned_by", sa.Integer(), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("pinned_at", sa.DateTime(), nullable=False),
        sa.Column("expires_at", sa.DateTime(), nullable=False),
        sa.UniqueConstraint("message_id", name="uq_direct_message_pin"),
    )
    for column in ("id", "user_low_id", "user_high_id", "message_id", "expires_at"):
        op.create_index(f"ix_direct_message_pins_{column}", "direct_message_pins", [column])

    op.create_table(
        "group_message_pins",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("group_id", sa.Integer(), sa.ForeignKey("groups.id", ondelete="CASCADE"), nullable=False),
        sa.Column(
            "message_id",
            sa.String(36),
            sa.ForeignKey("group_messages.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("pinned_by", sa.Integer(), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("pinned_at", sa.DateTime(), nullable=False),
        sa.Column("expires_at", sa.DateTime(), nullable=False),
        sa.UniqueConstraint("message_id", name="uq_group_message_pin"),
    )
    for column in ("id", "group_id", "message_id", "expires_at"):
        op.create_index(f"ix_group_message_pins_{column}", "group_message_pins", [column])


def downgrade() -> None:
    for column in ("id", "group_id", "message_id", "expires_at"):
        op.drop_index(f"ix_group_message_pins_{column}", table_name="group_message_pins")
    op.drop_table("group_message_pins")
    for column in ("id", "user_low_id", "user_high_id", "message_id", "expires_at"):
        op.drop_index(f"ix_direct_message_pins_{column}", table_name="direct_message_pins")
    op.drop_table("direct_message_pins")
