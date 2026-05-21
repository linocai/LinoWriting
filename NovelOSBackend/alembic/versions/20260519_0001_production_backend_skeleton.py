from __future__ import annotations

from alembic import op
import sqlalchemy as sa


revision = "20260519_0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    def has_table(name: str) -> bool:
        return name in inspector.get_table_names()

    def has_column(table: str, column: str) -> bool:
        return has_table(table) and column in {item["name"] for item in inspector.get_columns(table)}

    def add_column_if_missing(table: str, column: sa.Column) -> None:
        if not has_column(table, column.name):
            with op.batch_alter_table(table) as batch:
                batch.add_column(column)

    with op.batch_alter_table("novels") as batch:
        if not has_column("novels", "status"):
            batch.add_column(sa.Column("status", sa.String(), nullable=False, server_default="active"))
        if not has_column("novels", "language"):
            batch.add_column(sa.Column("language", sa.String(), nullable=False, server_default="zh-Hans"))

    if not has_table("structured_prompts"):
        op.create_table(
            "structured_prompts",
            sa.Column("id", sa.String(), primary_key=True),
            sa.Column("chapter_id", sa.String(), sa.ForeignKey("chapters.id"), nullable=False),
            sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
            sa.Column("payload", sa.JSON(), nullable=False),
            sa.Column("status", sa.String(), nullable=False, server_default="draft"),
            sa.Column("created_by", sa.String(), nullable=False, server_default="prompt_expander"),
            sa.Column("created_at", sa.Float(), nullable=False),
            sa.UniqueConstraint("chapter_id", "version", name="uq_structured_prompt_version"),
        )

    if not has_table("canon_update_patches"):
        op.create_table(
            "canon_update_patches",
            sa.Column("id", sa.String(), primary_key=True),
            sa.Column("chapter_id", sa.String(), sa.ForeignKey("chapters.id"), nullable=False),
            sa.Column("target_canon_version", sa.Integer(), nullable=False),
            sa.Column("status", sa.String(), nullable=False, server_default="pending_user_confirmation"),
            sa.Column("payload", sa.JSON(), nullable=False),
            sa.Column("created_at", sa.Float(), nullable=False),
            sa.Column("confirmed_at", sa.Float(), nullable=True),
        )

    if not has_table("canon_edit_history"):
        op.create_table(
            "canon_edit_history",
            sa.Column("id", sa.String(), primary_key=True),
            sa.Column("novel_id", sa.String(), sa.ForeignKey("novels.id"), nullable=False),
            sa.Column("chapter_id", sa.String(), sa.ForeignKey("chapters.id"), nullable=True),
            sa.Column("target", sa.String(), nullable=False),
            sa.Column("action", sa.String(), nullable=False),
            sa.Column("payload", sa.JSON(), nullable=False),
            sa.Column("created_by", sa.String(), nullable=False, server_default="canon_merge_agent"),
            sa.Column("created_at", sa.Float(), nullable=False),
        )

    if not has_table("bootstrap_imports"):
        op.create_table(
            "bootstrap_imports",
            sa.Column("id", sa.String(), primary_key=True),
            sa.Column("novel_id", sa.String(), sa.ForeignKey("novels.id"), nullable=False),
            sa.Column("status", sa.String(), nullable=False, server_default="imported"),
            sa.Column("source_type", sa.String(), nullable=False, server_default="first_three_chapters"),
            sa.Column("storage_path", sa.String(), nullable=True),
            sa.Column("chapters_payload", sa.JSON(), nullable=False),
            sa.Column("analysis_payload", sa.JSON(), nullable=False),
            sa.Column("created_at", sa.Float(), nullable=False),
            sa.Column("updated_at", sa.Float(), nullable=False),
        )

    add_column_if_missing("chapter_versions", sa.Column("user_feedback", sa.Text(), nullable=True))

    with op.batch_alter_table("context_packs") as batch:
        if not has_column("context_packs", "canon_version"):
            batch.add_column(sa.Column("canon_version", sa.Integer(), nullable=False, server_default="1"))
        unique_names = {item["name"] for item in inspector.get_unique_constraints("context_packs")} if has_table("context_packs") else set()
        if "uq_context_pack_chapter" in unique_names:
            batch.drop_constraint("uq_context_pack_chapter", type_="unique")

    with op.batch_alter_table("agent_runs") as batch:
        if not has_column("agent_runs", "novel_id"):
            batch.add_column(sa.Column("novel_id", sa.String(), nullable=True))
        if not has_column("agent_runs", "run_type"):
            batch.add_column(sa.Column("run_type", sa.String(), nullable=False, server_default="workflow"))
        if not has_column("agent_runs", "model"):
            batch.add_column(sa.Column("model", sa.String(), nullable=True))
        if not has_column("agent_runs", "input_payload"):
            batch.add_column(sa.Column("input_payload", sa.JSON(), nullable=False, server_default="{}"))
        if not has_column("agent_runs", "output_payload"):
            batch.add_column(sa.Column("output_payload", sa.JSON(), nullable=False, server_default="{}"))
        if not has_column("agent_runs", "input_json"):
            batch.add_column(sa.Column("input_json", sa.JSON(), nullable=False, server_default="{}"))
        if not has_column("agent_runs", "output_json"):
            batch.add_column(sa.Column("output_json", sa.JSON(), nullable=False, server_default="{}"))
        if not has_column("agent_runs", "token_usage"):
            batch.add_column(sa.Column("token_usage", sa.JSON(), nullable=False, server_default="{}"))
        if not has_column("agent_runs", "error_message"):
            batch.add_column(sa.Column("error_message", sa.Text(), nullable=True))
        if not has_column("agent_runs", "started_at"):
            batch.add_column(sa.Column("started_at", sa.Float(), nullable=True))
        if not has_column("agent_runs", "completed_at"):
            batch.add_column(sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True))
        if has_column("agent_runs", "timestamp_label"):
            batch.drop_column("timestamp_label")
        batch.alter_column("chapter_id", existing_type=sa.String(), nullable=True)

    with op.batch_alter_table("audit_reports") as batch:
        if not has_column("audit_reports", "pass"):
            batch.add_column(sa.Column("pass", sa.Boolean(), nullable=False, server_default=sa.true()))
        if not has_column("audit_reports", "highest_severity"):
            batch.add_column(sa.Column("highest_severity", sa.String(), nullable=False, server_default="none"))

    add_column_if_missing("world_bible_sections", sa.Column("section_key", sa.String(), nullable=True))

    with op.batch_alter_table("characters") as batch:
        batch.alter_column("current_state", type_=sa.JSON(), existing_type=sa.Text())
        batch.alter_column("dialogue_style", type_=sa.JSON(), existing_type=sa.Text())
        if not has_column("characters", "knowledge_summary"):
            batch.add_column(sa.Column("knowledge_summary", sa.JSON(), nullable=False, server_default="{}"))
        if not has_column("characters", "do_not_auto_mention"):
            batch.add_column(sa.Column("do_not_auto_mention", sa.Boolean(), nullable=False, server_default=sa.false()))
        if not has_column("characters", "default_visibility"):
            batch.add_column(sa.Column("default_visibility", sa.String(), nullable=False, server_default="manual_only"))

    with op.batch_alter_table("knowledge_matrix_entries") as batch:
        if not has_column("knowledge_matrix_entries", "fact"):
            batch.add_column(sa.Column("fact", sa.Text(), nullable=True))
        if not has_column("knowledge_matrix_entries", "visibility"):
            batch.add_column(sa.Column("visibility", sa.JSON(), nullable=True))
        batch.alter_column("allowed_narration", type_=sa.JSON(), existing_type=sa.Text())

    add_column_if_missing("memory_facts", sa.Column("time_in_story", sa.String(), nullable=True))
    add_column_if_missing("memory_facts", sa.Column("metadata", sa.JSON(), nullable=False, server_default="{}"))
    add_column_if_missing("memory_facts", sa.Column("created_by", sa.String(), nullable=False, server_default="system"))


