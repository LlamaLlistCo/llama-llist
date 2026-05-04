import re
from collections import Counter
from typing import List, Dict

STOPWORDS = {
    "the","is","a","an","and","or","to","of","in","on","for","with","that",
    "this","it","as","by","from","be","are","was","were","will","can","should",
}

def _tokens(text: str) -> List[str]:
    words = re.findall(r"\w+", text.lower())
    return [w for w in words if w not in STOPWORDS and len(w) > 2]

def extract_from_text(text: str, max_keywords: int = 6) -> Dict:
    """Lightweight local extraction: keywords, labels, todo-like lines, priority hint.

    This is intentionally simple and deterministic so it can run on-device without ML.
    """
    if not text:
        return {"keywords": [], "labels": [], "todos": [], "priority": "normal"}

    tokens = _tokens(text)
    counts = Counter(tokens)
    keywords = [k for k, _ in counts.most_common(max_keywords)]

    # labels: pick top 3 keywords as suggested labels
    labels = keywords[:3]

    # simple todo extraction: find lines with checkbox or lines starting with dash
    todos = []
    for line in text.splitlines():
        s = line.strip()
        if not s:
            continue
        if s.startswith("- [ ]") or s.startswith("- ") or s.lower().startswith("todo"):
            # clean marker
            cleaned = re.sub(r"^- \[.\]\s*", "", s)
            cleaned = re.sub(r"^-\s*", "", cleaned)
            todos.append(cleaned)

    # if no explicit todos found, try sentence-based heuristic
    if not todos:
        candidates = re.findall(r"([^.?!\n]{20,}?(?:need|should|todo|follow up|follow-up)[^.?!\n]*[.?!]?)", text, flags=re.I)
        for c in candidates:
            todos.append(c.strip())

    # priority heuristic: count urgent words
    urgent_markers = sum(1 for t in tokens if t in {"urgent","important","asap","immediately"})
    if urgent_markers >= 2:
        priority = "high"
    elif urgent_markers == 1:
        priority = "medium"
    else:
        priority = "normal"

    return {
        "keywords": keywords,
        "labels": labels,
        "todos": todos,
        "priority": priority,
    }
