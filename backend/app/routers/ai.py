from fastapi import APIRouter, Depends, HTTPException, Body
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Dict, Any
import json
import os
import re
import httpx

from app import crud, schemas
from app.database import get_db
from app.local_ai import extract_from_text

router = APIRouter(tags=["ai"])


def _note_text(note) -> str:
    return ((note.title or "") + "\n" + (note.content or "")).strip()


def _dedupe(items, limit: int = 8) -> list[str]:
    result: list[str] = []
    for item in items or []:
        text = str(item).strip()
        if text and text not in result:
            result.append(text)
        if len(result) >= limit:
            break
    return result


def _clip_summary(text: str, limit: int = 300) -> str:
    value = re.sub(r"\s+", " ", (text or "").strip())
    return value[:limit]


def _extract_json_object(text: str) -> Dict[str, Any] | None:
    if not text:
        return None
    try:
        parsed = json.loads(text)
        return parsed if isinstance(parsed, dict) else None
    except json.JSONDecodeError:
        pass

    match = re.search(r"\{[\s\S]*\}", text)
    if not match:
        return None
    try:
        parsed = json.loads(match.group(0))
        return parsed if isinstance(parsed, dict) else None
    except json.JSONDecodeError:
        return None


@router.post("/ai/local/extract/{note_id}")
@router.post("/notes/{note_id}/ai/extract")
async def local_extract(note_id: int, db: AsyncSession = Depends(get_db)):
    note = await crud.get_note(db, note_id)
    if not note:
        raise HTTPException(status_code=404, detail="笔记不存在")

    result = extract_from_text(_note_text(note))
    result["keywords"] = _dedupe(result.get("keywords"), 8)
    result["labels"] = _dedupe(result.get("labels"), 5)
    result["todos"] = _dedupe(result.get("todos"), 10)
    return {"note_id": note_id, "result": result}


@router.post("/ai/cloud/summarize/{note_id}")
@router.post("/notes/{note_id}/ai/summarize")
async def cloud_summarize(note_id: int, db: AsyncSession = Depends(get_db)):
    note = await crud.get_note(db, note_id)
    if not note:
        raise HTTPException(status_code=404, detail="笔记不存在")

    provider_url = (await crud.get_setting(db, "ai.provider_url") or "").strip()
    provider_key = (await crud.get_setting(db, "ai.api_key") or os.getenv("DEEPSEEK_API_KEY") or os.getenv("OPENAI_API_KEY") or "").strip()
    if not provider_key:
        raise HTTPException(status_code=503, detail="云端模型未配置 API Key，已降级为端侧整理")

    text = _note_text(note)
    if not text:
        raise HTTPException(status_code=400, detail="笔记内容为空，无法总结")

    prompt = (
        "你是 Llama Llist 的笔记整理助手。请只返回 JSON，不要添加解释。\n"
        "JSON 字段：summary(string, 80-220字中文摘要), keywords(array, 3-8个短关键词), "
        "todos(array, 从内容中识别出的行动项，可为空)。\n"
        "要求：不要编造未出现的事实；如果内容偏短，摘要也要简洁；行动项必须可执行。\n\n"
        f"笔记内容：\n{text[:6000]}"
    )

    url = provider_url.rstrip("/") if provider_url else "https://api.deepseek.com/v1/chat/completions"
    headers = {"Authorization": f"Bearer {provider_key}", "Content-Type": "application/json"}
    payload = {
        "model": "deepseek-chat",
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.2,
        "max_tokens": 900,
    }

    try:
        async with httpx.AsyncClient(timeout=18.0) as client:
            response = await client.post(url, headers=headers, json=payload)
            response.raise_for_status()
            data = response.json()
    except httpx.TimeoutException:
        raise HTTPException(status_code=504, detail="云端总结超时，已降级为端侧整理")
    except httpx.RequestError as exc:
        raise HTTPException(status_code=502, detail=f"云端模型请求失败: {exc}")
    except httpx.HTTPStatusError as exc:
        detail = exc.response.text[:300] if exc.response is not None else "unknown error"
        raise HTTPException(status_code=exc.response.status_code, detail=f"云端模型错误: {detail}")

    content = ""
    try:
        content = data.get("choices", [])[0].get("message", {}).get("content", "")
    except Exception:
        content = ""

    parsed = _extract_json_object(content)
    if parsed:
        summary = _clip_summary(str(parsed.get("summary") or ""))
        keywords = _dedupe(parsed.get("keywords"), 8)
        todos = _dedupe(parsed.get("todos"), 10)
    else:
        summary = _clip_summary(content)
        keywords = []
        todos = []

    if not summary:
        raise HTTPException(status_code=502, detail="云端模型返回为空，已降级为端侧整理")

    return {"note_id": note_id, "summary": summary, "keywords": keywords, "todos": todos}


@router.post("/ai/apply_todos/{note_id}")
@router.post("/notes/{note_id}/ai/apply_todos")
async def apply_todos(note_id: int, payload: Dict[str, Any] = Body(...), db: AsyncSession = Depends(get_db)):
    note = await crud.get_note(db, note_id)
    if not note:
        raise HTTPException(status_code=404, detail="笔记不存在")

    todos = _dedupe(payload.get("todos") or [], 20)
    if not todos:
        raise HTTPException(status_code=400, detail="没有可写入的待办")

    created = []
    for title in todos:
        db_todo = await crud.create_todo(db, schemas.TodoCreate(title=title, note_id=note_id))
        created.append(db_todo)

    return {"created": created, "count": len(created)}


@router.post("/ai/regenerate/{note_id}")
@router.post("/notes/{note_id}/ai/regenerate")
async def regenerate_extract(note_id: int, db: AsyncSession = Depends(get_db)):
    return await local_extract(note_id, db)
