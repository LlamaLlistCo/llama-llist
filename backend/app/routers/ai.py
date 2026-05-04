from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import APIRouter, Depends, HTTPException, status, Body
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List, Optional, Dict, Any
import os
import httpx

from app import crud, schemas
from app.database import get_db
from app.local_ai import extract_from_text

router = APIRouter(tags=["ai"])


def _note_text(note) -> str:
    return (note.title or "") + "\n" + (note.content or "")


@router.post("/ai/local/extract/{note_id}")
@router.post("/notes/{note_id}/ai/extract")
async def local_extract(note_id: int, db: AsyncSession = Depends(get_db)):
    note = await crud.get_note(db, note_id)
    if not note:
        raise HTTPException(status_code=404, detail="笔记不存在")

    text = _note_text(note)
    result = extract_from_text(text)
    # align shape: { keywords: [], labels: [], todos: [], priority: '' }
    return {"note_id": note_id, "result": result}


@router.post("/ai/cloud/summarize/{note_id}")
@router.post("/notes/{note_id}/ai/summarize")
async def cloud_summarize(note_id: int, db: AsyncSession = Depends(get_db)):
    """Proxy endpoint to call a cloud LLM for summarization.

    Returns: { note_id, summary, keywords }
    """
    note = await crud.get_note(db, note_id)
    if not note:
        raise HTTPException(status_code=404, detail="笔记不存在")

    # Prefer DB-configured provider settings (so users can set provider URL and API key from the app).
    provider_url = await crud.get_setting(db, 'ai.provider_url')
    provider_key = await crud.get_setting(db, 'ai.api_key')

    if not provider_key and not os.getenv("OPENAI_API_KEY"):
        raise HTTPException(status_code=503, detail="云端模型未配置（缺少 API key），请在设置中配置 AI 提供商")

    text = _note_text(note)
    prompt = f"请把以下会议/笔记内容用中文总结为一段不超过200字的摘要，并列出6个关键词，返回 JSON 格式，包含字段 summary 和 keywords：\n\n{text}"

    # Use provider URL if configured, otherwise default to OpenAI chat completions
    if provider_url:
        url = provider_url.rstrip('/')
        headers = {"Authorization": f"Bearer {provider_key}", "Content-Type": "application/json"}
        payload = {"model": "deepseek-v4-flash", "messages": [{"role": "user", "content": prompt}], "temperature": 0.2, "max_tokens": 800}
    else:
        api_key = os.getenv("DEEPSEEK_API_KEY")  # 需要在环境变量中设置
        url = "https://api.deepseek.com/v1/chat/completions"
        headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
        payload = {"model": "deepseek-v4-flash"}  # 或者 deepseek-coder

    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            r = await client.post(url, headers=headers, json=payload)
            r.raise_for_status()
            data = r.json()
            summary = None
            try:
                summary = data.get("choices", [])[0].get("message", {}).get("content")
            except Exception:
                summary = None

            if not summary:
                raise HTTPException(status_code=502, detail="云端模型返回空内容")

            # try to parse JSON from model; if fails, return raw text under summary
            import json
            keywords = []
            parsed = None
            try:
                parsed = json.loads(summary)
                summary_text = parsed.get('summary') if isinstance(parsed, dict) else None
                keywords = parsed.get('keywords') if isinstance(parsed, dict) else []
                if summary_text is None:
                    summary_text = summary
            except Exception:
                summary_text = summary

            return {"note_id": note_id, "summary": summary_text, "keywords": keywords}

    except httpx.RequestError as e:
        raise HTTPException(status_code=502, detail=f"请求云端模型失败: {e}")
    except httpx.HTTPStatusError as e:
        raise HTTPException(status_code=e.response.status_code, detail=f"云端模型错误: {e.response.text}")


@router.get('/settings/ai')
async def get_ai_settings(db: AsyncSession = Depends(get_db)):
    url = await crud.get_setting(db, 'ai.provider_url')
    key = await crud.get_setting(db, 'ai.api_key')
    return {"provider_url": url, "api_key": True if key else False}


@router.post('/settings/ai')
async def set_ai_settings(payload: Dict[str, str], db: AsyncSession = Depends(get_db)):
    # payload: { provider_url?: str, api_key?: str }
    provider = payload.get('provider_url')
    key = payload.get('api_key')
    if provider is not None:
        await crud.set_setting(db, 'ai.provider_url', provider)
    if key is not None:
        await crud.set_setting(db, 'ai.api_key', key)
    return {"ok": True}


@router.post("/ai/apply_todos/{note_id}")
@router.post("/notes/{note_id}/ai/apply_todos")
async def apply_todos(note_id: int, payload: Dict[str, Any] = Body(...), db: AsyncSession = Depends(get_db)):
    """Create todo items extracted/approved by AI and attach to the note.

    Accepts JSON: { todos: ["task1", "task2"] }
    Returns created todo items as list.
    """
    note = await crud.get_note(db, note_id)
    if not note:
        raise HTTPException(status_code=404, detail="笔记不存在")

    todos = payload.get("todos") or []
    if not isinstance(todos, list):
        raise HTTPException(status_code=400, detail="payload.todos must be a list")

    created = []
    for t in todos:
        todo_in = schemas.TodoCreate(title=str(t), note_id=note_id)
        db_todo = await crud.create_todo(db, todo_in)
        created.append(db_todo)

    return {"created": created}
