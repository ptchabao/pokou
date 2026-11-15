"""Honam, conformité à la maquette : repère d'adresse, référence de paiement,
produit manquant daté, incidents de course, inscription coursier en 6 étapes
(identité, zones et créneaux, wallet vérifié, quiz), disponibilité, défauts
datés et contestables.

Revision ID: 0024_honam_maquette
Revises: 0023_kory_plus_fee
"""
from alembic import op
import sqlalchemy as sa


revision = "0024_honam_maquette"
down_revision = "0023_kory_plus_fee"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("honam_orders") as batch:
        batch.add_column(sa.Column("delivery_landmark", sa.String(255), nullable=True))
        batch.add_column(sa.Column("original_returned_at", sa.DateTime(), nullable=True))
        batch.add_column(sa.Column("code_attempts", sa.Integer(), nullable=False, server_default="0"))
        batch.add_column(sa.Column("missing_reported_at", sa.DateTime(), nullable=True))
        batch.add_column(sa.Column("payment_reference", sa.String(64), nullable=True))
        batch.add_column(sa.Column("incident_kind", sa.String(10), nullable=True))
        batch.add_column(sa.Column("incident_at", sa.DateTime(), nullable=True))

    with op.batch_alter_table("honam_couriers") as batch:
        batch.add_column(sa.Column("zones_list", sa.JSON(), nullable=True))
        batch.add_column(sa.Column("days", sa.JSON(), nullable=True))
        batch.add_column(sa.Column("moments", sa.JSON(), nullable=True))
        batch.add_column(sa.Column("birth_date", sa.Date(), nullable=True))
        batch.add_column(sa.Column("transport", sa.String(6), nullable=True))
        batch.add_column(sa.Column("id_doc_type", sa.String(10), nullable=True))
        batch.add_column(sa.Column("id_front_media_id", sa.Integer(), nullable=True))
        batch.add_column(sa.Column("id_back_media_id", sa.Integer(), nullable=True))
        batch.add_column(sa.Column("selfie_media_id", sa.Integer(), nullable=True))
        batch.add_column(sa.Column("incomplete_item", sa.String(10), nullable=True))
        batch.add_column(sa.Column("incomplete_reason", sa.String(255), nullable=True))
        batch.add_column(sa.Column("quiz_passed_at", sa.DateTime(), nullable=True))
        batch.add_column(sa.Column("wallet_verified_at", sa.DateTime(), nullable=True))
        batch.add_column(sa.Column("review_requested_at", sa.DateTime(), nullable=True))
        batch.add_column(sa.Column("available", sa.Boolean(), nullable=False, server_default=sa.false()))
        batch.add_column(sa.Column("welcomed_at", sa.DateTime(), nullable=True))

    op.create_table(
        "honam_courier_defaults",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("courier_id", sa.Integer(), sa.ForeignKey("honam_couriers.id", ondelete="CASCADE"), nullable=False),
        sa.Column("order_id", sa.Integer(), sa.ForeignKey("honam_orders.id", ondelete="SET NULL"), nullable=True),
        sa.Column("pharmacy_id", sa.Integer(), sa.ForeignKey("honam_pharmacies.id", ondelete="SET NULL"), nullable=True),
        sa.Column("reason", sa.String(255), nullable=False),
        sa.Column("status", sa.String(10), nullable=False, server_default="CONFIRMED"),
        sa.Column("contest_until", sa.DateTime(), nullable=False),
        sa.Column("contested_at", sa.DateTime(), nullable=True),
        sa.Column("contest_note", sa.String(500), nullable=True),
        sa.Column("acknowledged_at", sa.DateTime(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_honam_courier_defaults_id", "honam_courier_defaults", ["id"])
    op.create_index("ix_honam_courier_defaults_courier_id", "honam_courier_defaults", ["courier_id"])
    op.create_index("ix_honam_courier_defaults_created_at", "honam_courier_defaults", ["created_at"])

    op.create_table(
        "honam_wallet_checks",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("phone", sa.String(32), nullable=False),
        sa.Column("verified_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_honam_wallet_checks_id", "honam_wallet_checks", ["id"])
    op.create_index("ix_honam_wallet_checks_user_id", "honam_wallet_checks", ["user_id"])

    op.create_table(
        "honam_courier_offer_dismissals",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("dismissed_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_honam_courier_offer_dismissals_id", "honam_courier_offer_dismissals", ["id"])
    op.create_index(
        "ix_honam_courier_offer_dismissals_user_id", "honam_courier_offer_dismissals", ["user_id"], unique=True,
    )


def downgrade() -> None:
    op.drop_table("honam_courier_offer_dismissals")
    op.drop_table("honam_wallet_checks")
    op.drop_table("honam_courier_defaults")
    with op.batch_alter_table("honam_couriers") as batch:
        for column in (
            "welcomed_at", "available", "review_requested_at", "wallet_verified_at", "quiz_passed_at",
            "incomplete_reason", "incomplete_item", "selfie_media_id", "id_back_media_id",
            "id_front_media_id", "id_doc_type", "transport", "birth_date", "moments", "days", "zones_list",
        ):
            batch.drop_column(column)
    with op.batch_alter_table("honam_orders") as batch:
        for column in (
            "incident_at", "incident_kind", "payment_reference", "missing_reported_at",
            "code_attempts", "original_returned_at", "delivery_landmark",
        ):
            batch.drop_column(column)
