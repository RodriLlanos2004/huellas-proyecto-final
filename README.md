# Huellas · Diario personal con comunidad web

Proyecto final de **Programación de Dispositivos Móviles** (Universidad Anáhuac Mayab).
Autor: **Rodrigo Sebastián Llanos Yañez**.

Huellas es una app Flutter para registrar cada día con foto (cámara o galería), texto dictado por voz,
estado de ánimo, categoría, calificación, gasto y la ubicación GPS. Todo se guarda en el teléfono
(SQLite + archivos planos) y el usuario puede **publicar** las entradas que elija en
**Huellas Comunidad**, un servicio web REST (Python · FastAPI) que las registra en **MySQL**.
La app consulta esa base de datos para mostrar la lista, la galería, el detalle y las estadísticas
de la comunidad.

```
huellas-proyecto-final/
├── lib/                  App Flutter (Dart) · arquitectura Feature-First
├── test/                 Pruebas unitarias, de SQLite y de widgets
├── backend/              Servicio web (artefactos web): FastAPI + PyMySQL
│   ├── app/main.py       Endpoints REST
│   ├── app/repositorio.py Sentencias SQL parametrizadas
│   ├── app/esquemas.py   Validaciones (reglas de negocio)
│   ├── tests/            Pruebas de integración contra MySQL
│   └── Dockerfile
├── database/
│   ├── huellas_comunidad.sql   Script de la base de datos (tablas, vista, catálogo)
│   └── permisos.sql            Usuario de la API con permisos mínimos
├── docker-compose.yml    MySQL 8.4 + API + Adminer
└── docs/                 Documentación (PDF), diagramas y capturas del emulador
```

## Cumplimiento del enunciado

| Lineamiento | Dónde está |
|---|---|
| Documento de requisitos y reglas de negocio | `docs/Documentacion_Huellas_Proyecto_Final.pdf` |
| Uso de imágenes | Fotos del diario (archivos locales), fotos de la comunidad (`Image.network`), fondo y logotipo propios en `assets/images/` (Drawer, bloqueo, comunidad), íconos de Material |
| Widgets con desplazamiento | `ListView` (diario, comunidad, historial), `GridView` (galería de la comunidad), `CustomScrollView`/`SliverAppBar` (detalles), filtro horizontal de categorías |
| Navegación entre pantallas | Rutas nombradas (`core/rutas.dart`, `app.dart`), `Drawer`, `TabBar`, diálogos |
| Información entre pantallas | `EntradaDiario` y `Publicacion` viajan como `arguments`; el formulario y los detalles devuelven resultados con `Navigator.pop` |
| Formularios | Texto (título, relato, alias, URL), numéricos (calificación 1-10, gasto), lógicos (`Switch` favorita y ubicación, `Checkbox` publicar), selectores de fecha y hora (`showDatePicker`, `showTimePicker`), lista desplegable de categoría |
| Gadgets (al menos 2) | Cámara, GPS, micrófono y sensor biométrico |
| Almacenamiento: ≥3 entidades | SQLite: `entradas`, `categorias`, `sincronizaciones` (`features/diario/data/base_datos_diario.dart`) |
| Almacenamiento: archivo plano | `bitacora_sincronizacion.txt` (valores separados por `;`) y respaldo `huellas_*.json` |
| Registro en BD vía servicios web | `POST /api/usuarios`, `POST /api/publicaciones` (multipart), `POST /api/publicaciones/{id}/me-gusta`, `DELETE /api/publicaciones/{id}` |
| Consulta y visualización | `GET /api/publicaciones` (filtros), `GET /api/publicaciones/{id}`, `GET /api/estadisticas` |

## Puesta en marcha

### 1. Base de datos y servicio web

Requiere Docker Desktop.

```bash
cp .env.example .env          # y cambia las contraseñas
docker compose up -d --build
```

* API y documentación interactiva: <http://localhost:8000/docs>
* Adminer (ver la base de datos): <http://localhost:8090> · servidor `mysql`, usuario `huellas_api`
* Datos de demostración (opcional):
  `docker compose cp backend/scripts/datos_demo.py api:/tmp/demo.py && docker compose exec api python /tmp/demo.py`

Sin Docker: ejecutar `database/huellas_comunidad.sql` en MySQL 8, crear el usuario de
`database/permisos.sql`, y en `backend/`:

```bash
pip install -r requirements.txt
BD_CONTRASENA=... uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### 2. App

```bash
flutter pub get
flutter test
flutter run
```

En el emulador de Android la computadora se ve como `http://10.0.2.2:8000` (valor por defecto).
En un teléfono real se cambia en **Ajustes › Servidor** por la IP de la computadora en la red Wi-Fi
(y se agrega esa IP a `android/app/src/main/res/xml/network_security_config.xml`, porque Android
bloquea HTTP sin cifrar).

### 3. Pruebas del servicio web

```bash
cd backend
pip install -r requirements-dev.txt
BD_CONTRASENA=... python -m pytest -q     # 21 pruebas contra MySQL real
```

## Arquitectura

```
lib/
├── main.dart                     Raíz de composición (elige implementaciones)
├── app.dart                      MaterialApp, rutas nombradas, español, bloqueo por ciclo de vida
├── core/                         Dependencias (AppScope), errores (FallaApp/FallaRed), servicios de hardware
└── features/
    ├── diario/                   Entradas, categorías, sincronizaciones (SQLite) + pantallas del diario
    ├── comunidad/                Cliente HTTP, sincronización, bitácora y pantallas de la comunidad
    ├── seguridad/                Biometría y preferencias (alias, servidor, id del dispositivo)
    └── ajustes/
```

Las pantallas dependen de interfaces (`RepositorioDiario`, `RepositorioComunidad`…); las pruebas
usan versiones falsas sin red ni hardware.
