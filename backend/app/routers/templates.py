from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List
from app import crud, schemas
from app.database import get_db

router = APIRouter(prefix="/templates", tags=["templates"])

@router.get("/", response_model=List[schemas.TemplateOut])
async def list_templates(
    db: AsyncSession = Depends(get_db)
):
    """获取所有笔记模板"""
    return await crud.get_templates(db)

@router.post("/", response_model=schemas.TemplateOut, status_code=status.HTTP_201_CREATED)
async def create_template(
    template: schemas.TemplateCreate,
    db: AsyncSession = Depends(get_db)
):
    """创建一个新模板"""
    return await crud.create_template(db, template)

@router.delete("/{template_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_template(
    template_id: int,
    db: AsyncSession = Depends(get_db)
):
    """删除指定模板"""
    success = await crud.delete_template(db, template_id)
    if not success:
        raise HTTPException(status_code=404, detail="模板不存在")
    return None