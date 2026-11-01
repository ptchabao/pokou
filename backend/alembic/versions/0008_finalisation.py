"""finalisation : mode preuve à deux, Pokou certifié Pro, suivi et parrainage Honam, favoris et alertes Assimé, tontine Kory Plus

Revision ID: 0008
Revises: 0007
Create Date: 2026-11-01 07:35:03.245801

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '0008'
down_revision = '0007'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table('direct_proof_modes',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('user_low_id', sa.Integer(), nullable=False),
    sa.Column('user_high_id', sa.Integer(), nullable=False),
    sa.Column('enabled_by', sa.Integer(), nullable=True),
    sa.Column('since', sa.DateTime(), nullable=False),
    sa.ForeignKeyConstraint(['enabled_by'], ['users.id'], ondelete='SET NULL'),
    sa.ForeignKeyConstraint(['user_high_id'], ['users.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['user_low_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('user_low_id', 'user_high_id', name='uq_direct_proof_pair')
    )
    with op.batch_alter_table('direct_proof_modes', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_direct_proof_modes_id'), ['id'], unique=False)
        batch_op.create_index(batch_op.f('ix_direct_proof_modes_user_high_id'), ['user_high_id'], unique=False)
        batch_op.create_index(batch_op.f('ix_direct_proof_modes_user_low_id'), ['user_low_id'], unique=False)

    op.create_table('honam_waitlist',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('user_id', sa.Integer(), nullable=False),
    sa.Column('country', sa.String(length=2), nullable=False),
    sa.Column('city', sa.String(length=80), nullable=False),
    sa.Column('role', sa.String(length=8), nullable=False),
    sa.Column('created_at', sa.DateTime(), nullable=False),
    sa.Column('notified_at', sa.DateTime(), nullable=True),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('user_id', 'role', name='uq_waitlist_user_role')
    )
    with op.batch_alter_table('honam_waitlist', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_honam_waitlist_city'), ['city'], unique=False)
        batch_op.create_index(batch_op.f('ix_honam_waitlist_country'), ['country'], unique=False)
        batch_op.create_index(batch_op.f('ix_honam_waitlist_id'), ['id'], unique=False)
        batch_op.create_index(batch_op.f('ix_honam_waitlist_user_id'), ['user_id'], unique=False)

    op.create_table('marketplace_alerts',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('user_id', sa.Integer(), nullable=False),
    sa.Column('query', sa.String(length=120), nullable=True),
    sa.Column('category', sa.String(length=64), nullable=True),
    sa.Column('location', sa.String(length=255), nullable=True),
    sa.Column('max_price', sa.Integer(), nullable=True),
    sa.Column('created_at', sa.DateTime(), nullable=False),
    sa.Column('last_matched_at', sa.DateTime(), nullable=True),
    sa.Column('matches_count', sa.Integer(), nullable=False, server_default='0'),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    with op.batch_alter_table('marketplace_alerts', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_marketplace_alerts_id'), ['id'], unique=False)
        batch_op.create_index(batch_op.f('ix_marketplace_alerts_user_id'), ['user_id'], unique=False)

    op.create_table('certified_pro_applications',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('user_id', sa.Integer(), nullable=False),
    sa.Column('business_name', sa.String(length=160), nullable=False),
    sa.Column('activity', sa.String(length=120), nullable=False),
    sa.Column('city', sa.String(length=80), nullable=True),
    sa.Column('document_media_id', sa.Integer(), nullable=True),
    sa.Column('status', sa.String(length=12), nullable=False),
    sa.Column('review_note', sa.String(length=500), nullable=True),
    sa.Column('submitted_at', sa.DateTime(), nullable=False),
    sa.Column('review_due_at', sa.DateTime(), nullable=False),
    sa.Column('reviewed_at', sa.DateTime(), nullable=True),
    sa.Column('reviewer_id', sa.Integer(), nullable=True),
    sa.ForeignKeyConstraint(['document_media_id'], ['media_assets.id'], ondelete='SET NULL'),
    sa.ForeignKeyConstraint(['reviewer_id'], ['users.id'], ondelete='SET NULL'),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    with op.batch_alter_table('certified_pro_applications', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_certified_pro_applications_id'), ['id'], unique=False)
        batch_op.create_index(batch_op.f('ix_certified_pro_applications_status'), ['status'], unique=False)
        batch_op.create_index(batch_op.f('ix_certified_pro_applications_user_id'), ['user_id'], unique=True)

    op.create_table('honam_pharmacy_couriers',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('pharmacy_id', sa.Integer(), nullable=False),
    sa.Column('courier_id', sa.Integer(), nullable=False),
    sa.Column('added_at', sa.DateTime(), nullable=False),
    sa.ForeignKeyConstraint(['courier_id'], ['honam_couriers.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['pharmacy_id'], ['honam_pharmacies.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('pharmacy_id', 'courier_id', name='uq_pharmacy_courier')
    )
    with op.batch_alter_table('honam_pharmacy_couriers', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_honam_pharmacy_couriers_courier_id'), ['courier_id'], unique=False)
        batch_op.create_index(batch_op.f('ix_honam_pharmacy_couriers_id'), ['id'], unique=False)
        batch_op.create_index(batch_op.f('ix_honam_pharmacy_couriers_pharmacy_id'), ['pharmacy_id'], unique=False)

    op.create_table('marketplace_favorites',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('user_id', sa.Integer(), nullable=False),
    sa.Column('product_id', sa.Integer(), nullable=False),
    sa.Column('created_at', sa.DateTime(), nullable=False),
    sa.ForeignKeyConstraint(['product_id'], ['marketplace_products.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('user_id', 'product_id', name='uq_marketplace_favorite')
    )
    with op.batch_alter_table('marketplace_favorites', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_marketplace_favorites_id'), ['id'], unique=False)
        batch_op.create_index(batch_op.f('ix_marketplace_favorites_product_id'), ['product_id'], unique=False)
        batch_op.create_index(batch_op.f('ix_marketplace_favorites_user_id'), ['user_id'], unique=False)

    op.create_table('kory_rounds',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('pot_id', sa.Integer(), nullable=False),
    sa.Column('number', sa.Integer(), nullable=False),
    sa.Column('beneficiary_id', sa.Integer(), nullable=False),
    sa.Column('due_at', sa.DateTime(), nullable=True),
    sa.Column('status', sa.String(length=10), nullable=False),
    sa.Column('closed_at', sa.DateTime(), nullable=True),
    sa.ForeignKeyConstraint(['beneficiary_id'], ['users.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['pot_id'], ['kory_pots.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    with op.batch_alter_table('kory_rounds', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_kory_rounds_beneficiary_id'), ['beneficiary_id'], unique=False)
        batch_op.create_index(batch_op.f('ix_kory_rounds_id'), ['id'], unique=False)
        batch_op.create_index(batch_op.f('ix_kory_rounds_pot_id'), ['pot_id'], unique=False)

    with op.batch_alter_table('direct_messages', schema=None) as batch_op:
        batch_op.add_column(sa.Column('proof_mode', sa.Boolean(), nullable=False, server_default=sa.false()))
        batch_op.add_column(sa.Column('deleted_at', sa.DateTime(), nullable=True))
        batch_op.add_column(sa.Column('original_content', sa.Text(), nullable=True))

    with op.batch_alter_table('honam_couriers', schema=None) as batch_op:
        batch_op.add_column(sa.Column('city', sa.String(length=80), nullable=True))
        batch_op.add_column(sa.Column('referral_code', sa.String(length=12), nullable=True))
        batch_op.add_column(sa.Column('referred_by_id', sa.Integer(), nullable=True))
        batch_op.add_column(sa.Column('referral_rewarded_at', sa.DateTime(), nullable=True))
        batch_op.create_index(batch_op.f('ix_honam_couriers_referral_code'), ['referral_code'], unique=True)

    with op.batch_alter_table('honam_orders', schema=None) as batch_op:
        batch_op.add_column(sa.Column('courier_latitude', sa.Float(), nullable=True))
        batch_op.add_column(sa.Column('courier_longitude', sa.Float(), nullable=True))
        batch_op.add_column(sa.Column('courier_location_at', sa.DateTime(), nullable=True))

    with op.batch_alter_table('kory_entries', schema=None) as batch_op:
        batch_op.add_column(sa.Column('round_number', sa.Integer(), nullable=True))
        batch_op.create_index(batch_op.f('ix_kory_entries_round_number'), ['round_number'], unique=False)

    with op.batch_alter_table('marketplace_boosts', schema=None) as batch_op:
        batch_op.add_column(sa.Column('days', sa.Integer(), nullable=True))
        batch_op.add_column(sa.Column('status_moderation', sa.String(length=10), nullable=True))
        batch_op.add_column(sa.Column('city', sa.String(length=80), nullable=True))
        batch_op.add_column(sa.Column('impressions', sa.Integer(), nullable=False, server_default='0'))
        batch_op.add_column(sa.Column('status_views', sa.Integer(), nullable=False, server_default='0'))
        batch_op.add_column(sa.Column('contacts', sa.Integer(), nullable=False, server_default='0'))
        batch_op.create_index(batch_op.f('ix_marketplace_boosts_city'), ['city'], unique=False)
        batch_op.create_index(batch_op.f('ix_marketplace_boosts_status_moderation'), ['status_moderation'], unique=False)

    # La clé étrangère du parrain n'est posée que sur PostgreSQL : SQLite ne
    # sait pas l'ajouter à une table existante sans la recréer (voir 0005).
    if op.get_bind().dialect.name == 'postgresql':
        op.create_foreign_key(
            'fk_honam_couriers_referred_by', 'honam_couriers', 'honam_couriers',
            ['referred_by_id'], ['id'], ondelete='SET NULL',
        )


def downgrade() -> None:
    if op.get_bind().dialect.name == 'postgresql':
        op.drop_constraint('fk_honam_couriers_referred_by', 'honam_couriers', type_='foreignkey')

    with op.batch_alter_table('marketplace_boosts', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_marketplace_boosts_status_moderation'))
        batch_op.drop_index(batch_op.f('ix_marketplace_boosts_city'))
        batch_op.drop_column('contacts')
        batch_op.drop_column('status_views')
        batch_op.drop_column('impressions')
        batch_op.drop_column('city')
        batch_op.drop_column('status_moderation')
        batch_op.drop_column('days')

    with op.batch_alter_table('kory_entries', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_kory_entries_round_number'))
        batch_op.drop_column('round_number')

    with op.batch_alter_table('honam_orders', schema=None) as batch_op:
        batch_op.drop_column('courier_location_at')
        batch_op.drop_column('courier_longitude')
        batch_op.drop_column('courier_latitude')

    with op.batch_alter_table('honam_couriers', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_honam_couriers_referral_code'))
        batch_op.drop_column('referral_rewarded_at')
        batch_op.drop_column('referred_by_id')
        batch_op.drop_column('referral_code')
        batch_op.drop_column('city')

    with op.batch_alter_table('direct_messages', schema=None) as batch_op:
        batch_op.drop_column('original_content')
        batch_op.drop_column('deleted_at')
        batch_op.drop_column('proof_mode')

    with op.batch_alter_table('kory_rounds', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_kory_rounds_pot_id'))
        batch_op.drop_index(batch_op.f('ix_kory_rounds_id'))
        batch_op.drop_index(batch_op.f('ix_kory_rounds_beneficiary_id'))

    op.drop_table('kory_rounds')
    with op.batch_alter_table('marketplace_favorites', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_marketplace_favorites_user_id'))
        batch_op.drop_index(batch_op.f('ix_marketplace_favorites_product_id'))
        batch_op.drop_index(batch_op.f('ix_marketplace_favorites_id'))

    op.drop_table('marketplace_favorites')
    with op.batch_alter_table('honam_pharmacy_couriers', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_honam_pharmacy_couriers_pharmacy_id'))
        batch_op.drop_index(batch_op.f('ix_honam_pharmacy_couriers_id'))
        batch_op.drop_index(batch_op.f('ix_honam_pharmacy_couriers_courier_id'))

    op.drop_table('honam_pharmacy_couriers')
    with op.batch_alter_table('certified_pro_applications', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_certified_pro_applications_user_id'))
        batch_op.drop_index(batch_op.f('ix_certified_pro_applications_status'))
        batch_op.drop_index(batch_op.f('ix_certified_pro_applications_id'))

    op.drop_table('certified_pro_applications')
    with op.batch_alter_table('marketplace_alerts', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_marketplace_alerts_user_id'))
        batch_op.drop_index(batch_op.f('ix_marketplace_alerts_id'))

    op.drop_table('marketplace_alerts')
    with op.batch_alter_table('honam_waitlist', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_honam_waitlist_user_id'))
        batch_op.drop_index(batch_op.f('ix_honam_waitlist_id'))
        batch_op.drop_index(batch_op.f('ix_honam_waitlist_country'))
        batch_op.drop_index(batch_op.f('ix_honam_waitlist_city'))

    op.drop_table('honam_waitlist')
    with op.batch_alter_table('direct_proof_modes', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_direct_proof_modes_user_low_id'))
        batch_op.drop_index(batch_op.f('ix_direct_proof_modes_user_high_id'))
        batch_op.drop_index(batch_op.f('ix_direct_proof_modes_id'))

    op.drop_table('direct_proof_modes')
