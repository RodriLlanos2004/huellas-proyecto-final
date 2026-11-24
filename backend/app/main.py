"""Servicio web REST de Huellas Comunidad (FastAPI + MySQL).

La app móvil lo consume para:
  * registrar al usuario con su alias,
  * publicar entradas del diario (datos + foto) en MySQL,
  * consultar las publicaciones (lista, detalle, filtros) y estadísticas,
  * marcar "me gusta" y eliminar sus propias publicaciones.

Documentación interactiva: http://localhost:8000/docs
"""

import uuid
from collections.abc import Iterator
from typing import Annotated

import pymysql
from fastapi import Depends, FastAPI, File, Form, HTTPException, Query, Request, UploadFile, status
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import ValidationError

from . import repositorio as repo
from .config import cargar
from .db import BaseDatosNoDisponible, conectar
from .esquemas import (
    Categoria,
    EstadoMeGusta,
    Estadisticas,
    MeGustaEntrada,
    PaginaPublicaciones,
    Publicacion,
    PublicacionEntrada,
    Usuario,
    UsuarioEntrada,
)

cfg = cargar()
cfg.carpeta_fotos.mkdir(parents=True, exist_ok=True)

app = FastAPI(
    title="Huellas Comunidad API",
    version="1.0.0",
    description="Servicio web del proyecto final de Programación de Dispositivos Móviles.",
)
app.mount("/fotos", StaticFiles(directory=cfg.carpeta_fotos), name="fotos")

_TIPOS_FOTO = {"image/jpeg": ".jpg", "image/png": ".png"}


# ------------------------------------------------------------------ utilidades

def conexion() -> Iterator[pymysql.connections.Connection]:
    """Dependencia: abre una conexión por petición y confirma o revierte al final."""
    with conectar(cfg) as cn:
        yield cn


Conexion = Annotated[pymysql.connections.Connection, Depends(conexion)]


@app.exception_handler(BaseDatosNoDisponible)
async def _bd_caida(_: Request, e: BaseDatosNoDisponible) -> JSONResponse:
    return JSONResponse(status_code=503, content={"detail": "La base de datos no está disponible."})


def _a_publicacion(fila: dict, request: Request) -> Publicacion:
    foto = fila.get("foto")
    return Publicacion(
        **{k: v for k, v in fila.items() if k != "foto"},
        foto_url=str(request.url_for("fotos", path=foto)) if foto else None,
    )


# ------------------------------------------------------------------ endpoints

@app.get("/api/salud", tags=["sistema"])
def salud(cn: Conexion) -> dict:
    with cn.cursor() as cur:
        cur.execute("SELECT VERSION() AS version")
        return {"estado": "ok", "mysql": cur.fetchone()["version"]}


@app.post("/api/usuarios", response_model=Usuario, tags=["usuarios"])
def registrar_usuario(datos: UsuarioEntrada, cn: Conexion) -> dict:
    try:
        return repo.registrar_usuario(cn, datos.alias, datos.dispositivo)
    except repo.AliasOcupado:
        raise HTTPException(status.HTTP_409_CONFLICT, "Ese alias ya lo usa otra persona.")


@app.get("/api/categorias", response_model=list[Categoria], tags=["catálogos"])
def listar_categorias(cn: Conexion) -> list[dict]:
    return repo.categorias(cn)


@app.get("/api/publicaciones", response_model=PaginaPublicaciones, tags=["publicaciones"])
def listar_publicaciones(
    request: Request,
    cn: Conexion,
    categoria_id: int | None = Query(None, ge=1, le=6),
    usuario_id: int | None = Query(None, gt=0),
    q: str | None = Query(None, max_length=60, description="Busca en título y texto"),
    limite: int = Query(30, ge=1, le=100),
    desplazamiento: int = Query(0, ge=0),
) -> PaginaPublicaciones:
    total, filas = repo.listar_publicaciones(
        cn, categoria_id=categoria_id, usuario_id=usuario_id, texto=q,
        limite=limite, desplazamiento=desplazamiento,
    )
    return PaginaPublicaciones(total=total, elementos=[_a_publicacion(f, request) for f in filas])