def downgrade() -> None:
    with op.batch_alter_table("memory_facts") as batch:
        batch.drop_column("created_by")
        batch.drop_column("metadata")
        batch.drop_column("time_in_story")

    with op.batch_alter_table("knowledge_matrix_entries") as batch:
        batch.alter_column("allowed_narration", type_=sa.Text(), existing_type=sa.JSON())
        batch.drop_column("visibility")
        batch.drop_column("fact")

    with op.batch_alter_table("characters") as batch:
        batch.drop_column("default_visibility")
        batch.drop_column("do_not_auto_mention")
        batch.drop_column("knowledge_summary")
        batch.alter_column("dialogue_style", type_=sa.Text(), existing_type=sa.JSON())
        batch.alter_column("current_state", type_=sa.Text(), existing_type=sa.JSON())

    with op.batch_alter_table("world_bible_sections") as batch:
        batch.drop_column("section_key")

    with op.batch_alter_table("audit_reports") as batch:
        batch.drop_column("highest_severity")
        batch.drop_column("pass")

    with op.batch_alter_table("agent_runs") as batch:
        batch.alter_column("chapter_id", existing_type=sa.String(), nullable=False)
        batch.add_column(sa.Column("timestamp_label", sa.String(), nullable=False, server_default=""))
        batch.drop_column("completed_at")
        batch.drop_column("started_at")
        batch.drop_column("error_message")
        batch.drop_column("token_usage")
        batch.drop_column("output_json")
        batch.drop_column("input_json")
        batch.drop_column("output_payload")
        batch.drop_column("input_payload")
        batch.drop_column("model")
        batch.drop_column("run_type")
        batch.drop_column("novel_id")

    with op.batch_alter_table("context_packs") as batch:
        batch.create_unique_constraint("uq_context_pack_chapter", ["chapter_id"])
        batch.drop_column("canon_version")

    with op.batch_alter_table("chapter_versions") as batch:
        batch.drop_column("user_feedback")

    op.drop_table("bootstrap_imports")
    op.drop_table("canon_edit_history")
    op.drop_table("canon_update_patches")
    op.drop_table("structured_prompts")

    with op.batch_alter_table("novels") as batch:
        batch.drop_column("language")
        batch.drop_column("status")
