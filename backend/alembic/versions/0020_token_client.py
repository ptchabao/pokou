"""Sessions : le type de client (app, web, console), pour « un seul téléphone ».

Revision ID: 0020_token_client
Revises: 0019_console_password
"""
from alembic import op
import sqlalchemy as sa


revision = "0020_token_client"
down_revision = "0019_console_password"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("tokens", sa.Column("client", sa.String(length=16), nullable=True))


def downgrade() -> None:
    op.drop_column("tokens", "client")
