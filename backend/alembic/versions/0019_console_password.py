"""Console d'administration : connexion par e-mail et mot de passe.

Réservée aux comptes de l'équipe (le compte super-administrateur créé au
déploiement n'a pas de téléphone pour recevoir un code SMS).

Revision ID: 0019_console_password
Revises: 0018_admin_space
"""
from alembic import op
import sqlalchemy as sa


revision = "0019_console_password"
down_revision = "0018_admin_space"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("console_password_hash", sa.String(length=100), nullable=True))
    op.add_column("users", sa.Column("console_failed_attempts", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("users", sa.Column("console_locked_until", sa.DateTime(), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "console_locked_until")
    op.drop_column("users", "console_failed_attempts")
    op.drop_column("users", "console_password_hash")
