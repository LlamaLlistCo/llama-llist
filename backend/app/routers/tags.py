from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List
from app import crud, schemas
from app.database import get_db

router = APIRouter(prefix="/tags", tags=["tags"])

@router.get("/", response_model=List[schemas.TagOut])
async def list_tags(
    db: AsyncSession = Depends(get_db)
):
    return await crud.get_tags(db)

@router.post("/", response_model=schemas.TagOut, status_code=status.HTTP_201_CREATED)
async def create_tag(
    tag: schemas.TagCreate,
    db: AsyncSession = Depends(get_db)
):
    if not tag.name or not tag.name.strip():
        raise HTTPException(status_code=400, detail="标签名不能为空")
    created = await crud.create_tag(db, schemas.TagCreate(name=tag.name.strip()))
    if not created:
        raise HTTPException(status_code=409, detail="标签已存在")
    return created

@router.delete("/{tag_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_tag(
    tag_id: int,
    db: AsyncSession = Depends(get_db)
):
    await crud.delete_tag(db, tag_id)
    return None
