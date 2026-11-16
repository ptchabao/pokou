"""Assimé, maquette : état, prix à débattre, expiration et statistiques des
annonces ; bilan journalier des mises en avant ; réponse du vendeur aux
avis ; signalements et annonces masquées.

Les annonces déjà en ligne reçoivent 30 jours à partir de la migration :
les faire expirer d'un coup sur leur date de création viderait le marché.

Revision ID: 0026_assime_maquette
Revises: 0025_honam_canaux
"""
from datetime import datetime, timedelta

from alembic import op
import sqlalchemy as sa


revision = "0026_assime_maquette"
down_revision = "0025_honam_canaux"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("marketplace_products") as batch:
        batch.add_column(sa.Column("condition", sa.String(16), nullable=True))
        batch.add_column(sa.Column("negotiable", sa.Boolean(), nullable=False, server_default=sa.false()))
        batch.add_column(sa.Column("expires_at", sa.DateTime(), nullable=True))
        batch.add_column(sa.Column("views_count", sa.Integer(), nullable=False, server_default="0"))
        batch.add_column(sa.Column("contacts_count", sa.Integer(), nullable=False, server_default="0"))
        batch.create_index("ix_marketplace_products_condition", ["condition"])
        batch.create_index("ix_marketplace_products_expires_at", ["expires_at"])
    products = sa.table("marketplace_products", sa.column("expires_at", sa.DateTime()))
    op.execute(products.update().values(expires_at=datetime.utcnow() + timedelta(days=30)))

    with op.batch_alter_table("seller_reviews") as batch:
        batch.add_column(sa.Column("seller_reply", sa.String(500), nullable=True))
        batch.add_column(sa.Column("seller_replied_at", sa.DateTime(), nullable=True))

    with op.batch_alter_table("marketplace_boosts") as batch:
        batch.add_column(sa.Column("opens", sa.Integer(), nullable=False, server_default="0"))
        batch.add_column(sa.Column("contacts_before", sa.Integer(), nullable=False, server_default="0"))
        batch.add_column(sa.Column("daily", sa.JSON(), nullable=True))

    with op.batch_alter_table("marketplace_alerts") as batch:
        batch.add_column(sa.Column("paused", sa.Boolean(), nullable=False, server_default=sa.false()))

    op.create_table(
        "marketplace_reports",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("reporter_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("product_id", sa.Integer(), sa.ForeignKey("marketplace_products.id", ondelete="CASCADE"), nullable=True),
        sa.Column("review_id", sa.Integer(), sa.ForeignKey("seller_reviews.id", ondelete="CASCADE"), nullable=True),
        sa.Column("reason", sa.String(24), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.UniqueConstraint("reporter_id", "product_id", name="uq_marketplace_report_product"),
        sa.UniqueConstraint("reporter_id", "review_id", name="uq_marketplace_report_review"),
    )
    op.create_index("ix_marketplace_reports_id", "marketplace_reports", ["id"])
    op.create_index("ix_marketplace_reports_reporter_id", "marketplace_reports", ["reporter_id"])
    op.create_index("ix_marketplace_reports_product_id", "marketplace_reports", ["product_id"])
    op.create_index("ix_marketplace_reports_review_id", "marketplace_reports", ["review_id"])

    op.create_table(
        "marketplace_hidden",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("product_id", sa.Integer(), sa.ForeignKey("marketplace_products.id", ondelete="CASCADE"), nullable=True),
        sa.Column("seller_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_marketplace_hidden_id", "marketplace_hidden", ["id"])
    op.create_index("ix_marketplace_hidden_user_id", "marketplace_hidden", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_marketplace_hidden_user_id", table_name="marketplace_hidden")
    op.drop_index("ix_marketplace_hidden_id", table_name="marketplace_hidden")
    op.drop_table("marketplace_hidden")
    op.drop_index("ix_marketplace_reports_review_id", table_name="marketplace_reports")
    op.drop_index("ix_marketplace_reports_product_id", table_name="marketplace_reports")
    op.drop_index("ix_marketplace_reports_reporter_id", table_name="marketplace_reports")
    op.drop_index("ix_marketplace_reports_id", table_name="marketplace_reports")
    op.drop_table("marketplace_reports")
    with op.batch_alter_table("marketplace_alerts") as batch:
        batch.drop_column("paused")
    with op.batch_alter_table("marketplace_boosts") as batch:
        batch.drop_column("daily")
        batch.drop_column("contacts_before")
        batch.drop_column("opens")
    with op.batch_alter_table("seller_reviews") as batch:
        batch.drop_column("seller_replied_at")
        batch.drop_column("seller_reply")
    with op.batch_alter_table("marketplace_products") as batch:
        batch.drop_index("ix_marketplace_products_expires_at")
        batch.drop_index("ix_marketplace_products_condition")
        batch.drop_column("contacts_count")
        batch.drop_column("views_count")
        batch.drop_column("expires_at")
        batch.drop_column("negotiable")
        batch.drop_column("condition")
