"""Kory : ce que la maquette demande en plus (bénéficiaire, visibilité des
montants, membres choisis, co-organisateur, pause et fin d'une cotisation,
tirage scellé, acceptation, échange de mois et dissolution d'une tontine).

Revision ID: 0022_kory_mockup
Revises: 0021_home_banners
"""
from alembic import op
import sqlalchemy as sa


revision = "0022_kory_mockup"
down_revision = "0021_home_banners"
branch_labels = None
depends_on = None


_POT_COLUMNS = [
    sa.Column("beneficiary_name", sa.String(length=120), nullable=True),
    sa.Column("amounts_visible", sa.Boolean(), nullable=False, server_default=sa.true()),
    sa.Column("members_selected", sa.Boolean(), nullable=False, server_default=sa.false()),
    sa.Column("deputy_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="SET NULL", name="fk_kory_pots_deputy_id"), nullable=True),
    sa.Column("ends_at", sa.DateTime(), nullable=True),
    sa.Column("paused_period", sa.String(length=12), nullable=True),
    sa.Column("next_amount", sa.Integer(), nullable=True),
    sa.Column("next_amount_from", sa.String(length=12), nullable=True),
    sa.Column("draw_mode", sa.String(length=8), nullable=True),
    sa.Column("draw_seal", sa.String(length=16), nullable=True),
    sa.Column("drawn_at", sa.DateTime(), nullable=True),
    sa.Column("dissolved_at", sa.DateTime(), nullable=True),
    sa.Column("dissolve_reason", sa.String(length=280), nullable=True),
    sa.Column("reminded_at", sa.DateTime(), nullable=True),
]

_MEMBER_COLUMNS = [
    sa.Column("accepted_at", sa.DateTime(), nullable=True),
    sa.Column("declined_at", sa.DateTime(), nullable=True),
    sa.Column("position", sa.Integer(), nullable=True),
]


def upgrade() -> None:
    with op.batch_alter_table("kory_pots") as batch:
        # QUARTERLY et BIWEEKLY ne tiennent pas en 8 caractères.
        batch.alter_column("period", type_=sa.String(length=10), existing_type=sa.String(length=8))
        for column in _POT_COLUMNS:
            batch.add_column(column)
    with op.batch_alter_table("kory_members") as batch:
        for column in _MEMBER_COLUMNS:
            batch.add_column(column)
    op.create_table(
        "kory_swaps",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("pot_id", sa.Integer(), sa.ForeignKey("kory_pots.id", ondelete="CASCADE"), nullable=False),
        sa.Column("requester_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("target_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("requester_round", sa.Integer(), nullable=False),
        sa.Column("target_round", sa.Integer(), nullable=False),
        sa.Column("message", sa.String(length=280), nullable=True),
        sa.Column("status", sa.String(length=10), nullable=False, server_default="PENDING"),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column("decided_at", sa.DateTime(), nullable=True),
    )
    op.create_index("ix_kory_swaps_id", "kory_swaps", ["id"])
    op.create_index("ix_kory_swaps_pot_id", "kory_swaps", ["pot_id"])
    op.create_index("ix_kory_swaps_status", "kory_swaps", ["status"])


def downgrade() -> None:
    op.drop_index("ix_kory_swaps_status", table_name="kory_swaps")
    op.drop_index("ix_kory_swaps_pot_id", table_name="kory_swaps")
    op.drop_index("ix_kory_swaps_id", table_name="kory_swaps")
    op.drop_table("kory_swaps")
    with op.batch_alter_table("kory_members") as batch:
        for column in reversed(_MEMBER_COLUMNS):
            batch.drop_column(column.name)
    with op.batch_alter_table("kory_pots") as batch:
        for column in reversed(_POT_COLUMNS):
            batch.drop_column(column.name)
        batch.alter_column("period", type_=sa.String(length=8), existing_type=sa.String(length=10))
