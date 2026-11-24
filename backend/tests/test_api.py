"""Pruebas de integración del API contra una base MySQL/MariaDB real.

Requiere la base creada con database/huellas_comunidad.sql y las variables
BD_USUARIO / BD_CONTRASENA. Ejecutar desde la carpeta backend:

    BD_CONTRASENA=... python -m pytest -q
"""

import json
import os
import tempfile
import uuid
from datetime import datetime, timedelta

import pymysql
import pytest

os.environ.setdefault("CARPETA_FOTOS", tempfile.mkdtemp(prefix="fotos_"))

from fastapi.testclient import TestClient  # noqa: E402

from app.config import cargar  # noqa: E402
from app.main import app  # noqa: E402

cliente = TestClient(app)

# PNG de 1x1 píxel, suficiente para probar la subida.
PNG = bytes.fromhex(
    "89504e470d0a1a0a0000000d4948445200000001000000010806000000"
    "1f15c4890000000d49444154789c6360000002000154a24f5d0000000049454e44ae426082"
)


@pytest.fixture(autouse=True)
def base_limpia():
    cfg = cargar()
    cn = pymysql.connect(host=cfg.bd_host, port=cfg.bd_puerto, user=cfg.bd_usuario,
                         password=cfg.bd_contrasena, database=cfg.bd_nombre, autocommit=True)
    with cn.cursor() as cur:
        cur.execute("DELETE FROM me_gusta")
        cur.execute("DELETE FROM publicaciones")
        cur.execute("DELETE FROM usuarios")
    cn.close()


def registrar(alias="rodri", dispositivo=None):
    r = cliente.post("/api/usuarios", json={"alias": alias, "dispositivo": dispositivo or str(uuid.uuid4())})
    assert r.status_code == 200, r.text
    return r.json()


def datos_publicacion(usuario_id, **cambios):
    base = {
        "usuario_id": usuario_id,
        "categoria_id": 1,
        "id_local": 7,
        "titulo": "Atardecer en Progreso",
        "texto": "Fuimos al malecón a ver el atardecer.",
        "fecha": "2026-11-20T18:30:00",
        "animo": "radiante",
        "calificacion": 9,
        "gasto": 250.5,
        "favorita": True,
        "latitud": 21.2833,
        "longitud": -89.6667,
    }
    base.update(cambios)
    return base


def publicar(datos, foto=True):
    archivos = {"foto": ("foto.png", PNG, "image/png")} if foto else None
    return cliente.post("/api/publicaciones", data={"datos": json.dumps(datos)}, files=archivos)


def test_salud_reporta_mysql():
    r = cliente.get("/api/salud")
    assert r.status_code == 200
    assert r.json()["estado"] == "ok"


def test_categorias_del_catalogo():
    r = cliente.get("/api/categorias")
    assert [c["nombre"] for c in r.json()] == ["Viajes", "Comida", "Escuela", "Familia", "Deporte", "Otro"]


def test_registro_es_idempotente_por_dispositivo_y_cambia_alias():
    disp = str(uuid.uuid4())
    a = registrar("rodri", disp)
    b = registrar("rodri_ll", disp)
    assert a["id"] == b["id"] and b["alias"] == "rodri_ll"


def test_alias_ocupado_por_otro_dispositivo_da_409():
    registrar("rodri")
    r = cliente.post("/api/usuarios", json={"alias": "rodri", "dispositivo": str(uuid.uuid4())})
    assert r.status_code == 409


def test_alias_invalido_da_422():
    r = cliente.post("/api/usuarios", json={"alias": "a b", "dispositivo": str(uuid.uuid4())})
    assert r.status_code == 422


def test_publicar_con_foto_y_consultar():
    u = registrar()
    r = publicar(datos_publicacion(u["id"]))
    assert r.status_code == 201, r.text
    p = r.json()
    assert p["alias"] == "rodri" and p["categoria"] == "Viajes" and p["me_gusta"] == 0
    assert p["foto_url"].endswith(".png")
    assert cliente.get(p["foto_url"]).content == PNG

    lista = cliente.get("/api/publicaciones").json()
    assert lista["total"] == 1 and lista["elementos"][0]["titulo"] == "Atardecer en Progreso"
    assert cliente.get(f"/api/publicaciones/{p['id']}").json()["gasto"] == 250.5


