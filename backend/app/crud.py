from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete, func, or_, and_
from sqlalchemy.exc import IntegrityError
from app import models, schemas


# ----- Notes CRUD -----
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
    result = await db.execute(
        select(models.Note).order_by(models.Note.updated_at.desc()).offset(skip).limit(limit)
    )
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
                    func.lower(func.coalesce(models.Note.summary, "")).like(f"%{q_norm}%"),
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

    stmt = stmt.order_by(models.Note.updated_at.desc()).offset(skip).limit(limit)
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
    await db.execute(delete(models.Todo).where(models.Todo.note_id == note_id))
    await db.execute(delete(models.Note).where(models.Note.id == note_id))
    await db.commit()


# ----- Tags CRUD -----
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
    result = await db.execute(select(models.Note).where(models.Note.tag_id == tag_id))
    for note in result.scalars().all():
        note.tag_id = None
    await db.execute(delete(models.Tag).where(models.Tag.id == tag_id))
    await db.commit()


# ----- Todos CRUD -----
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


# ----- Templates CRUD -----
async def get_templates(db: AsyncSession):
    result = await db.execute(
        select(models.Template).order_by(models.Template.sort_order.asc(), models.Template.id.asc())
    )
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
    default_templates = [
        {
            "name": "草甸灵感速记",
            "category": "灵感",
            "icon": "🦙",
            "description": "适合快速捕捉想法，再交给 AI 整理。",
            "sort_order": 10,
            "content_skeleton": "# 灵感标题：\n\n## 一句话想法\n\n## 触发场景\n- \n\n## 可行动的小步骤\n- [ ] \n",
        },
        {
            "name": "课堂/会议行动项",
            "category": "学习",
            "icon": "⛰️",
            "description": "记录讨论内容，并让 AI 提取待办。",
            "sort_order": 20,
            "content_skeleton": "# 主题：\n- 时间：\n- 参与者：\n\n## 关键记录\n1. \n\n## 需要跟进\n- [ ] \n\n## 疑问与补充\n- \n",
        },
        {
            "name": "读书摘毛线",
            "category": "阅读",
            "icon": "📚",
            "description": "把摘录、观点和行动启发分开。",
            "sort_order": 30,
            "content_skeleton": "# 书名：\n\n## 核心观点\n- \n\n## 金句摘录\n> \n\n## 可以实践的事\n- [ ] \n",
        },
        {
            "name": "山谷复盘计划",
            "category": "计划",
            "icon": "🌄",
            "description": "适合周复盘、项目复盘和下一步规划。",
            "sort_order": 40,
            "content_skeleton": "# 复盘对象：\n\n## 做得不错\n- \n\n## 卡住的地方\n- \n\n## 下一步行动\n- [ ] \n",
        },
        {
            "name": "云朵心情札记",
            "category": "生活",
            "icon": "☁️",
            "description": "轻量记录情绪、事件和自我照顾。",
            "sort_order": 50,
            "content_skeleton": "日期：\n天气：\n心情：\n\n## 今天的小事\n\n## 想感谢的瞬间\n\n## 明天照顾自己的方式\n- [ ] \n",
        },
    ]

    existing_result = await db.execute(select(models.Template.name))
    existing_names = set(existing_result.scalars().all())
    for t_data in default_templates:
        if t_data["name"] not in existing_names:
            db.add(models.Template(**t_data))

    await db.commit()
    print("Default templates initialized.")


# ----- Settings CRUD -----
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


# ----- Themes CRUD -----
async def get_theme(db: AsyncSession, theme_id: int):
    result = await db.execute(select(models.Theme).where(models.Theme.id == theme_id))
    return result.scalars().first()


async def get_themes(db: AsyncSession):
    result = await db.execute(select(models.Theme).order_by(models.Theme.id.asc()))
    return result.scalars().all()


async def init_default_themes(db: AsyncSession):
    default_themes = [
        {
            "id": 1,
            "name": "羊驼草甸",
            "primary_color": "#6F7F4F",
            "secondary_color": "#B7A887",
            "background_color": "#F8F5EC",
            "accent_color": "#D9A85F",
            "text_color": "#3F382F",
            "is_dark": False,
        },
        {
            "id": 2,
            "name": "安第斯纸本",
            "primary_color": "#8A654A",
            "secondary_color": "#C8A978",
            "background_color": "#FAF3E7",
            "accent_color": "#C9895B",
            "text_color": "#453328",
            "is_dark": False,
        },
        {
            "id": 3,
            "name": "云朵羊毛",
            "primary_color": "#5B8FA8",
            "secondary_color": "#A9C7D6",
            "background_color": "#F3FAFC",
            "accent_color": "#86B8C8",
            "text_color": "#253D4A",
            "is_dark": False,
        },
        {
            "id": 4,
            "name": "山谷晨光",
            "primary_color": "#70875A",
            "secondary_color": "#D1BF84",
            "background_color": "#FBF7E8",
            "accent_color": "#E2B85F",
            "text_color": "#34402C",
            "is_dark": False,
        },
        {
            "id": 5,
            "name": "极简牧场",
            "primary_color": "#5F6D5A",
            "secondary_color": "#A7A08E",
            "background_color": "#F7F6F1",
            "accent_color": "#9A7D58",
            "text_color": "#323530",
            "is_dark": False,
        },
        {
            "id": 6,
            "name": "AI 驼队工作台",
            "primary_color": "#51606F",
            "secondary_color": "#95A3A8",
            "background_color": "#F4F7F6",
            "accent_color": "#79A58C",
            "text_color": "#263238",
            "is_dark": False,
        },
    ]

    existing_result = await db.execute(select(models.Theme.id))
    existing_ids = set(existing_result.scalars().all())
    for theme_data in default_themes:
        if theme_data["id"] not in existing_ids:
            db.add(models.Theme(**theme_data))

    await db.commit()
    print("Default themes initialized.")
