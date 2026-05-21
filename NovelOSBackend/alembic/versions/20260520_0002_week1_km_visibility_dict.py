from __future__ import annotations

from alembic import op
import sqlalchemy as sa


revision = "20260520_0002"
down_revision = "20260519_0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    table = sa.table(
        "knowledge_matrix_entries",
        sa.column("id", sa.String()),
        sa.column("visibility", sa.JSON()),
        sa.column("author_knowledge", sa.String()),
        sa.column("reader_knowledge", sa.String()),
        sa.column("character_knowledge", sa.JSON()),
    )
    connection = op.get_bind()
    rows = connection.execute(
        sa.select(
            table.c.id,
            table.c.visibility,
            table.c.author_knowledge,
            table.c.reader_knowledge,
            table.c.character_knowledge,
        )
    ).mappings()
    for row in rows:
        visibility = dict(row["visibility"] or {})
        visibility.setdefault("author", row["author_knowledge"] or "known")
        visibility.setdefault("reader", row["reader_knowledge"] or "reader_unknown")
        for item in row["character_knowledge"] or []:
            if isinstance(item, dict):
                key = item.get("character_name") or item.get("character_id")
                if key:
                    visibility.setdefault(str(key), item.get("state") or "unknown")
        connection.execute(
            table.update()
            .where(table.c.id == row["id"])
            .values(visibility=visibility, character_knowledge=[])
        )

    with op.batch_alter_table("knowledge_matrix_entries") as batch:
        batch.alter_column(
            "visibility",
            existing_type=sa.JSON(),
            nullable=False,
            server_default=sa.text("'{}'"),
        )


def downgrade() -> None:
    with op.batch_alter_table("knowledge_matrix_entries") as batch:
        batch.alter_column(
            "visibility",
            existing_type=sa.JSON(),
            nullable=True,
            server_default=None,
        )
