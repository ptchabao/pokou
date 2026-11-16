"""Signalements : messages joints chiffrés au repos, consentement daté.

`abuse_reports.recent_messages` (JSON en clair) est remplacée par
`recent_messages_encrypted` (jeton Fernet, clé REPORTS_ENCRYPTION_KEY) et
`messages_consent_at`. Les lignes existantes sont chiffrées si la clé est
présente au moment de la migration ; sinon leurs messages sont EFFACÉS
plutôt que gardés en clair.

Revision ID: 0025_reports_chiffres
Revises: 0024_honam_maquette
"""
import json

from alembic import op
import sqlalchemy as sa


revision = "0025_reports_chiffres"
down_revision = "0024_honam_maquette"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("abuse_reports") as batch:
        batch.add_column(sa.Column("recent_messages_encrypted", sa.Text(), nullable=True))
        batch.add_column(sa.Column("messages_consent_at", sa.DateTime(), nullable=True))

    from app.core.report_crypto import encrypt_messages

    bind = op.get_bind()
    rows = bind.execute(
        sa.text(
            "SELECT id, recent_messages, created_at FROM abuse_reports "
            "WHERE recent_messages IS NOT NULL"
        )
    ).fetchall()
    for report_id, raw, created_at in rows:
        messages = raw if isinstance(raw, list) else json.loads(raw or "null")
        token = encrypt_messages(messages) if messages else None
        if token is not None:
            # Joints avant cette version : le consentement était la feuille
            # elle-même, qui annonçait l'envoi ; on le date du signalement.
            bind.execute(
                sa.text(
                    "UPDATE abuse_reports SET recent_messages_encrypted = :t, "
                    "messages_consent_at = :c WHERE id = :i"
                ),
                {"t": token, "c": created_at, "i": report_id},
            )

    with op.batch_alter_table("abuse_reports") as batch:
        batch.drop_column("recent_messages")


def downgrade() -> None:
    # On ne redéchiffre pas vers une colonne en clair : le retour arrière
    # rend une colonne vide.
    with op.batch_alter_table("abuse_reports") as batch:
        batch.add_column(sa.Column("recent_messages", sa.JSON(), nullable=True))
        batch.drop_column("messages_consent_at")
        batch.drop_column("recent_messages_encrypted")
