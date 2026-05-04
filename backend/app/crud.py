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
    priority: str | None = None,
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
    if priority:
        filters.append(models.Todo.priority == priority)
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


async def get_templates(db: AsyncSession):
    result = await db.execute(select(models.Template))
    return result.scalars().all()

async def create_template(db: AsyncSession, template: schemas.TemplateCreate):
    db_template = models.Template(**template.dict())
    db.add(db_template)
    await db.commit()
    await db.refresh(db_template)
    return db_template

async def delete_template(db: AsyncSession, template_id: int):
    result = await db.execute(delete(models.Template).where(models.Template.id == template_id))
    await db.commit()
    return result.rowcount > 0

async def init_default_templates(db: AsyncSession):
    """初始化系统预设模板"""
    # 1. 检查是否已经存在模板，避免重复插入
    result = await db.execute(select(func.count(models.Template.id)))
    count = result.scalar()
    
    if count > 0:
        return # 如果表里有东西，就不初始化了

    # 2. 定义预设模板数据
    default_templates = [
        {
            "name": "📚 读书笔记",
            "category": "书架",
            "icon": "📖",
            "content_skeleton": "# 书名：\n## 核心观点：\n- \n## 金句摘录：\n> \n## 思考与实践：\n"
        },
        {
            "name": "🌿 心情随笔",
            "category": "心情",
            "icon": "🍃",
            "content_skeleton": "日期：\n天气：\n心情：\n---\n今天发生的难忘的事：\n"
        },
        {
            "name": "💼 会议记录",
            "category": "会议",
            "icon": "📝",
            "content_skeleton": "# 会议主题：\n- 时间地点：\n- 参会人员：\n---\n### 议程内容：\n1. \n### 待办行动项：\n- [ ] "
        }
    ]

    # 3. 批量插入
    for t_data in default_templates:
        db_template = models.Template(**t_data)
        db.add(db_template)
    
    await db.commit()
    print("✅ 系统预设模板初始化成功！")


# ----- 简单设置 CRUD -----
async def get_setting(db: AsyncSession, key: str):
    result = await db.execute(select(models.Setting).where(models.Setting.key == key))
    row = result.scalars().first()
    return row.value if row else None


async def set_setting(db: AsyncSession, key: str, value: str):
    result = await db.execute(select(models.Setting).where(models.Setting.key == key))
    row = result.scalars().first()
    if row:
        row.value = value
    else:
        row = models.Setting(key=key, value=value)
        db.add(row)
    await db.commit()
    return row