from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete, func, or_, and_
from sqlalchemy.exc import IntegrityError
from app import models, schemas

# ----- 笔记 CRUD -----
async def create_note(db: AsyncSession, note: schemas.NoteCreate):
    db_note = models.Note(**note.dict())
    db.add(db_note)
    await db.commit()
    await db.refresh(db_note)
    return db_note

async def get_note(db: AsyncSession, note_id: int):
    result = await db.execute(select(models.Note).where(models.Note.id == note_id))
    return result.scalars().first()

async def get_notes(db: AsyncSession, skip: int = 0, limit: int = 100):
    result = await db.execute(select(models.Note).offset(skip).limit(limit))
    return result.scalars().all()

async def search_notes(
    db: AsyncSession,
    q: str | None = None,
    created_from=None,
    created_to=None,
    tag_id: int | None = None,
    skip: int = 0,
    limit: int = 100,
):
    stmt = select(models.Note)
    filters = []

    if q:
        q_norm = q.strip().lower()
        if q_norm:
            filters.append(
                or_(
                    func.lower(models.Note.title).like(f"%{q_norm}%"),
                    func.lower(func.coalesce(models.Note.content, "")).like(f"%{q_norm}%"),
                )
            )

    if created_from:
        filters.append(models.Note.created_at >= created_from)
    if created_to:
        filters.append(models.Note.created_at <= created_to)
    if tag_id is not None:
        filters.append(models.Note.tag_id == tag_id)

    if filters:
        stmt = stmt.where(and_(*filters))

    stmt = stmt.order_by(models.Note.created_at.desc()).offset(skip).limit(limit)
    result = await db.execute(stmt)
    return result.scalars().all()

async def update_note(db: AsyncSession, note_id: int, payload: schemas.NoteUpdate):
    db_note = await get_note(db, note_id)
    if not db_note:
        return None
    data = payload.dict(exclude_unset=True)
    for k, v in data.items():
        setattr(db_note, k, v)
    await db.commit()
    await db.refresh(db_note)
    return db_note

async def delete_note(db: AsyncSession, note_id: int):
    await db.execute(delete(models.Note).where(models.Note.id == note_id))
    await db.commit()

# ----- 标签 CRUD -----
async def create_tag(db: AsyncSession, tag: schemas.TagCreate):
    db_tag = models.Tag(**tag.dict())
    db.add(db_tag)
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        return None
    await db.refresh(db_tag)
    return db_tag

async def get_tags(db: AsyncSession):
    result = await db.execute(select(models.Tag).order_by(models.Tag.name.asc()))
    return result.scalars().all()

async def delete_tag(db: AsyncSession, tag_id: int):
    await db.execute(delete(models.Tag).where(models.Tag.id == tag_id))
    await db.commit()

# ----- 待办 CRUD -----
async def create_todo(db: AsyncSession, todo: schemas.TodoCreate):
    db_todo = models.Todo(**todo.dict())
    db.add(db_todo)
    await db.commit()
    await db.refresh(db_todo)
    return db_todo

async def get_todo(db: AsyncSession, todo_id: int):
    result = await db.execute(select(models.Todo).where(models.Todo.id == todo_id))
    return result.scalars().first()

async def get_todos(
    db: AsyncSession,
    status: str | None = None,
    deadline_from=None,
    deadline_to=None,
    note_id: int | None = None,
    skip: int = 0,
    limit: int = 100,
):
    stmt = select(models.Todo)
    filters = []
    if status:
        filters.append(models.Todo.status == status)
    if deadline_from:
        filters.append(models.Todo.deadline >= deadline_from)
    if deadline_to:
        filters.append(models.Todo.deadline <= deadline_to)
    if note_id is not None:
        filters.append(models.Todo.note_id == note_id)
    if filters:
        stmt = stmt.where(and_(*filters))
    stmt = stmt.order_by(models.Todo.id.desc()).offset(skip).limit(limit)
    result = await db.execute(stmt)
    return result.scalars().all()

async def update_todo(db: AsyncSession, todo_id: int, payload: schemas.TodoUpdate):
    db_todo = await get_todo(db, todo_id)
    if not db_todo:
        return None
    data = payload.dict(exclude_unset=True)
    for k, v in data.items():
        setattr(db_todo, k, v)
    await db.commit()
    await db.refresh(db_todo)
    return db_todo

async def delete_todo(db: AsyncSession, todo_id: int):
    await db.execute(delete(models.Todo).where(models.Todo.id == todo_id))
    await db.commit()