@app.get("/api/publicaciones/{publicacion_id}", response_model=Publicacion, tags=["publicaciones"])
def obtener_publicacion(publicacion_id: int, request: Request, cn: Conexion) -> Publicacion:
    fila = repo.obtener_publicacion(cn, publicacion_id)
    if fila is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "La publicación no existe.")
    return _a_publicacion(fila, request)


@app.post(
    "/api/publicaciones",
    response_model=Publicacion,
    status_code=status.HTTP_201_CREATED,
    tags=["publicaciones"],
    responses={200: {"description": "La entrada ya estaba publicada; se devuelve la existente."}},
)
async def publicar(
    request: Request,
    cn: Conexion,
    datos: Annotated[str, Form(description="JSON con los campos de PublicacionEntrada")],
    foto: Annotated[UploadFile | None, File()] = None,
):
    try:
        entrada = PublicacionEntrada.model_validate_json(datos)
    except ValidationError as e:
        raise HTTPException(422, e.errors(include_url=False, include_context=False))

    if not repo.existe_usuario(cn, entrada.usuario_id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "El usuario no está registrado.")

    # RN-07: si la entrada ya se publicó, se devuelve la existente (reintentos seguros).
    existente = repo.buscar_por_origen(cn, entrada.usuario_id, entrada.id_local)
    if existente is not None:
        return JSONResponse(_a_publicacion(existente, request).model_dump(mode="json"), status_code=200)

    nombre_foto = None
    if foto is not None and foto.filename:
        extension = _TIPOS_FOTO.get(foto.content_type or "")
        if extension is None:
            raise HTTPException(status.HTTP_415_UNSUPPORTED_MEDIA_TYPE, "La foto debe ser JPG o PNG.")
        contenido = await foto.read()
        if len(contenido) > cfg.max_foto_bytes:
            raise HTTPException(status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, "La foto supera los 5 MB.")
        nombre_foto = f"{uuid.uuid4().hex}{extension}"
        (cfg.carpeta_fotos / nombre_foto).write_bytes(contenido)

    try:
        nuevo_id = repo.insertar_publicacion(cn, entrada, nombre_foto)
    except pymysql.err.IntegrityError as e:
        if nombre_foto:
            (cfg.carpeta_fotos / nombre_foto).unlink(missing_ok=True)
        raise HTTPException(status.HTTP_409_CONFLICT, f"Los datos violan una regla de la base: {e.args[-1]}")
    return _a_publicacion(repo.obtener_publicacion(cn, nuevo_id), request)


@app.delete("/api/publicaciones/{publicacion_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["publicaciones"])
def eliminar_publicacion(publicacion_id: int, cn: Conexion, usuario_id: int = Query(gt=0)) -> None:
    fila = repo.obtener_publicacion(cn, publicacion_id)
    if fila is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "La publicación no existe.")
    # RN-10: solo el autor puede eliminar su publicación.
    if fila["usuario_id"] != usuario_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Solo el autor puede eliminar esta publicación.")
    repo.eliminar_publicacion(cn, publicacion_id)
    if fila["foto"]:
        (cfg.carpeta_fotos / fila["foto"]).unlink(missing_ok=True)


@app.post("/api/publicaciones/{publicacion_id}/me-gusta", response_model=EstadoMeGusta, tags=["publicaciones"])
def me_gusta(publicacion_id: int, datos: MeGustaEntrada, cn: Conexion) -> EstadoMeGusta:
    if repo.obtener_publicacion(cn, publicacion_id) is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "La publicación no existe.")
    if not repo.existe_usuario(cn, datos.usuario_id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "El usuario no está registrado.")
    marcado, total = repo.alternar_me_gusta(cn, publicacion_id, datos.usuario_id)
    return EstadoMeGusta(publicacion_id=publicacion_id, me_gusta=total, marcado=marcado)


@app.get("/api/estadisticas", response_model=Estadisticas, tags=["consultas"])
def estadisticas(cn: Conexion) -> dict:
    return repo.estadisticas(cn)
