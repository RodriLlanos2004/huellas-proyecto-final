/// Jerarquía de fallas de la aplicación.
///
/// Las capas de datos y de dispositivo traducen las excepciones técnicas
/// (PlatformException, DatabaseException, TimeoutException, FileSystemException,
/// SocketException, ClientException)
/// a una de estas fallas, con un mensaje en español que la interfaz puede
/// mostrar tal cual. Así la UI nunca depende de detalles de un plugin concreto
/// (principio de inversión de dependencias) y un error nunca cierra la app.
sealed class FallaApp implements Exception {
  const FallaApp(this.mensaje, [this.causa]);

  /// Texto listo para mostrarse al usuario.
  final String mensaje;

  /// Excepción original, útil para depurar.
  final Object? causa;

  @override
  String toString() => '$runtimeType: $mensaje${causa == null ? '' : ' ($causa)'}';
}

/// El usuario negó un permiso. Si [permanente] es verdadero, el sistema ya no
/// volverá a mostrar el diálogo y la única salida es abrir los ajustes.
final class FallaPermiso extends FallaApp {
  const FallaPermiso(super.mensaje, {this.permanente = false});
  final bool permanente;
}

/// Un servicio del sistema está apagado (por ejemplo, el GPS).
final class FallaServicioDesactivado extends FallaApp {
  const FallaServicioDesactivado(super.mensaje);
}

/// El hardware no respondió a tiempo (por ejemplo, el GPS sin señal).
final class FallaTiempoAgotado extends FallaApp {
  const FallaTiempoAgotado(super.mensaje);
}

/// El dispositivo no tiene el hardware o servicio requerido.
final class FallaHardware extends FallaApp {
  const FallaHardware(super.mensaje, [super.causa]);
}

/// Error al leer o escribir datos locales (SQLite o archivos).
final class FallaAlmacenamiento extends FallaApp {
  const FallaAlmacenamiento(super.mensaje, [super.causa]);
}

/// Falló la comunicación con el servicio web: sin red, servidor apagado,
/// tiempo agotado o una respuesta de error (4xx/5xx).
final class FallaRed extends FallaApp {
  const FallaRed(String mensaje, {this.codigo, Object? causa}) : super(mensaje, causa);

  /// Código HTTP si el servidor respondió; null si ni siquiera hubo respuesta.
  final int? codigo;

  bool get sinConexion => codigo == null;
}

/// Convierte cualquier error en un mensaje presentable.
String mensajeDeError(Object? error) => switch (error) {
      FallaApp(:final mensaje) => mensaje,
      _ => 'Ocurrió un error inesperado. Intenta de nuevo.',
    };
