from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List, Optional
from datetime import datetime
from app import crud, schemas
from app.database import get_db

router = APIRouter(prefix="/todos", tags=["todos"])

@router.get("/", response_model=List[schemas.TodoOut])
async def list_todos(
    status: Optional[schemas.TodoStatus] = None,
    deadline_from: Optional[datetime] = None,
    deadline_to: Optional[datetime] = None,
    note_id: Optional[int] = None,
    skip: int = 0,
    limit: int = 100,
    db: AsyncSession = Depends(get_db)
):
    return await crud.get_todos(
        db,
        status=status,
        deadline_from=deadline_from,
        deadline_to=deadline_to,
        note_id=note_id,
        skip=skip,
        limit=limit,
    )

@router.post("/", response_model=schemas.TodoOut, status_code=status.HTTP_201_CREATED)
async def create_todo(
    todo: schemas.TodoCreate,
    db: AsyncSession = Depends(get_db)
):
    if not todo.title or not todo.title.strip():
        raise HTTPException(status_code=400, detail="待办标题不能为空")
    payload = todo.model_copy(update={"title": todo.title.strip()})
    return await crud.create_todo(db, payload)

@router.put("/{todo_id}", response_model=schemas.TodoOut)
async def update_todo(
    todo_id: int,
    payload: schemas.TodoUpdate,
    db: AsyncSession = Depends(get_db)
):
    if payload.title is not None and not payload.title.strip():
        raise HTTPException(status_code=400, detail="待办标题不能为空")
    updated = await crud.update_todo(db, todo_id, payload)
    if not updated:
        raise HTTPException(status_code=404, detail="待办不存在")
    return updated

@router.delete("/{todo_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_todo(
    todo_id: int,
    db: AsyncSession = Depends(get_db)
):
    todo = await crud.get_todo(db, todo_id)
    if not todo:
        raise HTTPException(status_code=404, detail="待办不存在")
    await crud.delete_todo(db, todo_id)
    return None
