"""Rôles de la console modifiables (RBAC) : table admin_roles, et le rôle
créé par l'équipe d'un membre (users.admin_role_id).

Revision ID: 0034_admin_roles
Revises: 0033_store_review_account
"""
import sqlalchemy as sa
from alembic import op

revision = "0034_admin_roles"
down_revision = "0033_store_review_account"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "admin_roles",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("key", sa.String(length=60), nullable=False),
        sa.Column("label", sa.String(length=80), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("permissions", sa.JSON(), nullable=False),
        sa.Column("is_system", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_admin_roles_key", "admin_roles", ["key"], unique=True)
    op.create_index("ix_admin_roles_id", "admin_roles", ["id"])
    with op.batch_alter_table("users") as batch:
        batch.add_column(sa.Column("admin_role_id", sa.Integer(), nullable=True))
        batch.create_foreign_key(
            "fk_users_admin_role_id", "admin_roles", ["admin_role_id"], ["id"], ondelete="SET NULL"
        )


def downgrade() -> None:
    with op.batch_alter_table("users") as batch:
        batch.drop_constraint("fk_users_admin_role_id", type_="foreignkey")
        batch.drop_column("admin_role_id")
    op.drop_index("ix_admin_roles_id", table_name="admin_roles")
    op.drop_index("ix_admin_roles_key", table_name="admin_roles")
    op.drop_table("admin_roles")
