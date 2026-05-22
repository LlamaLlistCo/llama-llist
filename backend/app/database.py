from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker, declarative_base
from sqlalchemy import text
import os

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATABASE_URL = f"sqlite+aiosqlite:///{os.path.join(BASE_DIR, 'notes.db')}"

engine = create_async_engine(DATABASE_URL, echo=False)
AsyncSessionLocal = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

Base = declarative_base()


async def get_db():
    async with AsyncSessionLocal() as session:
        yield session


async def init_db():
    async with engine.begin() as conn:
        from app import models
        await conn.run_sync(Base.metadata.create_all)
        await ensure_lightweight_migrations(conn)


async def ensure_lightweight_migrations(conn):
    """Keep existing SQLite databases compatible without a migration tool."""
    template_columns = await conn.execute(text("PRAGMA table_info(templates)"))
    existing = {row[1] for row in template_columns.fetchall()}
    if "description" not in existing:
        await conn.execute(text("ALTER TABLE templates ADD COLUMN description VARCHAR(200)"))
    if "sort_order" not in existing:
        await conn.execute(text("ALTER TABLE templates ADD COLUMN sort_order INTEGER DEFAULT 0"))
    if "is_system" not in existing:
        await conn.execute(text("ALTER TABLE templates ADD COLUMN is_system BOOLEAN DEFAULT 1"))

    indexes = [
        "CREATE INDEX IF NOT EXISTS ix_notes_created_at ON notes (created_at)",
        "CREATE INDEX IF NOT EXISTS ix_notes_updated_at ON notes (updated_at)",
        "CREATE INDEX IF NOT EXISTS ix_todos_status ON todos (status)",
        "CREATE INDEX IF NOT EXISTS ix_todos_deadline ON todos (deadline)",
        "CREATE INDEX IF NOT EXISTS ix_todos_priority ON todos (priority)",
        "CREATE INDEX IF NOT EXISTS ix_todos_note_id ON todos (note_id)",
    ]
    for stmt in indexes:
        await conn.execute(text(stmt))
