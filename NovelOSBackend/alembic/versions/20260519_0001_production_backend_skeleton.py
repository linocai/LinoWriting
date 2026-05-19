from __future__ import annotations

from alembic import op
import sqlalchemy as sa


revision = "20260519_0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "bootstrap_imports",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("novel_id", sa.String(), sa.ForeignKey("novels.id"), nullable=False),
        sa.Column("status", sa.String(), nullable=False, server_default="imported"),
        sa.Column("source_type", sa.String(), nullable=False, server_default="first_three_chapters"),
        sa.Column("chapters_payload", sa.JSON(), nullable=False),
        sa.Column("analysis_payload", sa.JSON(), nullable=False),
        sa.Column("created_at", sa.Float(), nullable=False),
        sa.Column("updated_at", sa.Float(), nullable=False),
    )

    with op.batch_alter_table("agent_runs") as batch:
        batch.add_column(sa.Column("novel_id", sa.String(), nullable=True))
        batch.add_column(sa.Column("run_type", sa.String(), nullable=False, server_default="workflow"))
        batch.add_column(sa.Column("input_payload", sa.JSON(), nullable=False, server_default="{}"))
        batch.add_column(sa.Column("output_payload", sa.JSON(), nullable=False, server_default="{}"))
        batch.add_column(sa.Column("error_message", sa.Text(), nullable=True))
        batch.add_column(sa.Column("started_at", sa.Float(), nullable=True))
        batch.add_column(sa.Column("finished_at", sa.Float(), nullable=True))
        batch.alter_column("chapter_id", existing_type=sa.String(), nullable=True)

    with op.batch_alter_table("audit_reports") as batch:
        batch.add_column(sa.Column("passed", sa.Boolean(), nullable=False, server_default=sa.true()))
        batch.add_column(sa.Column("highest_severity", sa.String(), nullable=False, server_default="none"))

    with op.batch_alter_table("knowledge_matrix_entries") as batch:
        batch.add_column(sa.Column("visibility", sa.JSON(), nullable=True))


def downgrade() -> None:
    with op.batch_alter_table("knowledge_matrix_entries") as batch:
        batch.drop_column("visibility")

    with op.batch_alter_table("audit_reports") as batch:
        batch.drop_column("highest_severity")
        batch.drop_column("passed")

    with op.batch_alter_table("agent_runs") as batch:
        batch.alter_column("chapter_id", existing_type=sa.String(), nullable=False)
        batch.drop_column("finished_at")
        batch.drop_column("started_at")
        batch.drop_column("error_message")
        batch.drop_column("output_payload")
        batch.drop_column("input_payload")
        batch.drop_column("run_type")
        batch.drop_column("novel_id")

    op.drop_table("bootstrap_imports")
