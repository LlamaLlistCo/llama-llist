from pydantic import BaseModel
from datetime import datetime
from typing import Optional, Literal

# 笔记相关
class NoteBase(BaseModel):
    title: str
    content: Optional[str] = None
    image_paths: Optional[str] = None
    tag_id: Optional[int] = None

class NoteCreate(NoteBase):
    pass

class NoteUpdate(BaseModel):
    title: Optional[str] = None
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

class TodoBase(BaseModel):
    title: str
    status: TodoStatus = "pending"
    deadline: Optional[datetime] = None
    note_id: Optional[int] = None

class TodoCreate(TodoBase):
    pass

class TodoUpdate(BaseModel):
    title: Optional[str] = None
    status: Optional[TodoStatus] = None
    deadline: Optional[datetime] = None
    note_id: Optional[int] = None

class TodoOut(TodoBase):
    id: int

    class Config:
        from_attributes = True
