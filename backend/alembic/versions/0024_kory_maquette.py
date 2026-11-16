"""Kory, maquette du 11 novembre 2026 : rappels d'une cotisation.

- `kory_members.reminders_muted` : le membre a coupé les rappels de cette
  cotisation (écran 21, « Rappels de cette cotisation »).
- `kory_pots.auto_reminder_key` : le dernier rappel automatique envoyé
  (« 2026-12:J-2 »), pour n'en envoyer qu'un par échéance et par étape.

Revision ID: 0024_kory_maquette
Revises: 0024_certified_pro_details
"""
from alembic import op
import sqlalchemy as sa


revision = "0024_kory_maquette"
down_revision = "0024_certified_pro_details"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("kory_members") as batch:
        batch.add_column(
            sa.Column("reminders_muted", sa.Boolean(), nullable=False, server_default=sa.false())
        )
    with op.batch_alter_table("kory_pots") as batch:
        batch.add_column(sa.Column("auto_reminder_key", sa.String(length=24), nullable=True))
        # Règle de levée : les tontines existantes restent sans valeur
        # (ancienne règle) ; les nouvelles reçoivent « ALL ».
        batch.add_column(sa.Column("levee_rule", sa.String(length=8), nullable=True))


def downgrade() -> None:
    with op.batch_alter_table("kory_pots") as batch:
        batch.drop_column("levee_rule")
        batch.drop_column("auto_reminder_key")
    with op.batch_alter_table("kory_members") as batch:
        batch.drop_column("reminders_muted")
