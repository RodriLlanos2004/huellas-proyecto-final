"""Modelos de entrada y salida del API (Pydantic).

Aquí viven las reglas de negocio que se validan antes de tocar la base de
datos. Si una petición no las cumple, FastAPI responde 422 con el detalle.
"""

import re
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, Field, field_validator, model_validator

Animo = Literal["radiante", "feliz", "tranquilo", "cansado", "triste"]

_PATRON_ALIAS = re.compile(r"^[A-Za-z0-9_.]{3,20}$")


class UsuarioEntrada(BaseModel):
    alias: str = Field(min_length=3, max_length=20)
    dispositivo: str = Field(min_length=8, max_length=36)

    @field_validator("alias")
    @classmethod
    def alias_valido(cls, v: str) -> str:
        # RN-08: alias de 3 a 20 caracteres, solo letras, números, punto o guion bajo.
        if not _PATRON_ALIAS.match(v):
            raise ValueError("El alias solo admite letras, números, punto y guion bajo (3 a 20).")
        return v


class Usuario(BaseModel):
    id: int
    alias: str
    creado_en: datetime


class Categoria(BaseModel):
    id: int
    nombre: str
    icono: str
    color: str


class PublicacionEntrada(BaseModel):
    """Datos que envía la app al publicar una entrada del diario."""

    usuario_id: int = Field(gt=0)
    categoria_id: int = Field(ge=1, le=6)
    id_local: int = Field(gt=0)
    titulo: str = Field(min_length=1, max_length=60)
    texto: str = Field(min_length=3, max_length=5000)
    fecha: datetime
    animo: Animo
    calificacion: int = Field(ge=1, le=10)
    gasto: Decimal = Field(ge=0, le=100000, max_digits=8, decimal_places=2)
    favorita: bool = False
    latitud: float | None = Field(default=None, ge=-90, le=90)
    longitud: float | None = Field(default=None, ge=-180, le=180)

    @field_validator("titulo", "texto")
    @classmethod
    def sin_espacios_extremos(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("No puede estar vacío.")
        return v

    @field_validator("fecha")
    @classmethod
    def fecha_no_futura(cls, v: datetime) -> datetime:
        # RN-03: un recuerdo no puede tener fecha futura (se tolera 1 día por zonas horarias).
        ahora = datetime.now(timezone.utc) if v.tzinfo else datetime.now()
        if v > ahora + timedelta(days=1):
            raise ValueError("La fecha del recuerdo no puede estar en el futuro.")
        return v.replace(tzinfo=None)

    @model_validator(mode="after")
    def coordenadas_completas(self) -> "PublicacionEntrada":
        if (self.latitud is None) != (self.longitud is None):
            raise ValueError("La ubicación necesita latitud y longitud juntas.")
        return self


class Publicacion(BaseModel):
    id: int
    usuario_id: int
    alias: str
    categoria_id: int
    categoria: str
    categoria_icono: str
    categoria_color: str
    id_local: int
    titulo: str
    texto: str
    fecha: datetime
    animo: str
    calificacion: int
    gasto: float
    favorita: bool
    latitud: float | None
    longitud: float | None
    foto_url: str | None
    publicado_en: datetime
    me_gusta: int


class PaginaPublicaciones(BaseModel):
    total: int
    elementos: list[Publicacion]


class MeGustaEntrada(BaseModel):
    usuario_id: int = Field(gt=0)


class EstadoMeGusta(BaseModel):
    publicacion_id: int
    me_gusta: int
    marcado: bool


class EstadisticaCategoria(BaseModel):
    categoria_id: int
    categoria: str
    color: str
    total: int
    promedio_calificacion: float | None
    gasto_total: float


class Estadisticas(BaseModel):
    total_publicaciones: int
    total_usuarios: int
    promedio_calificacion: float | None
    gasto_total: float
    por_categoria: list[EstadisticaCategoria]
    por_animo: dict[str, int]
