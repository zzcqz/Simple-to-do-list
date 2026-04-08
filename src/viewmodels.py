from __future__ import annotations

import time
from dataclasses import replace
from typing import Any

from PySide6.QtCore import QAbstractListModel, QModelIndex, QObject, Qt, Signal, Slot

from .models import EventRow
from .storage import load_events, save_events


class EventRepository(QObject):
    """
    单一数据源：负责读写持久化与跨列表变更同步。
    """

    changed = Signal()
    event_updated = Signal(int)
    event_deleted = Signal(int)

    def __init__(self, parent: QObject | None = None):
        super().__init__(parent)
        self._events: list[EventRow] = []
        self.reload()

    def events(self) -> list[EventRow]:
        return self._events

    @Slot()
    def reload(self) -> None:
        events = [e for e in load_events() if e.is_parent]
        self._events = events
        self.changed.emit()

    def _persist(self) -> None:
        save_events(self._events)
        self.changed.emit()

    def _persist_silent(self) -> None:
        # 用于仅更新 sort_order 的场景，避免触发两个列表的 reset，保证拖拽动画连续
        save_events(self._events)

    def _find_index(self, event_id: int) -> int:
        for i, e in enumerate(self._events):
            if e.id == event_id:
                return i
        return -1

    @Slot(int, bool)
    def set_done(self, event_id: int, done: bool) -> None:
        idx = self._find_index(event_id)
        if idx < 0:
            return
        now = int(time.time())
        self._events[idx] = replace(self._events[idx], done=done, updated_at=now)
        self._persist()

    @Slot(int, str, str, int, int, bool)
    def update_event(
        self,
        event_id: int,
        title: str,
        note: str,
        start_at: int,
        end_at: int,
        urgent: bool,
    ) -> None:
        idx = self._find_index(event_id)
        if idx < 0:
            return
        now = int(time.time())
        e = self._events[idx]
        self._events[idx] = replace(
            e,
            title=title,
            note=note,
            start_at=start_at,
            end_at=end_at,
            urgent=urgent,
            updated_at=now,
        )
        self._persist()

    @Slot(int, bool)
    def set_urgent(self, event_id: int, urgent: bool) -> None:
        idx = self._find_index(event_id)
        if idx < 0:
            return
        now = int(time.time())
        self._events[idx] = replace(self._events[idx], urgent=urgent, updated_at=now)
        save_events(self._events)
        self.event_updated.emit(event_id)

    @Slot(str, str, int, int, bool)
    def add_event(self, title: str, note: str, start_at: int, end_at: int, urgent: bool) -> None:
        now = int(time.time())
        next_id = (max([e.id for e in self._events], default=1000) + 1) if self._events else 1000

        # sort_order 只在“进行中列表”内有意义；新建默认进入进行中，排到末尾
        in_progress = [e for e in self._events if (e.is_parent and not e.done)]
        next_sort = (max([e.sort_order for e in in_progress], default=-1) + 1) if in_progress else 0

        e = EventRow(
            id=next_id,
            title=title,
            note=note,
            start_at=start_at,
            end_at=end_at,
            urgent=urgent,
            done=False,
            sort_order=next_sort,
            created_at=now,
            updated_at=now,
            parent_id=None,
        )
        self._events.append(e)
        self._persist()

    @Slot(int)
    def delete_event(self, event_id: int) -> None:
        full = load_events()
        n0 = len(full)
        full = [e for e in full if e.id != event_id and e.parent_id != event_id]
        if len(full) == n0:
            return
        save_events(full)
        idx = self._find_index(event_id)
        if idx >= 0:
            self._events.pop(idx)
        self.event_deleted.emit(event_id)

    @Slot(bool, int, int)
    def move_within(self, done_flag: bool, from_row: int, to_row: int) -> None:
        """
        只在当前列表（done_flag 对应的子集）内重排，并写 sort_order。
        """
        subset = [e for e in self._events if (e.is_parent and e.done == done_flag)]
        subset.sort(key=lambda x: (x.sort_order, x.updated_at, x.id))
        if from_row < 0 or to_row < 0:
            return
        if from_row >= len(subset) or to_row >= len(subset):
            return
        if from_row == to_row:
            return

        moved = subset.pop(from_row)
        subset.insert(to_row, moved)

        now = int(time.time())
        # 回写 sort_order 到主列表对应对象
        for i, ev in enumerate(subset):
            idx = self._find_index(ev.id)
            if idx >= 0 and self._events[idx].sort_order != i:
                self._events[idx] = replace(self._events[idx], sort_order=i, updated_at=now)
        self._persist()

    def apply_sort_order(self, done_flag: bool, ordered_ids: list[int]) -> None:
        """
        将同一列表(done_flag)内的顺序写入 sort_order 并持久化（静默）。
        """
        now = int(time.time())
        id_to_rank = {eid: i for i, eid in enumerate(ordered_ids)}
        for i, e in enumerate(self._events):
            if not (e.is_parent and e.done == done_flag):
                continue
            rank = id_to_rank.get(e.id)
            if rank is None:
                continue
            if e.sort_order != rank:
                self._events[i] = replace(e, sort_order=rank, updated_at=now)
        self._persist_silent()


