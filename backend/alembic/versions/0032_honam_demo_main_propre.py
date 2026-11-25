"""Honam : officines de démonstration ; Assimé : vente en main propre.

- `honam_pharmacies.is_demo` : les officines « Démo » créées par le seed
  pour les testeurs, visibles seulement là où le pays l'autorise.
- `marketplace_handovers` : la remise en main propre d'un article Assimé,
  close par le code que l'acheteur donne au vendeur.

Revision ID: 0032_honam_demo_main_propre
Revises: 0031_kory_archives, 0031_vue_unique_sondages
(fusionne les deux branches 0031 : une seule tête)
"""
from alembic import op
import sqlalchemy as sa


revision = "0032_honam_demo_main_propre"
down_revision = ("0031_kory_archives", "0031_vue_unique_sondages")
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("honam_pharmacies") as batch:
        batch.add_column(sa.Column("is_demo", sa.Boolean(), nullable=False, server_default=sa.false()))
    op.create_table(
        "marketplace_handovers",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("product_id", sa.Integer(), sa.ForeignKey("marketplace_products.id", ondelete="CASCADE"), nullable=False),
        sa.Column("seller_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("buyer_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("code", sa.String(6), nullable=True),
        sa.Column("final_price", sa.Integer(), nullable=True),
        sa.Column("status", sa.String(10), nullable=False, server_default="PENDING"),
        sa.Column("attempts", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("expires_at", sa.DateTime(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("closed_at", sa.DateTime(), nullable=True),
    )
    for column in ("id", "product_id", "seller_id", "buyer_id", "status"):
        op.create_index(f"ix_marketplace_handovers_{column}", "marketplace_handovers", [column])


def downgrade() -> None:
    for column in ("id", "product_id", "seller_id", "buyer_id", "status"):
        op.drop_index(f"ix_marketplace_handovers_{column}", table_name="marketplace_handovers")
    op.drop_table("marketplace_handovers")
    with op.batch_alter_table("honam_pharmacies") as batch:
        batch.drop_column("is_demo")
