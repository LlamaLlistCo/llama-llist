from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Dict, Any

from app import crud, schemas
from app.database import get_db

router = APIRouter(tags=["settings"])


@router.get('/settings/theme')
async def get_current_theme(db: AsyncSession = Depends(get_db)):
    """获取当前主题"""
    theme_id = await crud.get_setting(db, 'ui.theme_id')
    if not theme_id:
        theme_id = '1'
        await crud.set_setting(db, 'ui.theme_id', '1')
    
    theme = await crud.get_theme(db, int(theme_id))
    if not theme:
        raise HTTPException(status_code=404, detail="主题不存在")
    return theme


@router.post('/settings/theme/{theme_id}')
async def set_current_theme(theme_id: int, db: AsyncSession = Depends(get_db)):
    """切换主题"""
    theme = await crud.get_theme(db, theme_id)
    if not theme:
        raise HTTPException(status_code=404, detail="主题不存在")
    
    await crud.set_setting(db, 'ui.theme_id', str(theme_id))
    return {"ok": True, "theme": theme}


@router.get('/settings/themes')
async def list_themes(db: AsyncSession = Depends(get_db)):
    """获取所有主题列表"""
    themes = await crud.get_themes(db)
    return {"themes": themes}


@router.get('/settings/ai')
async def get_ai_settings(db: AsyncSession = Depends(get_db)):
    url = await crud.get_setting(db, 'ai.provider_url')
    key = await crud.get_setting(db, 'ai.api_key')
    return {"provider_url": url, "api_key": True if key else False}


@router.post('/settings/ai')
async def set_ai_settings(payload: Dict[str, str], db: AsyncSession = Depends(get_db)):
    provider = payload.get('provider_url')
    key = payload.get('api_key')
    if provider is not None:
        await crud.set_setting(db, 'ai.provider_url', provider)
    if key is not None:
        await crud.set_setting(db, 'ai.api_key', key)
    return {"ok": True}