class FilteredEventListModel(QAbstractListModel):
    """
    单个列表：只展示 done_flag 对应的父事件，列表内部按 sort_order 排序。
    """

    IdRole = Qt.UserRole + 1
    TitleRole = Qt.UserRole + 2
    NoteRole = Qt.UserRole + 3
    StartAtRole = Qt.UserRole + 4
    EndAtRole = Qt.UserRole + 5
    UrgentRole = Qt.UserRole + 6
    DoneRole = Qt.UserRole + 7
    SortOrderRole = Qt.UserRole + 8
    UpdatedAtRole = Qt.UserRole + 9

    def __init__(self, repo: EventRepository, done_flag: bool, parent: QObject | None = None):
        super().__init__(parent)
        self._repo = repo
        self._done_flag = done_flag
        self._rows: list[EventRow] = []
        self._repo.changed.connect(self.reload)
        self._repo.event_updated.connect(self._on_repo_event_updated)
        self._repo.event_deleted.connect(self._on_repo_event_deleted)
        self.reload()

    def roleNames(self) -> dict[int, bytes]:
        return {
            self.IdRole: b"id",
            self.TitleRole: b"title",
            self.NoteRole: b"note",
            self.StartAtRole: b"start_at",
            self.EndAtRole: b"end_at",
            self.UrgentRole: b"urgent",
            self.DoneRole: b"done",
            self.SortOrderRole: b"sort_order",
            self.UpdatedAtRole: b"updated_at",
        }

    def rowCount(self, parent: QModelIndex = QModelIndex()) -> int:
        if parent.isValid():
            return 0
        return len(self._rows)

    def data(self, index: QModelIndex, role: int = Qt.DisplayRole) -> Any:
        if not index.isValid():
            return None
        e = self._rows[index.row()]
        if role == self.IdRole:
            return e.id
        if role == self.TitleRole:
            return e.title
        if role == self.NoteRole:
            return e.note
        if role == self.StartAtRole:
            return e.start_at
        if role == self.EndAtRole:
            return e.end_at
        if role == self.UrgentRole:
            return e.urgent
        if role == self.DoneRole:
            return e.done
        if role == self.SortOrderRole:
            return e.sort_order
        if role == self.UpdatedAtRole:
            return e.updated_at
        return None

    @Slot()
    def reload(self) -> None:
        events = [e for e in self._repo.events() if (e.is_parent and e.done == self._done_flag)]
        events.sort(key=lambda x: (x.sort_order, x.updated_at, x.id))
        self.beginResetModel()
        self._rows = events
        self.endResetModel()

    @Slot(int, bool)
    def set_done(self, event_id: int, done: bool) -> None:
        self._repo.set_done(event_id, done)

    @Slot(int, str, str, int, int, bool)
    def update_event(self, event_id: int, title: str, note: str, start_at: int, end_at: int, urgent: bool) -> None:
        self._repo.update_event(event_id, title, note, start_at, end_at, urgent)

    @Slot(str, str, int, int, bool)
    def add_event(self, title: str, note: str, start_at: int, end_at: int, urgent: bool) -> None:
        self._repo.add_event(title, note, start_at, end_at, urgent)

    @Slot(int, int)
    def move(self, from_row: int, to_row: int) -> None:
        if from_row < 0 or to_row < 0:
            return
        if from_row >= len(self._rows) or to_row >= len(self._rows):
            return
        if from_row == to_row:
            return

        # 关键：使用 beginMoveRows/endMoveRows，ListView 才能产生交互式 displaced 动画
        self.beginMoveRows(QModelIndex(), from_row, from_row, QModelIndex(), to_row + (1 if to_row > from_row else 0))
        e = self._rows.pop(from_row)
        self._rows.insert(to_row, e)
        self.endMoveRows()

        self._repo.apply_sort_order(self._done_flag, [x.id for x in self._rows])

    @Slot(int)
    def _on_repo_event_updated(self, event_id: int) -> None:
        row_idx = -1
        for i, e in enumerate(self._rows):
            if e.id == event_id:
                row_idx = i
                break
        if row_idx < 0:
            return
        src = None
        for e in self._repo.events():
            if e.id == event_id:
                src = e
                break
        if src is None:
            return
        self._rows[row_idx] = src
        i = self.index(row_idx, 0)
        self.dataChanged.emit(i, i, [self.TitleRole, self.NoteRole, self.StartAtRole, self.EndAtRole, self.UrgentRole, self.UpdatedAtRole])

    @Slot(int)
    def _on_repo_event_deleted(self, event_id: int) -> None:
        row_idx = -1
        for i, e in enumerate(self._rows):
            if e.id == event_id:
                row_idx = i
                break
        if row_idx < 0:
            return
        self.beginRemoveRows(QModelIndex(), row_idx, row_idx)
        self._rows.pop(row_idx)
        self.endRemoveRows()

