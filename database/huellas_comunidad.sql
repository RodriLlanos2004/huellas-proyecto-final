-- =====================================================================
--  Huellas Comunidad · Script de base de datos (MySQL 8)
--  Proyecto final · Programación de Dispositivos Móviles
--  Universidad Anáhuac Mayab
--
--  Crea la base, las tablas con sus reglas de negocio (llaves, únicos y
--  CHECK), una vista de consulta, el catálogo de categorías y un usuario
--  de aplicación con permisos mínimos.
--
--  Ejecución manual:   mysql -u root -p < database/huellas_comunidad.sql
--  Con Docker Compose: se ejecuta solo la primera vez que arranca MySQL.
-- =====================================================================

CREATE DATABASE IF NOT EXISTS huellas_comunidad
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE huellas_comunidad;

-- ---------------------------------------------------------------------
-- Usuarios de la comunidad. No hay contraseñas: la identidad es un alias
-- público ligado al identificador anónimo del dispositivo (RN-08).
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS usuarios (
  id           INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  alias        VARCHAR(20)   NOT NULL,
  dispositivo  CHAR(36)      NOT NULL,
  creado_en    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT uq_usuarios_alias       UNIQUE (alias),
  CONSTRAINT uq_usuarios_dispositivo UNIQUE (dispositivo),
  CONSTRAINT ck_usuarios_alias       CHECK (CHAR_LENGTH(alias) BETWEEN 3 AND 20)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- Catálogo de categorías. Los id coinciden con los de la tabla local de
-- SQLite en la app, así una entrada conserva su categoría al publicarse.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS categorias (
  id      TINYINT UNSIGNED NOT NULL,
  nombre  VARCHAR(30)      NOT NULL,
  icono   VARCHAR(30)      NOT NULL,
  color   CHAR(7)          NOT NULL,
  PRIMARY KEY (id),
  CONSTRAINT uq_categorias_nombre UNIQUE (nombre)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- Publicaciones: entradas del diario que el usuario decidió compartir.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS publicaciones (
  id            INT UNSIGNED      NOT NULL AUTO_INCREMENT,
  usuario_id    INT UNSIGNED      NOT NULL,
  categoria_id  TINYINT UNSIGNED  NOT NULL,
  id_local      INT UNSIGNED      NOT NULL,           -- id de la entrada en el SQLite del teléfono
  titulo        VARCHAR(60)       NOT NULL,
  texto         TEXT              NOT NULL,
  fecha         DATETIME          NOT NULL,           -- cuándo ocurrió el recuerdo
  animo         VARCHAR(12)       NOT NULL,
  calificacion  TINYINT UNSIGNED  NOT NULL,
  gasto         DECIMAL(10, 2)    NOT NULL DEFAULT 0,
  favorita      BOOLEAN           NOT NULL DEFAULT FALSE,
  latitud       DECIMAL(9, 6)     NULL,
  longitud      DECIMAL(9, 6)     NULL,
  foto          VARCHAR(80)       NULL,               -- nombre del archivo en el servidor
  publicado_en  DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  -- RN-07: una entrada del teléfono se publica una sola vez.
  CONSTRAINT uq_publicaciones_origen UNIQUE (usuario_id, id_local),
  CONSTRAINT fk_publicaciones_usuario   FOREIGN KEY (usuario_id)   REFERENCES usuarios (id)   ON DELETE CASCADE,
  CONSTRAINT fk_publicaciones_categoria FOREIGN KEY (categoria_id) REFERENCES categorias (id),
  CONSTRAINT ck_publicaciones_titulo       CHECK (CHAR_LENGTH(TRIM(titulo)) BETWEEN 1 AND 60),
  CONSTRAINT ck_publicaciones_animo        CHECK (animo IN ('radiante', 'feliz', 'tranquilo', 'cansado', 'triste')),
  CONSTRAINT ck_publicaciones_calificacion CHECK (calificacion BETWEEN 1 AND 10),
  CONSTRAINT ck_publicaciones_gasto        CHECK (gasto BETWEEN 0 AND 100000),
  CONSTRAINT ck_publicaciones_coordenadas  CHECK (
    (latitud IS NULL AND longitud IS NULL) OR
    (latitud BETWEEN -90 AND 90 AND longitud BETWEEN -180 AND 180)
  ),
  INDEX ix_publicaciones_fecha (fecha),
  INDEX ix_publicaciones_categoria (categoria_id)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- "Me gusta": un usuario solo puede dar uno por publicación (RN-11).
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS me_gusta (
  usuario_id      INT UNSIGNED NOT NULL,
  publicacion_id  INT UNSIGNED NOT NULL,
  creado_en       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (usuario_id, publicacion_id),
  CONSTRAINT fk_me_gusta_usuario     FOREIGN KEY (usuario_id)     REFERENCES usuarios (id)      ON DELETE CASCADE,
  CONSTRAINT fk_me_gusta_publicacion FOREIGN KEY (publicacion_id) REFERENCES publicaciones (id) ON DELETE CASCADE
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- Vista que usa el servicio web para listar: une autor, categoría y el
-- conteo de "me gusta" en una sola consulta.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_publicaciones AS
SELECT p.id,
       p.usuario_id,
       u.alias,
       p.categoria_id,
       c.nombre AS categoria,
       c.icono  AS categoria_icono,
       c.color  AS categoria_color,
       p.id_local,
       p.titulo,
       p.texto,
       p.fecha,
       p.animo,
       p.calificacion,
       p.gasto,
       p.favorita,
       p.latitud,
       p.longitud,
       p.foto,
       p.publicado_en,
       (SELECT COUNT(*) FROM me_gusta m WHERE m.publicacion_id = p.id) AS me_gusta
FROM publicaciones p
JOIN usuarios   u ON u.id = p.usuario_id
JOIN categorias c ON c.id = p.categoria_id;

-- ---------------------------------------------------------------------
-- Catálogo inicial (mismo orden e id que en la app).
-- ---------------------------------------------------------------------
INSERT INTO categorias (id, nombre, icono, color) VALUES
  (1, 'Viajes',   'flight',      '#00796B'),
  (2, 'Comida',   'restaurant',  '#E07A4F'),
  (3, 'Escuela',  'school',      '#3F51B5'),
  (4, 'Familia',  'family',      '#C2185B'),
  (5, 'Deporte',  'sports',      '#2E7D32'),
  (6, 'Otro',     'bookmark',    '#6D4C41')
ON DUPLICATE KEY UPDATE nombre = VALUES(nombre), icono = VALUES(icono), color = VALUES(color);

-- ---------------------------------------------------------------------
-- Usuario de la aplicación con permisos mínimos (solo lectura/escritura
-- de datos, sin poder alterar la estructura). La contraseña se define en
-- el archivo .env cuando se usa Docker Compose.
-- ---------------------------------------------------------------------
-- CREATE USER IF NOT EXISTS 'huellas_api'@'%' IDENTIFIED BY '<contraseña>';
-- GRANT SELECT, INSERT, UPDATE, DELETE ON huellas_comunidad.* TO 'huellas_api'@'%';

-- ---------------------------------------------------------------------
-- Consultas de ejemplo (las mismas que ejecuta el servicio web)
-- ---------------------------------------------------------------------
-- Últimas publicaciones de una categoría:
--   SELECT * FROM v_publicaciones WHERE categoria_id = 1 ORDER BY fecha DESC LIMIT 20;
-- Estadísticas por categoría:
--   SELECT c.nombre, COUNT(p.id) AS total, ROUND(AVG(p.calificacion), 1) AS promedio
--   FROM categorias c LEFT JOIN publicaciones p ON p.categoria_id = c.id
--   GROUP BY c.id ORDER BY total DESC;
