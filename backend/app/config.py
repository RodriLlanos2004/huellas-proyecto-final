"""Configuración del servicio web leída de variables de entorno.

En Docker Compose los valores vienen del archivo `.env`; así las
credenciales de la base de datos nunca quedan escritas en el código.
"""

import os
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Configuracion:
    bd_host: str
    bd_puerto: int
    bd_usuario: str
    bd_contrasena: str
    bd_nombre: str
    carpeta_fotos: Path
    max_foto_bytes: int


def cargar() -> Configuracion:
    return Configuracion(
        bd_host=os.getenv("BD_HOST", "127.0.0.1"),
        bd_puerto=int(os.getenv("BD_PUERTO", "3306")),
        bd_usuario=os.getenv("BD_USUARIO", "huellas_api"),
        bd_contrasena=os.getenv("BD_CONTRASENA", ""),
        bd_nombre=os.getenv("BD_NOMBRE", "huellas_comunidad"),
        carpeta_fotos=Path(os.getenv("CARPETA_FOTOS", "fotos")),
        # RN-12: las fotos no pueden pesar más de 5 MB.
        max_foto_bytes=int(os.getenv("MAX_FOTO_BYTES", str(5 * 1024 * 1024))),
    )
