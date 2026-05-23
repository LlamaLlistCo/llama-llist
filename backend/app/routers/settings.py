from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, HttpUrl
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Dict, Any
import httpx

from app import crud, schemas
from app.database import get_db

router = APIRouter(tags=["settings"])


class AISettingsPayload(BaseModel):
    provider_url: str | None = None
    api_key: str | None = None
    model_name: str | None = None


class AIModelCheckPayload(BaseModel):
    provider_url: str
    api_key: str
    model_name: str


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
    model_name = await crud.get_setting(db, 'ai.model_name')
    return {"provider_url": url, "api_key": True if key else False, "model_name": model_name or "deepseek-chat"}


@router.post('/settings/ai')
async def set_ai_settings(payload: AISettingsPayload, db: AsyncSession = Depends(get_db)):
    provider = payload.provider_url
    key = payload.api_key
    model_name = payload.model_name
    if provider is not None:
        await crud.set_setting(db, 'ai.provider_url', provider)
    if key is not None:
        await crud.set_setting(db, 'ai.api_key', key)
    if model_name is not None:
        await crud.set_setting(db, 'ai.model_name', model_name)
    return {"ok": True}


@router.post('/settings/ai/check')
async def check_ai_settings(payload: AIModelCheckPayload):
    provider = (payload.provider_url or '').strip()
    api_key = (payload.api_key or '').strip()

    model_name = (payload.model_name or '').strip()

    if not provider:
        raise HTTPException(status_code=400, detail='Provider URL 不能为空')
    if not api_key:
        raise HTTPException(status_code=400, detail='API Key 不能为空')
    if not model_name:
        raise HTTPException(status_code=400, detail='模型名称不能为空')

    try:
        parsed = HttpUrl(provider)
        if parsed.scheme != 'https':
            raise HTTPException(status_code=400, detail='Provider URL 必须使用 HTTPS')
    except Exception:
        raise HTTPException(status_code=400, detail='Provider URL 格式不合法')

    url = provider.rstrip('/')
    headers = {
        'Authorization': f'Bearer {api_key}',
        'Content-Type': 'application/json'
    }
    body: Dict[str, Any] = {
        'model': model_name,
        'messages': [{'role': 'user', 'content': 'reply with ok'}],
        'temperature': 0,
        'max_tokens': 8
    }

    try:
        async with httpx.AsyncClient(timeout=12.0) as client:
            response = await client.post(url, headers=headers, json=body)
            response.raise_for_status()
    except httpx.TimeoutException:
        raise HTTPException(status_code=504, detail='模型检测超时，请稍后重试')
    except httpx.HTTPStatusError as exc:
        detail = exc.response.text[:200] if exc.response is not None else 'unknown error'
        raise HTTPException(status_code=502, detail=f'模型检测失败: {detail}')
    except httpx.RequestError as exc:
        raise HTTPException(status_code=502, detail=f'模型检测失败: {exc}')

    return {'ok': True, 'message': '模型连接正常'}

