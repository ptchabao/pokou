"""Honam : les messages d'une commande portent un canal (patient, coursier,
livraison). Les messages existants, sans canal, vont dans « patient ».

Revision ID: 0025_honam_canaux
Revises: 0025_reports_chiffres
"""
from alembic import op
import sqlalchemy as sa


revision = "0025_honam_canaux"
down_revision = "0025_reports_chiffres"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("honam_order_messages") as batch:
        batch.add_column(sa.Column("channel", sa.String(length=10), nullable=False, server_default="patient"))
        batch.add_column(sa.Column(
            "courier_id", sa.Integer(),
            sa.ForeignKey("users.id", ondelete="SET NULL", name="fk_honam_order_messages_courier_id"),
            nullable=True,
        ))
        batch.create_index("ix_honam_order_messages_channel", ["channel"])
    # Les messages d'avant les canaux : le fil commun devient celui de la
    # patiente et de l'officine (le défaut de la colonne s'en charge déjà).
    op.execute("UPDATE honam_order_messages SET channel = 'patient' WHERE channel IS NULL")


def downgrade() -> None:
    with op.batch_alter_table("honam_order_messages") as batch:
        batch.drop_index("ix_honam_order_messages_channel")
        batch.drop_column("courier_id")
        batch.drop_column("channel")
