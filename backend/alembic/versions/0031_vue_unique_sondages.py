"""Vue unique dans les groupes, réponse de sondage définitive après 15 minutes.

- `group_messages.view_once` : photo ou vidéo de groupe à vue unique ;
- `group_message_views` : qui l'a déjà ouverte (une fois par membre) ;
- `group_messages.poll_allows_multiple` : « une seule » ou « plusieurs »
  réponses, annoncé en clair par l'auteur d'un sondage de groupe (les choix,
  eux, restent chiffrés) ;
- `poll_vote_windows` : la date du PREMIER vote de chacun, qui ouvre sa
  fenêtre de modification de 15 minutes.

Aucun contenu de message : seulement des identifiants, des dates et des
drapeaux.

Revision ID: 0031_vue_unique_sondages
Revises: 0030_numero_masque_effacement
"""
from alembic import op
import sqlalchemy as sa


revision = "0031_vue_unique_sondages"
down_revision = "0030_numero_masque_effacement"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("group_messages") as batch:
        batch.add_column(
            sa.Column("view_once", sa.Boolean(), nullable=False, server_default=sa.false())
        )
        batch.add_column(sa.Column("poll_allows_multiple", sa.Boolean(), nullable=True))

    op.create_table(
        "group_message_views",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "message_id",
            sa.String(36),
            sa.ForeignKey("group_messages.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("viewed_at", sa.DateTime(), nullable=False),
        sa.UniqueConstraint("message_id", "user_id", name="uq_group_message_view"),
    )
    for column in ("message_id", "user_id"):
        op.create_index(f"ix_group_message_views_{column}", "group_message_views", [column])

    op.create_table(
        "poll_vote_windows",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("poll_key", sa.String(36), nullable=False),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("first_voted_at", sa.DateTime(), nullable=False),
        sa.UniqueConstraint("poll_key", "user_id", name="uq_poll_vote_window"),
    )
    for column in ("poll_key", "user_id"):
        op.create_index(f"ix_poll_vote_windows_{column}", "poll_vote_windows", [column])


def downgrade() -> None:
    for column in ("poll_key", "user_id"):
        op.drop_index(f"ix_poll_vote_windows_{column}", table_name="poll_vote_windows")
    op.drop_table("poll_vote_windows")
    for column in ("message_id", "user_id"):
        op.drop_index(f"ix_group_message_views_{column}", table_name="group_message_views")
    op.drop_table("group_message_views")
    with op.batch_alter_table("group_messages") as batch:
        batch.drop_column("poll_allows_multiple")
        batch.drop_column("view_once")
