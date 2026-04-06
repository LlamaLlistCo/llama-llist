from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List, Optional
from datetime import datetime
from app import crud, schemas
from app.database import get_db

router = APIRouter(prefix="/notes", tags=["notes"])

@router.post("/", response_model=schemas.NoteOut, status_code=status.HTTP_201_CREATED)
async def create_note(
    note: schemas.NoteCreate,
    db: AsyncSession = Depends(get_db)
):
    # 标题不能为空校验（后端二次校验）
    if not note.title or not note.title.strip():
        raise HTTPException(status_code=400, detail="标题不能为空")
    return await crud.create_note(db, note)

@router.get("/{note_id}", response_model=schemas.NoteOut)
async def get_note(
    note_id: int,
    db: AsyncSession = Depends(get_db)
):
    note = await crud.get_note(db, note_id)
    if not note:
        raise HTTPException(status_code=404, detail="笔记不存在")
    return note

@router.get("/", response_model=List[schemas.NoteOut])
async def list_notes(
    q: Optional[str] = None,
    created_from: Optional[datetime] = None,
    created_to: Optional[datetime] = None,
    tag_id: Optional[int] = None,
    skip: int = 0,
    limit: int = 100,
    db: AsyncSession = Depends(get_db)
):
    has_filters = any([q, created_from, created_to, tag_id is not None])
    if has_filters:
        return await crud.search_notes(
            db,
            q=q,
            created_from=created_from,
            created_to=created_to,
            tag_id=tag_id,
            skip=skip,
            limit=limit,
        )
    return await crud.get_notes(db, skip=skip, limit=limit)

@router.put("/{note_id}", response_model=schemas.NoteOut)
async def update_note(
    note_id: int,
    payload: schemas.NoteUpdate,
    db: AsyncSession = Depends(get_db)
):
    if payload.title is not None and not payload.title.strip():
        raise HTTPException(status_code=400, detail="标题不能为空")
    note = await crud.update_note(db, note_id, payload)
    if not note:
        raise HTTPException(status_code=404, detail="笔记不存在")
    return note

@router.delete("/{note_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_note(
    note_id: int,
    db: AsyncSession = Depends(get_db)
):
    note = await crud.get_note(db, note_id)
    if not note:
        raise HTTPException(status_code=404, detail="笔记不存在")
    await crud.delete_note(db, note_id)
    return None
