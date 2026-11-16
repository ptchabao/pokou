"""Espace officine, maquettes p.93 et p.94 : recherche de coursier
(relance, rayon, annulation), retrait à l'officine, accusé de lecture des
messages, position du coursier disponible, et compte de l'officine
(prochaine garde, fermeture temporaire, nouveau wallet à vérifier,
sonnerie par téléphone du comptoir).

Revision ID: 0027_officine_coursier
Revises: 0026_assime_maquette
"""
from alembic import op
import sqlalchemy as sa


revision = "0027_officine_coursier"
down_revision = "0026_assime_maquette"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("honam_pharmacies") as batch:
        batch.add_column(sa.Column("next_duty_on", sa.Date(), nullable=True))
        batch.add_column(sa.Column("temporarily_closed_at", sa.DateTime(), nullable=True))
        batch.add_column(sa.Column("wallet_phone_pending", sa.String(32), nullable=True))

    with op.batch_alter_table("honam_pharmacy_staff") as batch:
        batch.add_column(sa.Column("ring_on_order", sa.Boolean(), nullable=False, server_default=sa.true()))
        batch.add_column(sa.Column("added_at", sa.DateTime(), nullable=True))

    with op.batch_alter_table("honam_orders") as batch:
        batch.add_column(sa.Column("dispatch_started_at", sa.DateTime(), nullable=True))
        batch.add_column(sa.Column("dispatch_radius_km", sa.Float(), nullable=True))
        batch.add_column(sa.Column("dispatch_cancelled_at", sa.DateTime(), nullable=True))
        batch.add_column(sa.Column("pickup_proposed_at", sa.DateTime(), nullable=True))
        batch.add_column(sa.Column("pickup_at_pharmacy", sa.Boolean(), nullable=False, server_default=sa.false()))

    with op.batch_alter_table("honam_order_messages") as batch:
        batch.add_column(sa.Column("read_at", sa.DateTime(), nullable=True))

    with op.batch_alter_table("honam_couriers") as batch:
        batch.add_column(sa.Column("latitude", sa.Float(), nullable=True))
        batch.add_column(sa.Column("longitude", sa.Float(), nullable=True))
        batch.add_column(sa.Column("located_at", sa.DateTime(), nullable=True))


def downgrade() -> None:
    with op.batch_alter_table("honam_couriers") as batch:
        batch.drop_column("located_at")
        batch.drop_column("longitude")
        batch.drop_column("latitude")

    with op.batch_alter_table("honam_order_messages") as batch:
        batch.drop_column("read_at")

    with op.batch_alter_table("honam_orders") as batch:
        batch.drop_column("pickup_at_pharmacy")
        batch.drop_column("pickup_proposed_at")
        batch.drop_column("dispatch_cancelled_at")
        batch.drop_column("dispatch_radius_km")
        batch.drop_column("dispatch_started_at")

    with op.batch_alter_table("honam_pharmacy_staff") as batch:
        batch.drop_column("added_at")
        batch.drop_column("ring_on_order")

    with op.batch_alter_table("honam_pharmacies") as batch:
        batch.drop_column("wallet_phone_pending")
        batch.drop_column("temporarily_closed_at")
        batch.drop_column("next_duty_on")
