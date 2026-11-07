"""Kory : engagements (KOR-12 à 14), motif de refus (KOR-5), prolongation ;
centre de notifications (NOT-1).

Revision ID: 0017_kory_pledges
Revises: 0016_e2ee_retries
"""
from alembic import op
import sqlalchemy as sa


revision = "0017_kory_pledges"
down_revision = "0016_e2ee_retries"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("kory_members") as t:
        t.add_column(sa.Column("pledge_base", sa.Integer(), nullable=True))
        t.add_column(sa.Column("pledge_daily", sa.Integer(), nullable=True))
        t.add_column(sa.Column("pledged_at", sa.DateTime(), nullable=True))
        t.add_column(sa.Column("pledge_cancelled_at", sa.DateTime(), nullable=True))
    with op.batch_alter_table("kory_entries") as t:
        t.add_column(sa.Column("review_reason", sa.String(length=280), nullable=True))
        t.add_column(sa.Column("proof_media_id", sa.Integer(), nullable=True))
    with op.batch_alter_table("kory_pots") as t:
        t.add_column(sa.Column("extended_at", sa.DateTime(), nullable=True))
    # Assimé : vente (ANN-18) et note de la vente (ANN-19).
    with op.batch_alter_table("marketplace_products") as t:
        t.add_column(sa.Column("sold_at", sa.DateTime(), nullable=True))
        t.add_column(sa.Column("buyer_id", sa.Integer(), nullable=True))
        t.add_column(sa.Column("final_price", sa.Integer(), nullable=True))
    with op.batch_alter_table("seller_reviews") as t:
        t.add_column(sa.Column("product_id", sa.Integer(), nullable=True))
        t.add_column(sa.Column("tags", sa.JSON(), nullable=True))
    # Sauvegarde chiffrée (MSG-12).
    op.create_table(
        "user_backups",
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("media_asset_id", sa.Integer(), sa.ForeignKey("media_assets.id", ondelete="SET NULL"), nullable=True),
        sa.Column("salt", sa.String(length=64), nullable=False),
        sa.Column("iterations", sa.Integer(), nullable=False),
        sa.Column("discussions", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("messages", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("size_bytes", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )
    # Centre de notifications (NOT-1).
    op.create_table(
        "service_notifications",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("service", sa.String(length=16), nullable=False),
        sa.Column("title", sa.String(length=120), nullable=False),
        sa.Column("body", sa.String(length=280), nullable=False),
        sa.Column("route", sa.String(length=120), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("read_at", sa.DateTime(), nullable=True),
    )
    op.create_index("ix_service_notifications_user_id", "service_notifications", ["user_id"])
    op.create_index("ix_service_notifications_created_at", "service_notifications", ["created_at"])


def downgrade() -> None:
    op.drop_table("service_notifications")
    op.drop_table("user_backups")
    with op.batch_alter_table("seller_reviews") as t:
        t.drop_column("tags")
        t.drop_column("product_id")
    with op.batch_alter_table("marketplace_products") as t:
        t.drop_column("final_price")
        t.drop_column("buyer_id")
        t.drop_column("sold_at")
    with op.batch_alter_table("kory_pots") as t:
        t.drop_column("extended_at")
    with op.batch_alter_table("kory_entries") as t:
        t.drop_column("proof_media_id")
        t.drop_column("review_reason")
    with op.batch_alter_table("kory_members") as t:
        t.drop_column("pledge_cancelled_at")
        t.drop_column("pledged_at")
        t.drop_column("pledge_daily")
        t.drop_column("pledge_base")
