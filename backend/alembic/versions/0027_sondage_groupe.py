"""Sondages dans les discussions de groupe : un vote chiffré par membre.

La question et les réponses voyagent chiffrées dans le message de groupe
(type POLL) ; seule la table des votes est nouvelle, et elle ne tient que des
chiffrés (voir models/groups.py::GroupPollVote).

Revision ID: 0027_sondage_groupe
Revises: 0026_assime_maquette
"""
from alembic import op
import sqlalchemy as sa


revision = "0027_sondage_groupe"
down_revision = "0026_assime_maquette"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "group_poll_votes",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "message_id",
            sa.String(36),
            sa.ForeignKey("group_messages.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("voter_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("encryption", sa.String(24), nullable=False),
        sa.Column("ciphertext", sa.Text(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.UniqueConstraint("message_id", "voter_id", name="uq_group_poll_vote"),
    )
    op.create_index("ix_group_poll_votes_id", "group_poll_votes", ["id"])
    op.create_index("ix_group_poll_votes_message_id", "group_poll_votes", ["message_id"])
    op.create_index("ix_group_poll_votes_voter_id", "group_poll_votes", ["voter_id"])


def downgrade() -> None:
    op.drop_index("ix_group_poll_votes_voter_id", table_name="group_poll_votes")
    op.drop_index("ix_group_poll_votes_message_id", table_name="group_poll_votes")
    op.drop_index("ix_group_poll_votes_id", table_name="group_poll_votes")
    op.drop_table("group_poll_votes")
