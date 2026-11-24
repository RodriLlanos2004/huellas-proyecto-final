"""Acceso a datos: todas las sentencias SQL del servicio web.

Se usan consultas parametrizadas (%s) en todos los casos, nunca se
concatena texto del usuario dentro del SQL: así se evita la inyección SQL.
"""

from typing import Any

import pymysql

from .esquemas import PublicacionEntrada

Fila = dict[str, Any]


class AliasOcupado(Exception):
    pass


def registrar_usuario(cn: pymysql.connections.Connection, alias: str, dispositivo: str) -> Fila:
    """Crea el usuario o, si el dispositivo ya existe, actualiza su alias (RN-08)."""
    with cn.cursor() as cur:
        cur.execute("SELECT id FROM usuarios WHERE alias = %s AND dispositivo <> %s", (alias, dispositivo))
        if cur.fetchone():
            raise AliasOcupado(alias)
        cur.execute(
            """
            INSERT INTO usuarios (alias, dispositivo) VALUES (%s, %s)
            ON DUPLICATE KEY UPDATE alias = VALUES(alias)
            """,
            (alias, dispositivo),
        )
        cur.execute("SELECT id, alias, creado_en FROM usuarios WHERE dispositivo = %s", (dispositivo,))
        return cur.fetchone()


def existe_usuario(cn: pymysql.connections.Connection, usuario_id: int) -> bool:
    with cn.cursor() as cur:
        cur.execute("SELECT 1 FROM usuarios WHERE id = %s", (usuario_id,))
        return cur.fetchone() is not None


def categorias(cn: pymysql.connections.Connection) -> list[Fila]:
    with cn.cursor() as cur:
        cur.execute("SELECT id, nombre, icono, color FROM categorias ORDER BY id")
        return list(cur.fetchall())


def listar_publicaciones(
    cn: pymysql.connections.Connection,
    *,
    categoria_id: int | None,
    usuario_id: int | None,
    texto: str | None,
    limite: int,
    desplazamiento: int,
) -> tuple[int, list[Fila]]:
    condiciones: list[str] = []
    parametros: list[Any] = []
    if categoria_id is not None:
        condiciones.append("categoria_id = %s")
        parametros.append(categoria_id)
    if usuario_id is not None:
        condiciones.append("usuario_id = %s")
        parametros.append(usuario_id)
    if texto:
        condiciones.append("(titulo LIKE %s OR texto LIKE %s)")
        patron = f"%{texto}%"
        parametros += [patron, patron]
    where = f"WHERE {' AND '.join(condiciones)}" if condiciones else ""
    with cn.cursor() as cur:
        cur.execute(f"SELECT COUNT(*) AS total FROM v_publicaciones {where}", parametros)
        total = cur.fetchone()["total"]
        cur.execute(
            f"SELECT * FROM v_publicaciones {where} ORDER BY fecha DESC, id DESC LIMIT %s OFFSET %s",
            [*parametros, limite, desplazamiento],
        )
        return total, list(cur.fetchall())


def obtener_publicacion(cn: pymysql.connections.Connection, publicacion_id: int) -> Fila | None:
    with cn.cursor() as cur:
        cur.execute("SELECT * FROM v_publicaciones WHERE id = %s", (publicacion_id,))
        return cur.fetchone()


def buscar_por_origen(cn: pymysql.connections.Connection, usuario_id: int, id_local: int) -> Fila | None:
    with cn.cursor() as cur:
        cur.execute(
            "SELECT * FROM v_publicaciones WHERE usuario_id = %s AND id_local = %s",
            (usuario_id, id_local),
        )
        return cur.fetchone()


def insertar_publicacion(cn: pymysql.connections.Connection, p: PublicacionEntrada, foto: str | None) -> int:
    with cn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO publicaciones
              (usuario_id, categoria_id, id_local, titulo, texto, fecha, animo,
               calificacion, gasto, favorita, latitud, longitud, foto)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """,
            (
                p.usuario_id, p.categoria_id, p.id_local, p.titulo, p.texto, p.fecha, p.animo,
                p.calificacion, p.gasto, p.favorita, p.latitud, p.longitud, foto,
            ),
        )
        return cur.lastrowid


def eliminar_publicacion(cn: pymysql.connections.Connection, publicacion_id: int) -> None:
    with cn.cursor() as cur:
        cur.execute("DELETE FROM publicaciones WHERE id = %s", (publicacion_id,))


def alternar_me_gusta(cn: pymysql.connections.Connection, publicacion_id: int, usuario_id: int) -> tuple[bool, int]:
    """Marca o desmarca el "me gusta" (RN-11: uno por usuario). Devuelve (marcado, total)."""
    with cn.cursor() as cur:
        borradas = cur.execute(
            "DELETE FROM me_gusta WHERE usuario_id = %s AND publicacion_id = %s",
            (usuario_id, publicacion_id),
        )
        if borradas == 0:
            cur.execute(
                "INSERT INTO me_gusta (usuario_id, publicacion_id) VALUES (%s, %s)",
                (usuario_id, publicacion_id),
            )
        cur.execute("SELECT COUNT(*) AS n FROM me_gusta WHERE publicacion_id = %s", (publicacion_id,))
        return borradas == 0, cur.fetchone()["n"]


def estadisticas(cn: pymysql.connections.Connection) -> Fila:
    with cn.cursor() as cur:
        cur.execute(
            """
            SELECT COUNT(*) AS total_publicaciones,
                   (SELECT COUNT(*) FROM usuarios) AS total_usuarios,
                   ROUND(AVG(calificacion), 1) AS promedio_calificacion,
                   COALESCE(SUM(gasto), 0) AS gasto_total
            FROM publicaciones
            """
        )
        resumen = cur.fetchone()
        cur.execute(
            """
            SELECT c.id AS categoria_id, c.nombre AS categoria, c.color,
                   COUNT(p.id) AS total,
                   ROUND(AVG(p.calificacion), 1) AS promedio_calificacion,
                   COALESCE(SUM(p.gasto), 0) AS gasto_total
            FROM categorias c
            LEFT JOIN publicaciones p ON p.categoria_id = c.id
            GROUP BY c.id, c.nombre, c.color
            ORDER BY total DESC, c.id
            """
        )
        resumen["por_categoria"] = list(cur.fetchall())
        cur.execute("SELECT animo, COUNT(*) AS n FROM publicaciones GROUP BY animo")
        resumen["por_animo"] = {f["animo"]: f["n"] for f in cur.fetchall()}
        return resumen
