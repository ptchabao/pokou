"""Messages exchanged by participants in a HONAM order.

Revision ID: 0010
Revises: 0009
Create Date: 2026-11-04

"""
from alembic import op
import sqlalchemy as sa


revision = "0010"
down_revision = "0009"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "honam_order_messages",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("order_id", sa.Integer(), nullable=False),
        sa.Column("sender_id", sa.Integer(), nullable=True),
        sa.Column("sender_role", sa.String(length=12), nullable=False),
        sa.Column("body", sa.String(length=1000), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["order_id"], ["honam_orders.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["sender_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_honam_order_messages_id", "honam_order_messages", ["id"], unique=False)
    op.create_index("ix_honam_order_messages_order_id", "honam_order_messages", ["order_id"], unique=False)
    op.create_index("ix_honam_order_messages_sender_id", "honam_order_messages", ["sender_id"], unique=False)
    op.create_index(
        "ix_honam_order_messages_order_created",
        "honam_order_messages",
        ["order_id", "created_at", "id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_honam_order_messages_order_created", table_name="honam_order_messages")
    op.drop_index("ix_honam_order_messages_sender_id", table_name="honam_order_messages")
    op.drop_index("ix_honam_order_messages_order_id", table_name="honam_order_messages")
    op.drop_index("ix_honam_order_messages_id", table_name="honam_order_messages")
    op.drop_table("honam_order_messages")