def test_publicar_dos_veces_la_misma_entrada_no_duplica():
    u = registrar()
    primero = publicar(datos_publicacion(u["id"]), foto=False)
    segundo = publicar(datos_publicacion(u["id"]), foto=False)
    assert primero.status_code == 201 and segundo.status_code == 200
    assert primero.json()["id"] == segundo.json()["id"]
    assert cliente.get("/api/publicaciones").json()["total"] == 1


@pytest.mark.parametrize(
    "cambio",
    [
        {"calificacion": 11},
        {"calificacion": 0},
        {"gasto": -1},
        {"titulo": "   "},
        {"animo": "enojado"},
        {"latitud": 95},
        {"longitud": None},
        {"fecha": (datetime.now() + timedelta(days=5)).isoformat()},
    ],
)
def test_reglas_de_negocio_rechazan_datos_invalidos(cambio):
    u = registrar()
    r = publicar(datos_publicacion(u["id"], **cambio), foto=False)
    assert r.status_code == 422, r.text


def test_foto_de_tipo_no_permitido_da_415():
    u = registrar()
    r = cliente.post(
        "/api/publicaciones",
        data={"datos": json.dumps(datos_publicacion(u["id"]))},
        files={"foto": ("nota.txt", b"hola", "text/plain")},
    )
    assert r.status_code == 415


def test_usuario_inexistente_da_404():
    r = publicar(datos_publicacion(999999), foto=False)
    assert r.status_code == 404


def test_filtros_por_categoria_y_texto():
    u = registrar()
    publicar(datos_publicacion(u["id"], id_local=1, categoria_id=1, titulo="Cenote Xlacah"), foto=False)
    publicar(datos_publicacion(u["id"], id_local=2, categoria_id=2, titulo="Cochinita"), foto=False)
    assert cliente.get("/api/publicaciones?categoria_id=2").json()["total"] == 1
    assert cliente.get("/api/publicaciones?q=cenote").json()["elementos"][0]["titulo"] == "Cenote Xlacah"


def test_me_gusta_alterna_y_es_uno_por_usuario():
    u = registrar()
    p = publicar(datos_publicacion(u["id"]), foto=False).json()
    url = f"/api/publicaciones/{p['id']}/me-gusta"
    assert cliente.post(url, json={"usuario_id": u["id"]}).json() == {"publicacion_id": p["id"], "me_gusta": 1, "marcado": True}
    assert cliente.post(url, json={"usuario_id": u["id"]}).json()["me_gusta"] == 0


def test_solo_el_autor_puede_eliminar():
    autor = registrar("autor")
    otro = registrar("otro")
    p = publicar(datos_publicacion(autor["id"])).json()
    assert cliente.delete(f"/api/publicaciones/{p['id']}?usuario_id={otro['id']}").status_code == 403
    assert cliente.delete(f"/api/publicaciones/{p['id']}?usuario_id={autor['id']}").status_code == 204
    assert cliente.get(f"/api/publicaciones/{p['id']}").status_code == 404


def test_estadisticas():
    u = registrar()
    publicar(datos_publicacion(u["id"], id_local=1, calificacion=8, gasto=100), foto=False)
    publicar(datos_publicacion(u["id"], id_local=2, calificacion=10, gasto=50, animo="feliz"), foto=False)
    e = cliente.get("/api/estadisticas").json()
    assert e["total_publicaciones"] == 2 and e["promedio_calificacion"] == 9.0 and e["gasto_total"] == 150.0
    assert e["por_categoria"][0]["categoria"] == "Viajes" and e["por_categoria"][0]["total"] == 2
    assert e["por_animo"] == {"radiante": 1, "feliz": 1}
