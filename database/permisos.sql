-- Permisos mínimos para el usuario del servicio web (creado por Docker con MYSQL_USER).
-- Solo puede leer y escribir datos de huellas_comunidad; no puede cambiar la estructura.
GRANT SELECT, INSERT, UPDATE, DELETE ON huellas_comunidad.* TO 'huellas_api'@'%';
FLUSH PRIVILEGES;
