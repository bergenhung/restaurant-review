"""Name matching across sources (e.g. "Joe's Pizza" vs "Joe’s Pizza - Broadway")."""
import re
import unicodedata
from difflib import SequenceMatcher

_NOISE = re.compile(r"\b(restaurant|the|cafe|bar|kitchen|grill|llc|inc)\b|[^\w]", re.UNICODE)


def normalize(text: str) -> str:
    text = unicodedata.normalize("NFKC", text or "").lower()
    text = text.split(" - ")[0]  # drop branch suffixes like "- Downtown"
    return _NOISE.sub("", text)


def similarity(a: str, b: str) -> float:
    na, nb = normalize(a), normalize(b)
    if not na or not nb:
        return 0.0
    if na == nb:
        return 1.0
    if na in nb or nb in na:
        return 0.9
    return SequenceMatcher(None, na, nb).ratio()


def has_cjk(text: str) -> bool:
    """True if the text contains Chinese characters."""
    return any("一" <= ch <= "鿿" for ch in text or "")


def km_between(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Straight-line distance between two points on Earth."""
    from math import asin, cos, radians, sin, sqrt
    dlat, dlng = radians(lat2 - lat1), radians(lng2 - lng1)
    a = sin(dlat / 2) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlng / 2) ** 2
    return 6371 * 2 * asin(sqrt(a))
