from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey, Boolean
from sqlalchemy.orm import relationship
from datetime import datetime
from app.database import Base

class Tag(Base):
    __tablename__ = "tags"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(50), unique=True, index=True)
    notes = relationship("Note", back_populates="tag")

class Note(Base):
    __tablename__ = "notes"
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(200), nullable=False)
    summary = Column(Text, nullable=True)
    view_type = Column(String(50), default="default")
    content = Column(Text)
    image_paths = Column(Text)   # 逗号分隔的图片路径
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    tag_id = Column(Integer, ForeignKey("tags.id"), nullable=True)
    tag = relationship("Tag", back_populates="notes")
    embedding = Column(Text, nullable=True)  # 存储向量（JSON 字符串）

class Template(Base):
    __tablename__ = "templates"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False)     # 模板名称
    category = Column(String(50))                  # 归属专区
    content_skeleton = Column(Text)                # 模板预设内容
    icon = Column(String(20), nullable=True)       # 模板图标，如“📚”

class Todo(Base):
    __tablename__ = "todos"
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(200), nullable=False)
    status = Column(String(20), default="pending")  # pending, completed, delayed
    deadline = Column(DateTime, nullable=True)
    note_id = Column(Integer, ForeignKey("notes.id"), nullable=True)
    note = relationship("Note", backref="todos")
    priority = Column(String(50), default="important_urgent")


class Setting(Base):
    __tablename__ = "settings"
    id = Column(Integer, primary_key=True, index=True)
    key = Column(String(100), unique=True, index=True, nullable=False)
    value = Column(Text, nullable=True)


class Theme(Base):
    __tablename__ = "themes"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(50), unique=True, index=True)
    primary_color = Column(String(7), nullable=False)       # 主色
    secondary_color = Column(String(7), nullable=False)     # 副色
    background_color = Column(String(7), nullable=False)    # 背景色
    accent_color = Column(String(7), nullable=False)        # 强调色
    text_color = Column(String(7), nullable=False)          # 文字色
    is_dark = Column(Boolean, default=False)