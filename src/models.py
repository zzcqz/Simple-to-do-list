from __future__ import annotations

from dataclasses import dataclass, field
from typing import Optional


@dataclass
class EventRow:
    id: int
    title: str
    note: str
    start_at: int  # unix seconds
    end_at: int
    urgent: bool
    done: bool
    sort_order: int
    created_at: int
    updated_at: int
    parent_id: Optional[int] = None

    @property
    def is_parent(self) -> bool:
        return self.parent_id is None


@dataclass
class ParentWithChildren:
    parent: EventRow
    children: list[EventRow] = field(default_factory=list)
