import time
import socket
import os
import colorama
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from starlette.middleware.base import BaseHTTPMiddleware
from app.database import init_db
from app.routers import notes
from app.routers import tags
from app.routers import todos
from app.routers import files

# 初始化 colorama
colorama.init()

app = FastAPI(title="Llama Llist API", version="0.1.0")

# 静态文件（uploads）
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UPLOAD_DIR = os.path.join(BASE_DIR, "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")

# 获取本机局域网 IP
def get_local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"

# CORS 中间件
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 彩色请求日志中间件
class LogMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        start = time.time()
        response = await call_next(request)
        duration = (time.time() - start) * 1000
        status = response.status_code
        if 200 <= status < 300:
            color = colorama.Fore.GREEN
        elif 300 <= status < 400:
            color = colorama.Fore.YELLOW
        elif 400 <= status < 600:
            color = colorama.Fore.RED
        else:
            color = colorama.Fore.WHITE
        print(
            f"{colorama.Fore.CYAN}[{time.strftime('%H:%M:%S')}]{colorama.Style.RESET_ALL} "
            f"{colorama.Fore.BLUE}{request.method}{colorama.Style.RESET_ALL} "
            f"{request.url.path} → "
            f"{color}{status}{colorama.Style.RESET_ALL} "
            f"({duration:.1f}ms)"
        )
        return response

app.add_middleware(LogMiddleware)

@app.on_event("startup")
async def startup():
    await init_db()
    local_ip = get_local_ip()
    print("\n" + "=" * 60)
    print(f"✅ {colorama.Fore.GREEN}Llama Llist 后端已成功启动！{colorama.Style.RESET_ALL}")
    print(f"📍 本地地址: http://127.0.0.1:8000")
    print(f"🌐 网络地址: http://{local_ip}:8000")
    print(f"📖 API 文档: http://127.0.0.1:8000/docs")
    print("=" * 60 + "\n")

app.include_router(notes.router)
app.include_router(tags.router)
app.include_router(todos.router)
app.include_router(files.router)

@app.get("/")
async def root():
    return {"message": "Llama Llist backend is running"}
