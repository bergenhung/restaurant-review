"""Open-now and today's hours, worked out in the restaurant's own time zone.

Done when each response is sent (not when it's cached), so a result cached at lunchtime still
says "Closed" at midnight.
"""
from datetime import datetime, timedelta, timezone

from app.models import Hours, ResultTable

WEEK = 7 * 24 * 60


def _minute_of_week(point: dict) -> int:
    # Google: day 0 = Sunday.
    return point.get("day", 0) * 1440 + point.get("hour", 0) * 60 + point.get("minute", 0)


DAYS = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]  # Google's order: day 0 = Sunday


def _open_at(hours: Hours, minute_of_week: int) -> bool:
    for period in hours.periods:
        if "close" not in period:
            return True  # open 24 hours
        start, end = _minute_of_week(period["open"]), _minute_of_week(period["close"])
        if end <= start:
            end += WEEK  # crosses midnight on Saturday night
        if start <= minute_of_week < end or start <= minute_of_week + WEEK < end:
            return True
    return False


def is_open(hours: Hours, now_utc: datetime) -> bool | None:
    if not hours.periods or hours.utc_offset_minutes is None:
        return None
    local = now_utc + timedelta(minutes=hours.utc_offset_minutes)
    return _open_at(hours, ((local.weekday() + 1) % 7) * 1440 + local.hour * 60 + local.minute)


def is_open_on(hours: Hours, day: str, hhmm: str, now_utc: datetime | None = None) -> bool | None:
    """Open on a weekday ("mon".."sun", or "today" in the restaurant's own time zone) at a local
    time ("19:30")? None when the hours aren't known."""
    if not hours.periods:
        return None
    try:
        h, m = (int(x) for x in hhmm.split(":"))
    except ValueError:
        return None
    if day == "today":
        if hours.utc_offset_minutes is None:
            return None
        local = (now_utc or datetime.now(timezone.utc)) + timedelta(minutes=hours.utc_offset_minutes)
        d = (local.weekday() + 1) % 7
    elif day in DAYS:
        d = DAYS.index(day)
    else:
        return None
    return _open_at(hours, d * 1440 + h * 60 + m)


def today_text(hours: Hours, now_utc: datetime) -> str | None:
    if len(hours.weekday_text) != 7:
        return None
    offset = hours.utc_offset_minutes or 0
    line = hours.weekday_text[(now_utc + timedelta(minutes=offset)).weekday()]  # Monday first
    for sep in (": ", "：", ":"):
        if sep in line:
            return line.split(sep, 1)[1].strip()
    return line


def refresh(table: ResultTable, now_utc: datetime | None = None) -> ResultTable:
    now_utc = now_utc or datetime.now(timezone.utc)
    for row in table.rows:
        if row.hours:
            row.hours.open_now = is_open(row.hours, now_utc)
            row.hours.today = today_text(row.hours, now_utc)
    return table
