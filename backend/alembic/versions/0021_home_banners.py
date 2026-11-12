"""Bannières du carrousel de l'accueil, par pays et région.

Revision ID: 0021_home_banners
Revises: 0020_token_client
"""
from alembic import op
import sqlalchemy as sa


revision = "0021_home_banners"
down_revision = "0020_token_client"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "home_banners",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("label", sa.String(length=40), nullable=True),
        sa.Column("title", sa.String(length=80), nullable=False),
        sa.Column("body", sa.String(length=200), nullable=True),
        sa.Column("image_media_id", sa.Integer(), sa.ForeignKey("media_assets.id", ondelete="SET NULL"), nullable=True),
        sa.Column("cta_label", sa.String(length=30), nullable=True),
        sa.Column("cta_url", sa.String(length=500), nullable=True),
        sa.Column("country", sa.String(length=2), nullable=True),
        sa.Column("region", sa.String(length=80), nullable=True),
        sa.Column("position", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("starts_at", sa.DateTime(), nullable=True),
        sa.Column("ends_at", sa.DateTime(), nullable=True),
        sa.Column("created_by", sa.Integer(), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_home_banners_id", "home_banners", ["id"])
    op.create_index("ix_home_banners_country", "home_banners", ["country"])


def downgrade() -> None:
    op.drop_index("ix_home_banners_country", table_name="home_banners")
    op.drop_index("ix_home_banners_id", table_name="home_banners")
    op.drop_table("home_banners")
