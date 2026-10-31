"""Pokou certifié et mode preuve

Revision ID: 0005
Revises: 0004
Create Date: 2026-10-31 13:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


revision = '0005'
down_revision = '0004'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table('certified_subscriptions',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('user_id', sa.Integer(), nullable=False),
    sa.Column('plan', sa.String(length=24), nullable=False),
    sa.Column('status', sa.String(length=16), nullable=False),
    sa.Column('trial_ends_at', sa.DateTime(), nullable=True),
    sa.Column('current_period_end', sa.DateTime(), nullable=True),
    sa.Column('wallet_holder_name', sa.String(length=160), nullable=True),
    sa.Column('first_paid_at', sa.DateTime(), nullable=True),
    sa.Column('badge_granted', sa.Boolean(), nullable=False, server_default=sa.false()),
    sa.Column('created_at', sa.DateTime(), nullable=False),
    sa.Column('updated_at', sa.DateTime(), nullable=False),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_certified_subscriptions_id'), 'certified_subscriptions', ['id'], unique=False)
    op.create_index(op.f('ix_certified_subscriptions_user_id'), 'certified_subscriptions', ['user_id'], unique=True)
    op.create_index(op.f('ix_certified_subscriptions_status'), 'certified_subscriptions', ['status'], unique=False)
    op.add_column('groups', sa.Column('proof_mode', sa.Boolean(), nullable=False, server_default=sa.false()))
    op.add_column('groups', sa.Column('proof_mode_since', sa.DateTime(), nullable=True))
    op.add_column('groups', sa.Column('proof_mode_by', sa.Integer(), nullable=True))
    op.add_column('group_messages', sa.Column('deleted_at', sa.DateTime(), nullable=True))
    op.add_column('group_messages', sa.Column('deleted_by', sa.Integer(), nullable=True))
    # SQLite n'ajoute pas de clé étrangère par ALTER : la contrainte n'est
    # posée qu'en PostgreSQL, la base de production.
    if op.get_bind().dialect.name == 'postgresql':
        op.create_foreign_key('fk_groups_proof_mode_by', 'groups', 'users', ['proof_mode_by'], ['id'], ondelete='SET NULL')
        op.create_foreign_key('fk_group_messages_deleted_by', 'group_messages', 'users', ['deleted_by'], ['id'], ondelete='SET NULL')


def downgrade() -> None:
    if op.get_bind().dialect.name == 'postgresql':
        op.drop_constraint('fk_group_messages_deleted_by', 'group_messages', type_='foreignkey')
        op.drop_constraint('fk_groups_proof_mode_by', 'groups', type_='foreignkey')
    op.drop_column('group_messages', 'deleted_by')
    op.drop_column('group_messages', 'deleted_at')
    op.drop_column('groups', 'proof_mode_by')
    op.drop_column('groups', 'proof_mode_since')
    op.drop_column('groups', 'proof_mode')
    op.drop_table('certified_subscriptions')
