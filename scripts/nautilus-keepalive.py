#!/usr/bin/python3
"""nautilus-keepalive: nautilus сам завершается через ~0.5–3 мин без открытых
окон (inactivity-timeout зашит в коде, настройки нет). Следующее открытие
после простоя = свежий процесс = холодный старт (~0.6с+ с тяжёлой темой
иконок вроде Papirus: резолв иконки там ~1.5мс против ~0.07мс у Adwaita,
плюс ~1мс на файл в больших папках).

Этот вотчер следит за bus-именем org.gnome.Nautilus и поднимает тёплый
демон СРАЗУ по событию смерти (а не по пулингу): окно уязвимости — только
~0.6с спавна. Проверка pgrep перед запуском исключает гонку с D-Bus-
активацией: если демон уже есть — ничего не делаем.

Бонус: чинит отсутствующие в Papirus эмблемы unwritable-* (их нет ни в одной
теме, каждое обращение — полный проход по цепочке Papirus→breeze→hicolor
до image-missing + WARNING в логе). Кладёт симлинки на emblem-locked в
~/.local/share/icons/hicolor (user-dir мержится с системным, кэш пересобирать
не нужно — несвежие директории читаются напрямую).
"""
import os
import subprocess
import sys

from gi.repository import Gio, GLib

BUS_NAME = "org.gnome.Nautilus"
NAUTILUS = "/usr/bin/nautilus"
EMBLEM_NAMES = (
    "emblem-unwritable",
    "unwritable",
    "emblem-unwritable-symbolic",
    "unwritable-symbolic",
)
EMBLEM_SRC = {
    "16x16/emblems": "/usr/share/icons/Papirus/16x16/emblems/emblem-locked.svg",
    "scalable/emblems": "/usr/share/icons/Papirus/48x48/emblems/emblem-locked.svg",
}


def daemon_alive() -> bool:
    return (
        subprocess.run(["pgrep", "-x", "nautilus"], capture_output=True).returncode
        == 0
    )


def spawn_daemon() -> None:
    if daemon_alive():
        return
    try:
        subprocess.Popen(
            [NAUTILUS, "--gapplication-service"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except OSError:
        pass


def ensure_unwritable_emblems() -> None:
    base = os.path.expanduser("~/.local/share/icons/hicolor")
    for subdir, src in EMBLEM_SRC.items():
        if not os.path.exists(src):
            continue
        d = os.path.join(base, subdir)
        try:
            os.makedirs(d, exist_ok=True)
        except OSError:
            continue
        for name in EMBLEM_NAMES:
            link = os.path.join(d, name + ".svg")
            try:
                if os.path.islink(link):
                    if os.readlink(link) == src:
                        continue
                    os.unlink(link)
                elif os.path.exists(link):
                    continue
                os.symlink(src, link)
            except OSError:
                pass


def on_appeared(_conn, _name, _owner) -> None:
    pass


def on_vanished(_conn, _name) -> None:
    GLib.timeout_add(300, _respawn_cb)


def _respawn_cb() -> bool:
    spawn_daemon()
    return False


def main() -> int:
    ensure_unwritable_emblems()
    Gio.bus_watch_name(
        Gio.BusType.SESSION,
        BUS_NAME,
        Gio.BusNameWatcherFlags.NONE,
        on_appeared,
        on_vanished,
    )
    if not daemon_alive():
        spawn_daemon()
    try:
        GLib.MainLoop().run()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
