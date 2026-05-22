from pydantic import BaseModel
from datetime import datetime
from typing import Optional, Literal

# 笔记相关
class NoteBase(BaseModel):
    title: str
    summary: Optional[str] = None
    view_type: Optional[str] = "default"
    content: Optional[str] = None
    image_paths: Optional[str] = None
    tag_id: Optional[int] = None

class NoteCreate(NoteBase):
    pass

class NoteUpdate(BaseModel):
    title: Optional[str] = None
    summary: Optional[str] = None       
    view_type: Optional[str] = None     
    content: Optional[str] = None
    image_paths: Optional[str] = None
    tag_id: Optional[int] = None

class NoteOut(NoteBase):
    id: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

# 标签相关
class TagBase(BaseModel):
    name: str

class TagCreate(TagBase):
    pass

class TagOut(TagBase):
    id: int

    class Config:
        from_attributes = True

TodoStatus = Literal["pending", "completed", "delayed"]
TodoPriority = Literal["important_urgent", "important_not_urgent", "not_important_urgent", "not_important_not_urgent"]

class TodoBase(BaseModel):
    title: str
    status: TodoStatus = "pending"
    priority: TodoPriority = "important_urgent"
    deadline: Optional[datetime] = None
    note_id: Optional[int] = None

class TodoCreate(TodoBase):
    pass

class TodoUpdate(BaseModel):
    title: Optional[str] = None
    status: Optional[TodoStatus] = None
    priority: Optional[TodoPriority] = None
    deadline: Optional[datetime] = None
    note_id: Optional[int] = None

class TodoOut(TodoBase):
    id: int

    class Config:
        from_attributes = True

#模板相关
class TemplateBase(BaseModel):
    name: str
    category: str
    content_skeleton: str
    icon: Optional[str] = None
    description: Optional[str] = None
    sort_order: int = 0
    is_system: bool = True

class TemplateCreate(TemplateBase):
    pass

class TemplateOut(TemplateBase):
    id: int
    class Config:
        from_attributes = True


# 简单的键值配置
class SettingIn(BaseModel):
    key: str
    value: str

class SettingOut(BaseModel):
    key: str
    value: str

    class Config:
        from_attributes = True


# 主题相关
class ThemeBase(BaseModel):
    name: str
    primary_color: str
    secondary_color: str
    background_color: str
    accent_color: str
    text_color: str
    is_dark: bool = False

class ThemeOut(ThemeBase):
    id: int

    class Config:
        from_attributes = True
