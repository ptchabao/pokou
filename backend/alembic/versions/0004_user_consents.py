"""consentements de l'inscription : conditions, âge, statistiques, marketing

Revision ID: 0004
Revises: 0003
Create Date: 2026-10-31 12:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


revision = '0004'
down_revision = '0003'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('users', sa.Column('terms_accepted_at', sa.DateTime(), nullable=True))
    op.add_column('users', sa.Column('terms_version', sa.String(length=16), nullable=True))
    op.add_column('users', sa.Column('age_confirmed_at', sa.DateTime(), nullable=True))
    op.add_column('users', sa.Column('consent_analytics', sa.Boolean(), nullable=False, server_default=sa.false()))
    op.add_column('users', sa.Column('consent_marketing', sa.Boolean(), nullable=False, server_default=sa.false()))


def downgrade() -> None:
    for column in ('consent_marketing', 'consent_analytics', 'age_confirmed_at', 'terms_version', 'terms_accepted_at'):
        op.drop_column('users', column)
