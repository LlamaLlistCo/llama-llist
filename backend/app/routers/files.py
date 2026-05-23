import os
import uuid
from fastapi import APIRouter, UploadFile, File, HTTPException, status

MAX_UPLOAD_SIZE = 5 * 1024 * 1024

router = APIRouter(prefix="/files", tags=["files"])

@router.post("/upload", status_code=status.HTTP_201_CREATED)
async def upload_file(file: UploadFile = File(...)):
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="仅支持图片文件")

    base_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    upload_dir = os.path.join(base_dir, "uploads")
    os.makedirs(upload_dir, exist_ok=True)

    ext = os.path.splitext(file.filename or "")[1].lower()
    allowed_ext = {".jpg", ".jpeg", ".png", ".webp", ".gif"}
    if ext and ext not in allowed_ext:
        raise HTTPException(status_code=400, detail="仅支持 jpg/jpeg/png/webp/gif")
    if not ext:
        ext = ".jpg"
    filename = f"{uuid.uuid4().hex}{ext}"
    save_path = os.path.join(upload_dir, filename)

    data = await file.read()
    if len(data) > MAX_UPLOAD_SIZE:
        raise HTTPException(status_code=413, detail="图片超过 5MB 限制")
    with open(save_path, "wb") as f:
        f.write(data)

    return {"url": f"/uploads/{filename}"}
