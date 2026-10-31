"""kory : cagnottes et cotisations tenues en journal

Revision ID: 0002
Revises: 0001
Create Date: 2026-10-31 08:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


revision = '0002'
down_revision = '0001'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table('kory_pots',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('group_id', sa.Integer(), nullable=True),
    sa.Column('organizer_id', sa.Integer(), nullable=False),
    sa.Column('collector_id', sa.Integer(), nullable=False),
    sa.Column('kind', sa.String(length=12), nullable=False),
    sa.Column('title', sa.String(length=120), nullable=False),
    sa.Column('description', sa.String(length=500), nullable=True),
    sa.Column('goal_amount', sa.Integer(), nullable=True),
    sa.Column('amount_per_member', sa.Integer(), nullable=True),
    sa.Column('period', sa.String(length=8), nullable=True),
    sa.Column('due_at', sa.DateTime(), nullable=True),
    sa.Column('join_code', sa.String(length=12), nullable=False),
    sa.Column('status', sa.String(length=8), nullable=False),
    sa.Column('created_at', sa.DateTime(), nullable=False),
    sa.Column('closed_at', sa.DateTime(), nullable=True),
    sa.ForeignKeyConstraint(['collector_id'], ['users.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['group_id'], ['groups.id'], ondelete='SET NULL'),
    sa.ForeignKeyConstraint(['organizer_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_kory_pots_id'), 'kory_pots', ['id'], unique=False)
    op.create_index(op.f('ix_kory_pots_group_id'), 'kory_pots', ['group_id'], unique=False)
    op.create_index(op.f('ix_kory_pots_organizer_id'), 'kory_pots', ['organizer_id'], unique=False)
    op.create_index(op.f('ix_kory_pots_collector_id'), 'kory_pots', ['collector_id'], unique=False)
    op.create_index(op.f('ix_kory_pots_join_code'), 'kory_pots', ['join_code'], unique=True)
    op.create_index(op.f('ix_kory_pots_status'), 'kory_pots', ['status'], unique=False)
    op.create_table('kory_members',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('pot_id', sa.Integer(), nullable=False),
    sa.Column('user_id', sa.Integer(), nullable=False),
    sa.Column('joined_at', sa.DateTime(), nullable=False),
    sa.ForeignKeyConstraint(['pot_id'], ['kory_pots.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_kory_members_id'), 'kory_members', ['id'], unique=False)
    op.create_index(op.f('ix_kory_members_pot_id'), 'kory_members', ['pot_id'], unique=False)
    op.create_index(op.f('ix_kory_members_user_id'), 'kory_members', ['user_id'], unique=False)
    op.create_table('kory_entries',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('pot_id', sa.Integer(), nullable=False),
    sa.Column('contributor_id', sa.Integer(), nullable=False),
    sa.Column('amount', sa.Integer(), nullable=False),
    sa.Column('wallet_reference', sa.String(length=64), nullable=True),
    sa.Column('period_label', sa.String(length=12), nullable=True),
    sa.Column('note', sa.String(length=280), nullable=True),
    sa.Column('status', sa.String(length=10), nullable=False),
    sa.Column('declared_at', sa.DateTime(), nullable=False),
    sa.Column('reviewed_at', sa.DateTime(), nullable=True),
    sa.ForeignKeyConstraint(['contributor_id'], ['users.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['pot_id'], ['kory_pots.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_kory_entries_id'), 'kory_entries', ['id'], unique=False)
    op.create_index(op.f('ix_kory_entries_pot_id'), 'kory_entries', ['pot_id'], unique=False)
    op.create_index(op.f('ix_kory_entries_contributor_id'), 'kory_entries', ['contributor_id'], unique=False)
    op.create_index(op.f('ix_kory_entries_status'), 'kory_entries', ['status'], unique=False)


def downgrade() -> None:
    op.drop_table('kory_entries')
    op.drop_table('kory_members')
    op.drop_table('kory_pots')
