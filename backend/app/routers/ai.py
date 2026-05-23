from fastapi import APIRouter, Depends, HTTPException, Body
from pydantic import BaseModel, Field, HttpUrl
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


class ApplyTodosPayload(BaseModel):
    todos: list[str] = Field(default_factory=list, max_length=20)


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


def _local_fallback_summary(text: str) -> Dict[str, Any]:
    local = extract_from_text(text)
    keywords = _dedupe(local.get("keywords"), 8)
    todos = _dedupe(local.get("todos"), 10)
    labels = _dedupe(local.get("labels"), 5)
    source = "；".join((text or "").splitlines())
    source = re.sub(r"\s+", " ", source).strip()
    summary_seed = source[:160]
    if not summary_seed:
        summary_seed = "当前内容较少，建议补充关键信息后再总结。"
    summary = _clip_summary(f"本地算法总结：{summary_seed}")
    return {"summary": summary, "keywords": keywords, "todos": todos, "labels": labels}


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

    text = _note_text(note)
    if not text:
        raise HTTPException(status_code=400, detail="笔记内容为空，无法总结")

    provider_url = (await crud.get_setting(db, "ai.provider_url") or "").strip()
    provider_key = (await crud.get_setting(db, "ai.api_key") or os.getenv("DEEPSEEK_API_KEY") or os.getenv("OPENAI_API_KEY") or "").strip()
    model_name = (await crud.get_setting(db, "ai.model_name") or "deepseek-chat").strip()

    if not provider_key:
        fallback = _local_fallback_summary(text)
        return {
            "note_id": note_id,
            "summary": fallback["summary"],
            "keywords": fallback["keywords"],
            "todos": fallback["todos"],
            "source": "local_fallback",
            "reason": "云端模型未配置 API Key"
        }

    prompt = (
        "你是 Llama Llist 的笔记整理助手。请只返回 JSON，不要添加解释。\n"
        "JSON 字段：summary(string, 80-220字中文摘要), keywords(array, 3-8个短关键词), "
        "todos(array, 从内容中识别出的行动项，可为空)。\n"
        "要求：不要编造未出现的事实；如果内容偏短，摘要也要简洁；行动项必须可执行。\n\n"
        f"笔记内容：\n{text[:6000]}"
    )

    url = provider_url.rstrip("/") if provider_url else "https://api.deepseek.com/v1/chat/completions"
    if provider_url:
        try:
            parsed_url = HttpUrl(provider_url)
            if parsed_url.scheme != "https":
                raise HTTPException(status_code=400, detail="云端 Provider URL 必须使用 HTTPS")
        except Exception:
            raise HTTPException(status_code=400, detail="云端 Provider URL 格式不合法")

    headers = {"Authorization": f"Bearer {provider_key}", "Content-Type": "application/json"}
    payload = {
        "model": model_name,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.2,
        "max_tokens": 900,
    }

    data: Dict[str, Any] = {}
    try:
        async with httpx.AsyncClient(timeout=18.0) as client:
            response = await client.post(url, headers=headers, json=payload)
            response.raise_for_status()
            try:
                data = response.json()
            except json.JSONDecodeError:
                fallback = _local_fallback_summary(text)
                return {
                    "note_id": note_id,
                    "summary": fallback["summary"],
                    "keywords": fallback["keywords"],
                    "todos": fallback["todos"],
                    "source": "local_fallback",
                    "reason": "云端返回非 JSON 或空响应"
                }
    except (httpx.TimeoutException, httpx.RequestError, httpx.HTTPStatusError):
        fallback = _local_fallback_summary(text)
        return {
            "note_id": note_id,
            "summary": fallback["summary"],
            "keywords": fallback["keywords"],
            "todos": fallback["todos"],
            "source": "local_fallback",
            "reason": "云端请求失败，已自动降级"
        }

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
        fallback = _local_fallback_summary(text)
        return {
            "note_id": note_id,
            "summary": fallback["summary"],
            "keywords": fallback["keywords"],
            "todos": fallback["todos"],
            "source": "local_fallback",
            "reason": "云端返回为空，已自动降级"
        }

    return {"note_id": note_id, "summary": summary, "keywords": keywords, "todos": todos, "source": "cloud"}



@router.post("/ai/apply_todos/{note_id}")
@router.post("/notes/{note_id}/ai/apply_todos")
async def apply_todos(note_id: int, payload: ApplyTodosPayload = Body(...), db: AsyncSession = Depends(get_db)):
    note = await crud.get_note(db, note_id)
    if not note:
        raise HTTPException(status_code=404, detail="笔记不存在")

    todos = _dedupe(payload.todos, 20)
    if not todos:
        raise HTTPException(status_code=400, detail="没有可写入的待办")

    created = []
    for title in todos:
        db_todo = await crud.create_todo(db, schemas.TodoCreate(title=title, note_id=note_id))
        created.append(db_todo)

    return {"created": created, "count": len(created)}




@router.get("/notes/search/index")
async def notes_search_index(q: str, limit: int = 20, db: AsyncSession = Depends(get_db)):
    keyword = (q or "").strip()
    if not keyword:
        raise HTTPException(status_code=400, detail="搜索关键词不能为空")
    keyword_lower = keyword.lower()

    notes = await crud.get_notes(db, skip=0, limit=500)
    scored: list[Dict[str, Any]] = []
    for note in notes:
        title = (note.title or "")
        summary = (note.summary or "")
        content = (note.content or "")

        title_l = title.lower()
        summary_l = summary.lower()
        content_l = content.lower()

        score = 0
        score += title_l.count(keyword_lower) * 5
        score += summary_l.count(keyword_lower) * 3
        score += content_l.count(keyword_lower) * 1

        tokens = _dedupe(extract_from_text(_note_text(note)).get("keywords"), 8)
        if keyword_lower in [t.lower() for t in tokens]:
            score += 4

        if score > 0:
            scored.append({
                "id": note.id,
                "title": title,
                "summary": summary,
                "score": score,
                "keywords": tokens,
                "updated_at": note.updated_at,
            })

    scored.sort(key=lambda x: x["score"], reverse=True)
    return {"query": keyword, "count": len(scored), "items": scored[:max(1, min(limit, 100))]}
