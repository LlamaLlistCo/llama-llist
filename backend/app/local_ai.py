import re
from collections import Counter
from typing import List, Dict

STOPWORDS = {
    "the", "is", "a", "an", "and", "or", "to", "of", "in", "on", "for", "with",
    "that", "this", "it", "as", "by", "from", "be", "are", "was", "were", "will",
    "can", "should", "今天", "我们", "需要", "进行", "一个", "这个", "那个", "然后",
}

DOMAIN_LABELS = {
    "工作": ["会议", "项目", "需求", "客户", "汇报", "排期", "上线", "复盘"],
    "学习": ["课堂", "作业", "考试", "论文", "阅读", "课程", "知识", "复习"],
    "生活": ["生活", "旅行", "运动", "饮食", "心情", "家庭", "购物", "计划"],
    "创意": ["灵感", "创意", "设计", "想法", "草稿", "文案", "脑暴"],
}

PRIORITY_MARKERS = {
    "important_urgent": ["紧急", "重要", "马上", "今天", "截止", "asap", "urgent", "立即"],
    "important_not_urgent": ["规划", "复盘", "长期", "重要", "学习", "优化"],
    "not_important_urgent": ["提醒", "催", "跟进", "确认"],
}


def _tokens(text: str) -> List[str]:
    lowered = text.lower()
    ascii_words = re.findall(r"[a-zA-Z][a-zA-Z0-9_-]{2,}", lowered)
    chinese_words = re.findall(r"[\u4e00-\u9fff]{2,6}", text)
    words = ascii_words + chinese_words
    return [w for w in words if w not in STOPWORDS and len(w) > 1]


def _extract_todos(text: str) -> List[str]:
    todos: List[str] = []
    for line in text.splitlines():
        raw = line.strip()
        if not raw:
            continue
        if re.match(r"^(-|\*|\d+[.)]|[□☐])\s*(\[.\]\s*)?", raw):
            cleaned = re.sub(r"^(-|\*|\d+[.)]|[□☐])\s*(\[.\]\s*)?", "", raw).strip()
            if cleaned:
                todos.append(cleaned)
        elif re.search(r"(todo|待办|行动项|需要|记得|完成|跟进|截止|提交|确认)", raw, re.I):
            todos.append(raw)

    if not todos:
        sentences = re.split(r"[。！？!?；;\n]", text)
        for sentence in sentences:
            if re.search(r"(需要|应该|记得|跟进|完成|提交|确认|安排|准备|todo|follow up)", sentence, re.I):
                value = sentence.strip()
                if 4 <= len(value) <= 80:
                    todos.append(value)

    deduped: List[str] = []
    for todo in todos:
        if todo not in deduped:
            deduped.append(todo)
    return deduped[:10]


def _suggest_labels(tokens: List[str], keywords: List[str]) -> List[str]:
    labels: List[str] = []
    joined = " ".join(tokens)
    for label, markers in DOMAIN_LABELS.items():
        if any(marker in joined for marker in markers):
            labels.append(label)
    for kw in keywords[:3]:
        if kw not in labels:
            labels.append(kw)
    return labels[:5]


def _priority(text: str) -> str:
    lowered = text.lower()
    urgent_score = sum(1 for marker in PRIORITY_MARKERS["important_urgent"] if marker in lowered)
    plan_score = sum(1 for marker in PRIORITY_MARKERS["important_not_urgent"] if marker in lowered)
    follow_score = sum(1 for marker in PRIORITY_MARKERS["not_important_urgent"] if marker in lowered)
    if urgent_score >= 2:
        return "important_urgent"
    if urgent_score == 1 or follow_score >= 2:
        return "not_important_urgent"
    if plan_score > 0:
        return "important_not_urgent"
    return "not_important_not_urgent"


def extract_from_text(text: str, max_keywords: int = 8) -> Dict:
    """Deterministic local extraction for weak-network and privacy-sensitive scenes."""
    if not text:
        return {"keywords": [], "labels": [], "todos": [], "priority": "not_important_not_urgent"}

    tokens = _tokens(text)
    counts = Counter(tokens)
    keywords = [k for k, _ in counts.most_common(max_keywords)]
    todos = _extract_todos(text)

    return {
        "keywords": keywords,
        "labels": _suggest_labels(tokens, keywords),
        "todos": todos,
        "priority": _priority(text),
    }
