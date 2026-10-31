"""outbox des évènements métier, relayés vers Kafka

Revision ID: 0003
Revises: 0002
Create Date: 2026-10-31 10:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


revision = '0003'
down_revision = '0002'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table('outbox_events',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('topic', sa.String(length=120), nullable=False),
    sa.Column('key', sa.String(length=120), nullable=True),
    sa.Column('event_type', sa.String(length=80), nullable=False),
    sa.Column('payload', sa.Text(), nullable=False),
    sa.Column('created_at', sa.DateTime(), nullable=False),
    sa.Column('published_at', sa.DateTime(), nullable=True),
    sa.Column('attempts', sa.Integer(), nullable=False),
    sa.Column('last_error', sa.String(length=500), nullable=True),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_outbox_events_id'), 'outbox_events', ['id'], unique=False)
    op.create_index(op.f('ix_outbox_events_created_at'), 'outbox_events', ['created_at'], unique=False)
    op.create_index(op.f('ix_outbox_events_published_at'), 'outbox_events', ['published_at'], unique=False)


def downgrade() -> None:
    op.drop_table('outbox_events')
