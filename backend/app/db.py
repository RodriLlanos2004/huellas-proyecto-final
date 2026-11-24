"""Conexión a MySQL con PyMySQL.

Cada petición HTTP obtiene su propia conexión (dependencia de FastAPI) y la
cierra al terminar. Para el volumen de un proyecto escolar es suficiente y
evita compartir estado entre hilos.
"""

from collections.abc import Iterator
from contextlib import contextmanager

import pymysql
from pymysql.cursors import DictCursor

from .config import Configuracion


class BaseDatosNoDisponible(Exception):
    """MySQL no respondió (apagado, credenciales incorrectas, red caída)."""


@contextmanager
def conectar(cfg: Configuracion) -> Iterator[pymysql.connections.Connection]:
    try:
        conexion = pymysql.connect(
            host=cfg.bd_host,
            port=cfg.bd_puerto,
            user=cfg.bd_usuario,
            password=cfg.bd_contrasena,
            database=cfg.bd_nombre,
            charset="utf8mb4",
            cursorclass=DictCursor,
            autocommit=False,
            connect_timeout=5,
        )
    except pymysql.err.OperationalError as e:
        raise BaseDatosNoDisponible(str(e)) from e
    try:
        yield conexion
        conexion.commit()
    except Exception:
        conexion.rollback()
        raise
    finally:
        conexion.close()
