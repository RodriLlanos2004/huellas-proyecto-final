import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/errores.dart';
import '../../diario/domain/registro_sincronizacion.dart';

/// Archivo plano `bitacora_sincronizacion.txt` en la carpeta de documentos.
///
/// Cada sincronización agrega una línea con valores separados por `;`
/// (fecha;enviadas;fallidas;resultado;servidor;detalle). Es un registro
/// legible que sobrevive aunque se borre la base de datos.
class BitacoraSincronizacion {
  BitacoraSincronizacion({Future<Directory> Function()? directorioBase})
      : _directorioBase = directorioBase ?? getApplicationDocumentsDirectory;

  static const nombreArchivo = 'bitacora_sincronizacion.txt';

  final Future<Directory> Function() _directorioBase;

  Future<File> archivo() async => File(p.join((await _directorioBase()).path, nombreArchivo));

  /// Agrega una línea; si el archivo no existe, primero escribe el encabezado.
  Future<void> agregar(RegistroSincronizacion registro) async {
    try {
      final f = await archivo();
      final nuevo = !await f.exists();
      await f.writeAsString(
        '${nuevo ? '${RegistroSincronizacion.encabezadoBitacora}\n' : ''}${registro.aLineaBitacora()}\n',
        mode: FileMode.append,
        flush: true,
      );
    } on FileSystemException catch (e) {
      // La bitácora es secundaria: si falla, se informa en consola sin interrumpir.
      debugPrint('No se pudo escribir la bitácora: $e');
    }
  }

  /// Contenido completo del archivo, o cadena vacía si aún no existe.
  Future<String> leer() async {
    try {
      final f = await archivo();
      return await f.exists() ? await f.readAsString() : '';
    } on FileSystemException catch (e) {
      throw FallaAlmacenamiento('No se pudo leer la bitácora de sincronización.', e);
    }
  }
}
