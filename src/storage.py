from __future__ import annotations

import json
import os
import time
from dataclasses import asdict
from pathlib import Path

from .models import EventRow


def _now_s() -> int:
    return int(time.time())


def default_data_path() -> Path:
    root = Path(__file__).resolve().parents[1]
    return root / "data" / "events.json"


def ensure_data_dir(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def load_events(path: Path | None = None) -> list[EventRow]:
    path = path or default_data_path()
    if not path.exists():
        ensure_data_dir(path)
        seed = _seed_events()
        save_events(seed, path)
        return seed

    raw = json.loads(path.read_text(encoding="utf-8"))
    events: list[EventRow] = []
    for item in raw.get("events", []):
        events.append(EventRow(**item))
    return events


def save_events(events: list[EventRow], path: Path | None = None) -> None:
    path = path or default_data_path()
    ensure_data_dir(path)
    payload = {"version": 1, "events": [asdict(e) for e in events]}
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    os.replace(tmp, path)


def _seed_events() -> list[EventRow]:
    now = _now_s()
    one_day = 24 * 3600
    base = now - 3 * one_day
    items: list[EventRow] = []
    for i in range(5):
        start_at = base + i * one_day
        end_at = start_at + (2 + i) * one_day
        items.append(
            EventRow(
                id=1000 + i,
                title=f"示例父事件 {i+1}",
                note="双击编辑；左右滑动完成/恢复；长按拖拽排序。",
                start_at=start_at,
                end_at=end_at,
                urgent=(i == 2),
                done=False,
                sort_order=i,
                created_at=now,
                updated_at=now,
                parent_id=None,
            )
        )
    return items

