"""Numéro de téléphone visible ou masqué, et « Supprimer la discussion » pour soi.

- `users.phone_visibility` : CONTACTS (défaut, le comportement d'avant pour
  les contacts) ou HIDDEN ;
- `phone_visibility_exceptions` : qui voit quand même un numéro masqué ;
- `direct_conversation_clears` : la date à partir de laquelle une personne
  ne veut plus voir une discussion à deux (le contenu, chiffré, n'est
  jamais sur le serveur en clair : seule une date y est écrite).

Revision ID: 0030_numero_masque_effacement
Revises: 0029_messages_epingles
"""
from alembic import op
import sqlalchemy as sa


revision = "0030_numero_masque_effacement"
down_revision = "0029_messages_epingles"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("users") as batch:
        batch.add_column(
            sa.Column(
                "phone_visibility",
                sa.String(16),
                nullable=False,
                server_default="CONTACTS",
            )
        )

    op.create_table(
        "phone_visibility_exceptions",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("owner_user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("allowed_user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.UniqueConstraint("owner_user_id", "allowed_user_id", name="uq_phone_visibility_exception"),
    )
    for column in ("owner_user_id", "allowed_user_id"):
        op.create_index(
            f"ix_phone_visibility_exceptions_{column}", "phone_visibility_exceptions", [column]
        )

    op.create_table(
        "direct_conversation_clears",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("other_user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("cleared_at", sa.DateTime(), nullable=False),
        sa.UniqueConstraint("user_id", "other_user_id", name="uq_direct_conversation_clear"),
    )
    for column in ("user_id", "other_user_id"):
        op.create_index(
            f"ix_direct_conversation_clears_{column}", "direct_conversation_clears", [column]
        )


def downgrade() -> None:
    for column in ("user_id", "other_user_id"):
        op.drop_index(f"ix_direct_conversation_clears_{column}", table_name="direct_conversation_clears")
    op.drop_table("direct_conversation_clears")
    for column in ("owner_user_id", "allowed_user_id"):
        op.drop_index(
            f"ix_phone_visibility_exceptions_{column}", table_name="phone_visibility_exceptions"
        )
    op.drop_table("phone_visibility_exceptions")
    with op.batch_alter_table("users") as batch:
        batch.drop_column("phone_visibility")
