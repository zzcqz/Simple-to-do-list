from __future__ import annotations

import sys
from pathlib import Path

from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuickControls2 import QQuickStyle

from .viewmodels import EventRepository, FilteredEventListModel


def _qml_path() -> Path:
    return Path(__file__).resolve().parent / "qml" / "Main.qml"


def main() -> int:
    # 使用非原生样式，允许自定义 Button/TextField 的 background/contentItem
    QQuickStyle.setStyle("Fusion")
    app = QGuiApplication(sys.argv)
    app.setOrganizationName("Local")
    app.setApplicationName("事务时间表项目v2")

    engine = QQmlApplicationEngine()

    repo = EventRepository()
    in_progress = FilteredEventListModel(repo=repo, done_flag=False)
    done = FilteredEventListModel(repo=repo, done_flag=True)
    engine.rootContext().setContextProperty("repo", repo)
    engine.rootContext().setContextProperty("inProgressModel", in_progress)
    engine.rootContext().setContextProperty("doneModel", done)

    qml = _qml_path()
    engine.load(QUrl.fromLocalFile(str(qml)))
    if not engine.rootObjects():
        return 1
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())

