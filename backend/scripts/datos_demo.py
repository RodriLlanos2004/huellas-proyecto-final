"""Carga datos de DEMOSTRACIÓN en Huellas Comunidad usando el propio servicio web.

Registra dos usuarios de prueba y les crea publicaciones para que la
comunidad no se vea vacía en la presentación. Son datos ficticios.

Uso (con Docker Compose levantado):
    docker compose cp backend/scripts/datos_demo.py api:/tmp/demo.py
    docker compose exec api python /tmp/demo.py
"""

import json
import urllib.error
import urllib.request
import uuid

API = "http://localhost:8000/api"


def llamar(metodo: str, ruta: str, cuerpo: bytes | None = None, tipo: str = "application/json") -> dict:
    peticion = urllib.request.Request(f"{API}{ruta}", data=cuerpo, method=metodo, headers={"Content-Type": tipo})
    with urllib.request.urlopen(peticion, timeout=10) as r:
        return json.loads(r.read().decode())


def registrar(alias: str) -> int:
    datos = json.dumps({"alias": alias, "dispositivo": uuid.uuid5(uuid.NAMESPACE_DNS, alias).hex}).encode()
    return llamar("POST", "/usuarios", datos)["id"]


def publicar(usuario_id: int, id_local: int, **campos) -> None:
    datos = {"usuario_id": usuario_id, "id_local": id_local, "favorita": False, **campos}
    frontera = uuid.uuid4().hex
    cuerpo = (
        f"--{frontera}\r\nContent-Disposition: form-data; name=\"datos\"\r\n\r\n"
        f"{json.dumps(datos)}\r\n--{frontera}--\r\n"
    ).encode()
    p = llamar("POST", "/publicaciones", cuerpo, f"multipart/form-data; boundary={frontera}")
    print(f"  #{p['id']} {p['titulo']} (@{p['alias']})")


ana = registrar("ana_demo")
luis = registrar("luis_demo")
print("Publicaciones de demostración:")
publicar(ana, 1, categoria_id=2, titulo="Marquesitas en Santa Lucía",
         texto="Noche de trova en el parque y una marquesita de queso de bola.",
         fecha="2026-11-14T20:30:00", animo="feliz", calificacion=9, gasto=60,
         latitud=20.970300, longitud=-89.621600, favorita=True)
publicar(ana, 2, categoria_id=1, titulo="Atardecer en Celestún",
         texto="Paseo en lancha para ver flamencos y el atardecer en la playa.",
         fecha="2026-11-08T18:10:00", animo="radiante", calificacion=10, gasto=350,
         latitud=20.859000, longitud=-90.399000)
publicar(luis, 1, categoria_id=5, titulo="Carrera en Paseo de Montejo",
         texto="10 km temprano antes del calor. Nuevo récord personal.",
         fecha="2026-11-16T06:45:00", animo="cansado", calificacion=8, gasto=0,
         latitud=20.992500, longitud=-89.617500)
publicar(luis, 2, categoria_id=3, titulo="Entrega del proyecto final",
         texto="Terminamos la app y la defensa salió muy bien.",
         fecha="2026-11-20T13:00:00", animo="tranquilo", calificacion=9, gasto=120,
         latitud=21.045500, longitud=-89.622600)
print("Listo.")
